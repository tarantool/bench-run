#!/usr/bin/env bash
set -eu
set -o pipefail

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
numaopts="numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11"
base_dir=$(pwd)

TIME=1200
WARMUP_TIME=10

killall tarantool tpcc_load 2>/dev/null || true
sync && echo "sync passed" || echo "sync failed with error" $?
echo 3 > /proc/sys/vm/drop_caches

sed 's#box.sql#box#g' -i /opt/tpcc/create_table.lua
$numaopts tarantool /opt/tpcc/create_table.lua &
sleep 5

# Usage: tpcc_load -h server_host -P port -d database_name -u mysql_user 
#            -p mysql_password -w warehouses -l part -m min_wh -n max_wh
#        * [part]: 1=ITEMS 2=WAREHOUSE 3=CUSTOMER 4=ORDERS
tpcc_opts="-h localhost -P 3301 -d tarantool -u root -p '' -w 15"

cd /opt/tpcc
. /opt/tpcc/load.sh tarantool 15

$numaopts /opt/tpcc/tpcc_start $tpcc_opts -r10 -l${TIME} -i${TIME} >tpcc_output.txt 2>/dev/null

echo -n "tpcc:" | tee tpc.c_result.txt
cat tpcc_output.txt | grep -e '<TpmC>' | grep -oP '\K[0-9.]*' | tee -a tpc.c_result.txt
cat tpcc_output.txt

echo ${TAR_VER} | tee tpc.c_t_version.txt
cp -f tpc.c_t_version.txt $base_dir
cp -f tpc.c_result.txt $base_dir

echo "Tarantool TAG:"
cat tpc.c_t_version.txt
echo "Overall result:"
echo "==============="
cat tpc.c_result.txt
