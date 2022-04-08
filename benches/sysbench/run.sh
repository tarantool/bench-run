#!/usr/bin/env bash

set -eu
set -o pipefail

source ../common.sh

SYSBENCH_TESTS="${SYSBENCH_TESTS:-}"
SYSBENCH_TIME="${SYSBENCH_TIME:-20}"
SYSBENCH_WARMUPTIME="${SYSBENCH_WARMUPTIME:-5}"
SYSBENCH_DBMS="${SYSBENCH_DBMS:-tarantool}"
SYSBENCH_THREADS="${SYSBENCH_THREADS:-200}"
SYSBENCH_RUNS="${SYSBENCH_RUNS:-10}"

TAR_VER=$(get_tarantool_version)

ARRAY_TESTS=(
	"oltp_read_only"
	"oltp_write_only"
	"oltp_read_write"
	"oltp_update_index"
	"oltp_update_non_index"
	"oltp_insert"
	"oltp_delete"
	"oltp_point_select"
	"select_random_points"
	"select_random_ranges"
	# "bulk_insert"
)

opts=("--db-driver=${SYSBENCH_DBMS}" "--threads=${SYSBENCH_THREADS}")

export LD_LIBRARY_PATH=/usr/local/lib

if [ -n "$SYSBENCH_TESTS" -a "$SYSBENCH_TESTS" != all ]; then
	IFS=, read -ra testlist <<< "$SYSBENCH_TESTS"
	ARRAY_TESTS=( "${testlist[@]}" )
fi

for test in "${ARRAY_TESTS[@]}"; do
	res=0
	tlog=sysbench_${test}_results.txt
	rm -f "$tlog"
	maxres=0
	for run in $(seq 1 "$SYSBENCH_RUNS"); do
		echo "$run"
		echo "------------ $test ------------ rerun: # $run ------------"

		stop_and_clean_tarantool /tmp/tarantool-server.sock
		wait_for_file_release /tmp/tarantool-server.sock 10
		under_numa 'tarantool' "$TARANTOOL_EXECUTABLE" tnt_srv.lua

		wait_for_tarantool_runnning /tmp/tarantool-server.sock 10

		./src/sysbench "$test" "${opts[@]}" cleanup > sysbench_output.txt
		./src/sysbench "$test" "${opts[@]}" prepare >> sysbench_output.txt

		under_numa 'benchmark' \
			./src/sysbench "$test" "${opts[@]}" \
				"--time=${SYSBENCH_TIME}" \
				"--warmup-time=${SYSBENCH_WARMUPTIME}" \
				run >> sysbench_output.txt

		grep -e 'transactions:' sysbench_output.txt | grep -oP '\(\K\S*' | tee "$tlog"
		tres=$(sed 's#^.*:##g' < "$tlog" | sed 's#\..*$##g')
		echo ">>> $tres"
		res=$(( res + tres ))
		if [[ $tres -gt $maxres ]]; then maxres=$tres ; fi
	done

	res=$(( res / SYSBENCH_RUNS ))
	echo "${test}: $res" >>Sysbench_result.txt

	echo "Subtest '$test' results:"
	echo "==============================="
	echo "Average result: $res"
	echo "Maximum result: $maxres"
	printf "Deviations (AVG -> MAX): %.2f%%" "$(bc <<< "scale = 4; (1 - $res / $maxres) * 100")"
done

echo "${TAR_VER}" | tee Sysbench_t_version.txt

echo "Tarantool TAG:"
cat Sysbench_t_version.txt
echo "Overall results:"
echo "================"
cat Sysbench_result.txt
kill_tarantool /tmp/tarantool-server.sock
