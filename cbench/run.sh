#!/usr/bin/env bash

kill `pidof tarantool`
set -e
set -o pipefail

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
echo ${TAR_VER} | tee cbench_t_version.txt

killall tarantool 2>/dev/null || true
rm -rf 5* 0*
echo 3 > /proc/sys/vm/drop_caches
numactl --membind=1 --cpunodebind=1 --physcpubind=9 tarantool /opt/cbench/cbench_runner.lua memtx 2>&1 | tee cbench_output_memtx.txt

killall tarantool 2>/dev/null || true
rm -rf 5* 0*
echo 3 > /proc/sys/vm/drop_caches
numactl --membind=1 --cpunodebind=1 --physcpubind=10 tarantool /opt/cbench/cbench_runner.lua vinyl fsync 500 2>&1 | tee cbench_output_vinyl_fsync.txt

killall tarantool 2>/dev/null || true
rm -rf 5* 0*
echo 3 > /proc/sys/vm/drop_caches
numactl --membind=1 --cpunodebind=1 --physcpubind=11 tarantool /opt/cbench/cbench_runner.lua vinyl write 500 2>&1 | tee cbench_output_memtx_write.txt

grep "^?tab" cbench_output_memtx.txt | sed "s/.*name=//"| sed "s/&param=/:/"| sed "s/cb\./cb\.memtx\./"| tee -a cbench_result.txt
grep "^?tab" cbench_output_vinyl_fsync.txt | sed "s/.*name=//"| sed "s/&param=/:/"| sed "s/cb\./cb\.vinyl\.fsync\./"| tee -a cbench_result.txt
grep "^?tab" cbench_output_memtx_write.txt | sed "s/.*name=//"| sed "s/&param=/:/"| sed "s/cb\./cb\.vinyl\.write\./"| tee -a cbench_result.txt

#mv tarantool-server.log cbench_tarantool_server.log

echo "RESULTS:"
cat cbench_result.txt

