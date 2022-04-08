#!/usr/bin/env bash
set -eu
set -o pipefail

source ../common.sh

TPCH_SKIP_SQLITE="${TPCH_SKIP_SQLITE:-}"

TAR_VER=$(get_tarantool_version)
numastr=
numastr="$(get_numa_cpu_option 'tarantool')"
if [ -n "$numastr" ]; then
	numastr="numactl $numastr"
fi

if [ -z "$TPCH_SKIP_SQLITE" ]; then
	make create_SQL_db

	kill_tarantool 3301
	wait_for_port_release 3301 10
	sync_disk
	maybe_drop_cache

	make bench-sqlite NUMAOPTS="$numastr"
fi

kill_tarantool 3301
wait_for_port_release 3301 10
make create_TNT_db

kill_tarantool 3301
wait_for_port_release 3301 10
sync_disk
maybe_drop_cache

make bench-tnt TARANTOOL="$TARANTOOL_EXECUTABLE" NUMAOPTS="$numastr"
make report
sed "/-2/d" bench-tnt.csv | sed "s/;/:/" | sed "s/-1/0/" | tee tpc.h_result.txt

echo "${TAR_VER}" | tee tpc.h_t_version.txt

echo "Tarantool TAG:"
cat tpc.h_t_version.txt

if [ -n "$TPCH_SKIP_SQLITE" ]; then
	echo "Overall result SQL:"
	echo "==================="
	cat bench-sqlite.csv
fi

echo " "
echo "Overall result TNT:"
echo "==================="
cat tpc.h_result.txt
