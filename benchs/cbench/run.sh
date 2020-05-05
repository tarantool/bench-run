#!/usr/bin/env bash

set -eu
set -o pipefail

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
numaopts="numactl --membind=1 --cpunodebind=1 --physcpubind=11"
cbench_opts=500

killall tarantool 2>/dev/null || true
rm -rf 5* 0*
sync && echo "sync passed" || echo "sync failed with error" $?
echo 3 > /proc/sys/vm/drop_caches
$numaopts tarantool /opt/cbench/cbench_runner.lua memtx 2>&1 | tee cbench_output_memtx.txt

killall tarantool 2>/dev/null || true
rm -rf 5* 0*
sync && echo "sync passed" || echo "sync failed with error" $?
echo 3 > /proc/sys/vm/drop_caches
$numaopts tarantool /opt/cbench/cbench_runner.lua vinyl fsync $cbench_opts 2>&1 | tee cbench_output_vinyl_fsync.txt

killall tarantool 2>/dev/null || true
rm -rf 5* 0*
sync && echo "sync passed" || echo "sync failed with error" $?
echo 3 > /proc/sys/vm/drop_caches
$numaopts tarantool /opt/cbench/cbench_runner.lua vinyl write $cbench_opts 2>&1 | tee cbench_output_vinyl_write.txt

grep "^?tab=cbench.tree" cbench_output_memtx.txt | \
  sed "s/.*name=//"| sed "s/&param=/:/"| sed "s/cb\./cb\.memtx\./"| \
  tee -a cbench-memtx-tree_result.txt
grep "^?tab=cbench.hash" cbench_output_memtx.txt | \
  sed "s/.*name=//"| sed "s/&param=/:/"| sed "s/cb\./cb\.memtx\./"| \
  tee -a cbench-memtx-hash_result.txt
grep "^?tab" cbench_output_vinyl_fsync.txt | \
  sed "s/.*name=//"| sed "s/&param=/:/"| sed "s/cb\./cb\.vinyl\.fsync\./"| \
  tee -a cbench-vinyl-fsync_result.txt
grep "^?tab" cbench_output_vinyl_write.txt | \
  sed "s/.*name=//"| sed "s/&param=/:/"| sed "s/cb\./cb\.vinyl\.write\./"| \
  tee -a cbench-vinyl-write_result.txt

echo ${TAR_VER} | tee cbench-memtx-tree_t_version.txt
echo ${TAR_VER} | tee cbench-memtx-hash_t_version.txt
echo ${TAR_VER} | tee cbench-vinyl-fsync_t_version.txt
echo ${TAR_VER} | tee cbench-vinyl-write_t_version.txt
echo ${TAR_VER} | tee cbench_t_version.txt

echo "Tarantool TAG:"
cat cbench_t_version.txt
echo "Overall results:"
echo "================"
echo "RESULTS (cbench-memtx-tree_result.txt):"
cat cbench-memtx-tree_result.txt
echo " "
echo "RESULTS (cbench-memtx-hash_result.txt):"
cat cbench-memtx-hash_result.txt
echo " "
echo "RESULTS (cbench-vinyl-fsync_result.txt):"
cat cbench-vinyl-fsync_result.txt
echo " "
echo "RESULTS (cbench-vinyl-write_result.txt):"
cat cbench-vinyl-write_result.txt
echo " "
echo "Publish data to bench database"
/opt/bench-run/benchs/publication/publish.py
