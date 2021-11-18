#!/usr/bin/env bash

set -eu
set -o pipefail

type=$1
if [ "$type" == "" ]; then
    type=hash
fi

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
numaopts="numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11"

killall tarantool 2>/dev/null || true
sync && echo "sync passed" || echo "sync failed with error" $?
echo 3 > /proc/sys/vm/drop_caches

$numaopts tarantool `dirname $0`/tnt_${type}.lua 2>&1 &
sed  "s/port 3303/port 3301/" /opt/nosqlbench/src/nosqlbench.conf -i
sed  "s/benchmark 'no_limit'/benchmark 'time_limit'/" /opt/nosqlbench/src/nosqlbench.conf -i
sed  "s/time_limit 10/time_limit 2000/" /opt/nosqlbench/src/nosqlbench.conf -i
sed  "s/request_batch_count 1/request_batch_count 10/" /opt/nosqlbench/src/nosqlbench.conf -i
sed  "s/rps 12000/rps 20000/" /opt/nosqlbench/src/nosqlbench.conf -i
sleep 5
echo "Run NB"
# WARNING: don't try to save output from stderr - file will use the whole disk space !
$numaopts  /opt/nosqlbench/src/nb /opt/nosqlbench/src/nosqlbench.conf | \
    grep -v "Warmup" | grep -v "Failed to allocate" >nosqlbench_output.txt || cat nosqlbench_output.txt

grep "TOTAL RPS STATISTICS:" nosqlbench_output.txt -A6 | \
  awk -F "|" 'NR > 4 {print $2,":", $4}' > noSQLbench.${type}_result.txt
echo ${TAR_VER} | tee noSQLbench.${type}_t_version.txt

echo "Tarantool TAG:"
cat noSQLbench.${type}_t_version.txt
echo "Overall results:"
echo "================"
cat noSQLbench.${type}_result.txt
