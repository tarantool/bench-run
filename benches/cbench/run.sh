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

stop_and_clean_tarantool
maybe_drop_cache

maybe_under_numactl "${numaopts[@]}" -- \
	"$TARANTOOL_EXECUTABLE" cbench_runner.lua memtx "$CBENCH_MEMTX_WORKLOAD" 2>&1 | tee cbench_output_memtx.txt

stop_and_clean_tarantool
maybe_drop_cache

maybe_under_numactl "${numaopts[@]}" -- \
	"$TARANTOOL_EXECUTABLE" cbench_runner.lua vinyl fsync "$CBENCH_VINYL_WORKLOAD" 2>&1 | tee cbench_output_vinyl_fsync.txt

stop_and_clean_tarantool
maybe_drop_cache

maybe_under_numactl "${numaopts[@]}" -- \
	"$TARANTOOL_EXECUTABLE" cbench_runner.lua vinyl write "$CBENCH_VINYL_WORKLOAD" 2>&1 | tee cbench_output_vinyl_write.txt

echo "$TAR_VER"
