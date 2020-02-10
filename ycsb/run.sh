#!/usr/bin/env bash

mode=$1
runs=$2

if [ "$mode" == "" ]; then
    mode=hash
fi

if [ "$runs" == "" ]; then
    runs=1
fi

kill `pidof tarantool`

set -e
set -o pipefail

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
echo ${TAR_VER} | tee ycsb_t_version.txt

ws=/opt/ycsb
cd $ws

for f in workloads/workload[a-f] ; do
    sed 's#recordcount=.*#recordcount=1000000#g' -i $f
    sed 's#operationcount=.*#operationcount=1000000#g' -i $f
done

srvlua=$ws/tarantool/src/main/conf/tarantool-${mode}.lua
cd $ws
sed 's/listen=.*/listen=3301,\n   memtx_memory = 2000000000,/' -i $srvlua
sed 's/logger_nonblock.*//' -i $srvlua
sed 's/logger/log/' -i $srvlua
sed 's/read,write,execute/create,read,write,execute/' -i $srvlua
numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11 tarantool $srvlua 2>&1 &
sleep 5

plogs=$ws/results
rm -rf $ws/0* $plogs
mkdir $plogs
for l in a b c d e f ; do
    echo =============== $l
    for r in `eval echo {1..$runs}` ; do
        res=$plogs/run${l}_${r}
        echo ---------------- ${l}: $r
        echo "tarantool.port=3301" >> $ws/workloads/workload${l}
        numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11 bin/ycsb load tarantool -s -P workloads/workload${l} >${res}.load 2>&1 || cat ${res}.load
        numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11 bin/ycsb run tarantool -s -P workloads/workload${l} >${res}.log 2>&1 || cat ${res}.log
        grep Thro ${res}.log | awk '{ print "Overall result: "$3 }' | tee ${res}.txt
        sed "s#Overall result#$l $r#g" ${res}.txt >>${plogs}/results.txt
    done
done
cat ${plogs}/results.txt
