#!/usr/bin/env bash

type=$1
if [ "$type" == "" ]; then
    type=hash
fi

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
echo ${TAR_VER} | tee nosqlbench_t_version.txt

kill `pidof tarantool`

#set -e
#
#set -o pipefail

killall tarantool 2>/dev/null || true
rm -rf 0*.xlog 0*.snap
sync
echo 3 > /proc/sys/vm/drop_caches

#cd /opt/nosqlbench/
#cmake . &&  make -j
#cd -
#
#tarantool -v
#
free -h
numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11 tarantool `dirname $0`/tnt_${type}.lua 2>&1 &
sed  "s/port 3303/port 3301/" /opt/nosqlbench/src/nosqlbench.conf -i
#sed  "s/request_count 4000000/request_count 400000/" /opt/nosqlbench/src/nosqlbench.conf -i
sed  "s/benchmark 'no_limit'/benchmark 'time_limit'/" /opt/nosqlbench/src/nosqlbench.conf -i
sed  "s/time_limit 10/time_limit 2000/" /opt/nosqlbench/src/nosqlbench.conf -i
sed  "s/request_batch_count 1/request_batch_count 10/" /opt/nosqlbench/src/nosqlbench.conf -i
sed  "s/rps 12000/rps 20000/" /opt/nosqlbench/src/nosqlbench.conf -i
sleep 5
echo "Run NB"
# WARNING: don't try to save output from stderr - file will use the whole disk space !
numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11 /opt/nosqlbench/src/nb /opt/nosqlbench/src/nosqlbench.conf | \
    grep -v "Warmup" | grep -v "Failed to allocate" >nosqlbench_output.txt || cat nosqlbench_output.txt

#echo "Latest 1000 lines:"
#tail -1000 nosqlbench_output.txt

echo "Getting results"
grep "TOTAL RPS STATISTICS:" nosqlbench_output.txt -A6 | awk -F "|" 'NR > 4 {print $2,":", $4}' > nosqlbench_result.txt

cat nosqlbench_result.txt

