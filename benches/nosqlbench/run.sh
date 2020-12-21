#!/usr/bin/env bash

set -eu
set -o pipefail

source ../common.sh

# type=$1
# if [ "$type" == "" ]; then
#     type=hash
# fi

NOSQLBENCH_WORKLOAD="${NOSQLBENCH_WORKLOAD:-}"
NOSQLBENCH_TIMELIMIT="${NOSQLBENCH_TIMELIMIT:-20000}"
NOSQLBENCH_BATCHCOUNT="${NOSQLBENCH_BATCHCOUNT:-10}"
NOSQLBENCH_RPS="${NOSQLBENCH_RPS:-20000}"
NOSQLBENCH_WORKLOADSIZE="${NOSQLBENCH_WORKLOADSIZE:-4000000}"

TAR_VER=$(get_tarantool_version)

function run_nosqlbench {
	local type="$1"
	stop_and_clean_tarantool /tmp/tarantool-server.sock
	wait_for_file_release /tmp/tarantool-server.sock 10

	under_numa 'tarantool' \
		"$TARANTOOL_EXECUTABLE" "tnt_${type}.lua" 2>&1 &

	config=nosqlbench.conf
	cp src/nosqlbench.conf "$config"

	sed  "s/port 3303/port 3301/" "$config" -i
	sed  "s/benchmark 'no_limit'/benchmark 'time_limit'/" "$config" -i
	sed  "s/time_limit 10/time_limit $NOSQLBENCH_TIMELIMIT/" "$config" -i
	sed  "s/request_batch_count 1/request_batch_count $NOSQLBENCH_BATCHCOUNT/" "$config" -i
	sed  "s/rps 12000/rps $NOSQLBENCH_RPS/" "$config" -i
	sed  "s/request_count 4000000/request_count $NOSQLBENCH_WORKLOADSIZE/" "$config" -i

	sleep 5
	echo "Run NB type='$type'"

	# WARNING: don't try to save output from stderr - file will use the whole disk space !
	(under_numa 'benchmark' \
		./src/nb "$config") \
		| grep -v "Warmup" \
		| grep -v "Failed to allocate" >nosqlbench_output.txt \
		|| cat nosqlbench_output.txt

	grep "TOTAL RPS STATISTICS:" nosqlbench_output.txt -A6 | \
		awk -F "|" 'NR > 4 {print $2,":", $4}' > "noSQLbench.${type}_result.txt"
	echo "${TAR_VER}" | tee "noSQLbench.${type}_t_version.txt"
}

if [ -z "$NOSQLBENCH_WORKLOAD" -o "$NOSQLBENCH_WORKLOAD" == all ]; then
	run_nosqlbench tree
	run_nosqlbench hash
else
	run_nosqlbench "$NOSQLBENCH_WORKLOAD"
fi
