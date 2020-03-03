#!/usr/bin/env bash

kill `pidof tarantool`

set -e
set -o pipefail

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
echo ${TAR_VER} | tee linkbench_t_version.txt

cd /opt/linkbench && mvn clean package -Dmaven.test.skip=true
cd src/tarantool && make
cd -

numaopts="numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11"

# use always newly created path specialy mounted if needed
wpath=/builds/ws
rm -rf $wpath
mkdir -p $wpath
cd $wpath
tfile=/opt/linkbench/src/tarantool/app.lua
# rewrite the lua script at the needed location
# to be able to use its add additional files
cp -f `dirname $0`/app.lua $tfile
$numaopts tarantool $tfile &

cfgfile=/opt/linkbench/config/LinkConfigTarantool.properties
sed "s/^maxid1 = .*/maxid1 = 5000000/g" -i /opt/linkbench/config/FBWorkload.properties
sed "s/^requesters = .*/requesters = 1/g" -i $cfgfile
sed "s/^requests = .*/requests = 2000000/g" -i $cfgfile
$numaopts /opt/linkbench/bin/linkbench -c $cfgfile -l 2>&1 | tee loading.res.txt
sync
echo 3 > /proc/sys/vm/drop_caches
$numaopts /opt/linkbench/bin/linkbench -c $cfgfile -r 2>&1 | tee linkbench_output.txt

grep "REQUEST PHASE COMPLETED" linkbench_output.txt | sed "s/.*second = /linkbench:/" | tee -a linkbench_result.txt
