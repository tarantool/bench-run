#!/usr/bin/env bash
set -eu
set -o pipefail

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
numaopts="numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11"
base_dir=$(pwd)

cd /opt/tpch

make create_SQL_db

killall tarantool 2>/dev/null || true
sync && echo "sync passed" || echo "sync failed with error" $?
echo 3 > /proc/sys/vm/drop_caches

make bench-sqlite NUMAOPTS=$numaopts

make create_TNT_db

killall tarantool 2>/dev/null || true
sync && echo "sync passed" || echo "sync failed with error" $?
echo 3 > /proc/sys/vm/drop_caches

make bench-tnt NUMAOPTS=$numaopts

make report
sed "/-2/d" bench-tnt.csv | sed "s/;/:/" | sed "s/-1/0/" | tee tpc.h_result.txt

echo ${TAR_VER} | tee tpc.h_t_version.txt
cp -f tpc.h_t_version.txt $base_dir
cp -f tpc.h_result.txt $base_dir
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
cat tpc.h_result.txt
echo " "
echo "Publish data to bench database"
/opt/bench-run/benchs/publication/publish.py
