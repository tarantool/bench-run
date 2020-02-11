#!/usr/bin/env bash

# use always newly created path specialy mounted if needed
wpath=/builds/ws
rm -rf $wpath
mkdir -p $wpath
cd $wpath

numactl --show
numactl --hardware
killall tarantool 2>/dev/null || true
rm -rf 0*.xlog 0*.snap /tmp/tarantool-server.sock
while netstat -tulnp | grep 3301 ; do
    echo "Waiting the port 3301 release..."
    sleep 4
done
while ! numactl --membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11 \
	tarantool `dirname $0`/tnt_srv.lua 2>&1 ; do
    echo "Waiting for Tarantool trying to start..."
    sleep 5
done
sync
echo 3 > /proc/sys/vm/drop_caches

STATUS=
while [ ${#STATUS} -eq "0" ]; do
    STATUS="$(echo box.info.status | tarantoolctl connect /tmp/tarantool-server.sock | grep -e "- running")"
    echo "waiting load snapshot to tarantool..."
    sleep 6
done
