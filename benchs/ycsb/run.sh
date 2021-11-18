#!/usr/bin/env bash

set -eu
set -o pipefail

mode=$1
runs=1

if [ "$mode" == "" ]; then
    mode=hash
fi

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
numaopts="numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11"
base_dir=$(pwd)

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
$numaopts tarantool $srvlua 2>&1 &
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
        $numaopts bin/ycsb load tarantool -s -P workloads/workload${l} >${res}.load 2>&1 || cat ${res}.load
	sync && echo "sync passed" || echo "sync failed with error" $?
	echo 3 > /proc/sys/vm/drop_caches
        $numaopts bin/ycsb run tarantool -s -P workloads/workload${l} >${res}.log 2>&1 || cat ${res}.log
        grep Thro ${res}.log | awk '{ print "Overall result: "$3 }' | tee ${res}.txt
        sed "s#Overall result#$l $r#g" ${res}.txt >>${plogs}/ycsb.${mode}_result.txt
    done
done

echo ${TAR_VER} | tee ycsb.${mode}_t_version.txt
cp -f ${plogs}/ycsb.${mode}_result.txt .
cp -f ycsb.${mode}_t_version.txt $base_dir
cp -f ycsb.${mode}_result.txt $base_dir

echo "Tarantool TAG:"
cat ycsb.${mode}_t_version.txt
echo "Overall results:"
echo "================"
cat ycsb.${mode}_result.txt

