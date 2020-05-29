#!/usr/bin/env bash
### set -eu
### set -o pipefail

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
numaopts="numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11"
base_dir=$(pwd)

cd /opt/tpch
make TPC-H.db

killall tarantool tpcc_load 2>/dev/null || true
sync && echo "sync passed" || echo "sync failed with error" $?
echo 3 > /proc/sys/vm/drop_caches

$numaopts /opt/tpch/bench_queries.sh 2>&1 | tee bench-sqlite.log
make 00000000000000000000.snap

killall tarantool tpcc_load 2>/dev/null || true
sync && echo "sync passed" || echo "sync failed with error" $?
echo 3 > /proc/sys/vm/drop_caches

$numaopts tarantool execute_query.lua -n 3 2>&1 | tee bench-tnt.log
make report

echo ${TAR_VER} | tee tpc.h_t_version.txt
cp -f tpc.h_t_version.txt $base_dir
#cp -f tpc.h_result.txt $base_dir
cp -f bench-sqlite.csv $base_dir
cp -f bench-tnt.csv $base_dir

echo "Tarantool TAG:"
cat tpc.h_t_version.txt
echo "Overall result SQL:"
echo "==================="
cat bench-sqlite.csv
echo " "
echo "Overall result TNT:"
echo "==================="
cat bench-tnt.csv
### cat tpc.h_result.txt
### echo " "
### echo "Publish data to bench database"
### /opt/bench-run/benchs/publication/publish.py
