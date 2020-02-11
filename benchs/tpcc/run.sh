#!/usr/bin/env bash

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
echo ${TAR_VER} | tee tpcc_t_version.txt

set -e

if [ ! -n "${TIME}" ]; then TIME=1200; fi
if [ ! -n "${WARMUP_TIME}" ]; then WARMUP_TIME=10; fi

set -o pipefail

killall tarantool tpcc_load 2>/dev/null || true
rm -rf 0*.xlog 0*.snap
sync
echo 3 > /proc/sys/vm/drop_caches

sed 's#box.sql#box#g' -i /opt/tpcc/create_table.lua
numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11 tarantool /opt/tpcc/create_table.lua &
sleep 5

# Usage: tpcc_load -h server_host -P port -d database_name -u mysql_user 
#            -p mysql_password -w warehouses -l part -m min_wh -n max_wh
#        * [part]: 1=ITEMS 2=WAREHOUSE 3=CUSTOMER 4=ORDERS
tpcc_opts="-h localhost -P 3301 -d tarantool -u root -p '' -w 15"

cd /opt/tpcc
. /opt/tpcc/load.sh tarantool 15

numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11 \
    /opt/tpcc/tpcc_start $tpcc_opts -r10 -l${TIME} -i${TIME} >tpcc_output.txt 2>/dev/null

echo -n "tpcc:" | tee tpcc_result.txt
cat tpcc_output.txt | grep -e '<TpmC>' | grep -oP '\K[0-9.]*' | tee -a tpcc_result.txt

cat tpcc_output.txt
echo "Overall result:"
echo "==============="
cat tpcc_result.txt
