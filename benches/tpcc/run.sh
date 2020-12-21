#!/usr/bin/env bash
set -eu
set -o pipefail

source ../common.sh

TAR_VER=$(get_tarantool_version)

TPCC_TIME="${TPCC_TIME:-1200}"
TPCC_WARMUPTIME="${TPCC_WARMUPTIME:-10}"
TPCC_WAREHOUSES="${TPCC_WAREHOUSES:-15}"
TPCC_FROMSNAPSHOT="${TPCC_FROMSNAPSHOT:-}"

killall tpcc_load 2>/dev/null || true
stop_and_clean_tarantool 3301

tpcc_opts=(-h localhost -P 3301 -d tarantool -u root -p '' -w "$TPCC_WAREHOUSES")

if [ -z "$TPCC_FROMSNAPSHOT" ]; then
	kill_tarantool 3301
	wait_for_port_release 3301 10
	under_numa 'tarantool' \
		"$TARANTOOL_EXECUTABLE" init_empty.lua &
	wait_for_tarantool_runnning 3301 15

	./tpcc_load "${tpcc_opts[@]}"
else
	[ ! -f "$TPCC_FROMSNAPSHOT" ] && error "No such file: '$TPCC_FROMSNAPSHOT'"
	cp "$TPCC_FROMSNAPSHOT" .

	kill_tarantool 3301
	wait_for_port_release 3301 10
	under_numa 'tarantool' \
		"$TARANTOOL_EXECUTABLE" init_not_empty.lua &
	wait_for_tarantool_runnning 3301 60
fi


under_numa 'benchmark' \
	./tpcc_start "${tpcc_opts[@]}" -r "$TPCC_WARMUPTIME" -l "$TPCC_TIME" -i "$TPCC_TIME" > tpcc_output.txt 2>/dev/null

echo -n "tpcc:" | tee tpc.c_result.txt
grep -e '<TpmC>' tpcc_output.txt | grep -oP '\K[0-9.]*' | tee -a tpc.c_result.txt
cat tpcc_output.txt

kill_tarantool 3301
wait_for_port_release 3301 10

echo "${TAR_VER}" | tee tpc.c_t_version.txt

echo "Tarantool TAG:"
cat tpc.c_t_version.txt
echo "Overall result:"
echo "==============="
cat tpc.c_result.txt
