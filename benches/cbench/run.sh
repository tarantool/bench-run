#!/usr/bin/env bash

set -eu
set -o pipefail

source ../common.sh

CBENCH_VINYL_WORKLOAD="${CBENCH_VINYL_WORKLOAD:-500}"
CBENCH_MEMTX_WORKLOAD="${CBENCH_MEMTX_WORKLOAD:-1000000}"

export LUA_CPATH="$PWD/?.so"
export LUA_PATH="$PWD/?/init.lua"

TAR_VER=$(get_tarantool_version)
numaopts=(--membind=1 --cpunodebind=1 --physcpubind=11)

WORKLOADS=(
	"memtx       $CBENCH_MEMTX_WORKLOAD"
	"vinyl fsync $CBENCH_VINYL_WORKLOAD"
	"vinyl write $CBENCH_VINYL_WORKLOAD"
)

for workload in "${WORKLOADS[@]}"; do
	read -ra workloadArr <<< "$workload"

	filename='cbench_output'
	for i in $(seq 0 $(( ${#workloadArr[@]} - 2 ))); do
		filename=$(printf '%s_%s' "$filename" "${workloadArr[$i]}")
	done

	filename=$(printf '%s.txt' "$filename")

	stop_and_clean_tarantool tarantool.pid
	wait_for_file_release tarantool.pid 10
	maybe_drop_cache

	maybe_under_numactl "${numaopts[@]}" -- \
		"$TARANTOOL_EXECUTABLE" cbench_runner.lua "${workloadArr[@]}" | tee "$filename"
done

stop_and_clean_tarantool tarantool.pid
wait_for_file_release tarantool.pid 10

echo "$TAR_VER"
