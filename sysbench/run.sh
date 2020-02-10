#!/usr/bin/env bash

runs=10
if [ "$1" != "" ]; then
    runs=$1
fi

kill `pidof tarantool`

set -e
set -o pipefail

TAR_VER=$(tarantool -v | grep -e "Tarantool" |  grep -oP '\s\K\S*')
echo ${TAR_VER} | tee sysbench_t_version.txt
set -e

ARRAY_TESTS=(
    "oltp_read_only"
    "oltp_write_only"
    "oltp_read_write"
    "oltp_update_index"
    "oltp_update_non_index"
    "oltp_insert"
    "oltp_delete"
    "oltp_point_select"
    "select_random_points"
    "select_random_ranges"
#    "bulk_insert"
)

if [ -n "${TEST}" ]; then ARRAY_TESTS=("${TEST}"); fi


if [ ! -n "${WARMUP_TIME}" ]; then WARMUP_TIME=5; fi
if [ ! -n "${TIME}" ]; then TIME=20; fi
if [ ! -n "${DBMS}" ]; then DBMS="tarantool"; fi
if [ ! -n "${THREADS}" ]; then THREADS=200; fi

if [ -n "${USER}" ]; then USER=--${DBMS}-user=${USER}; fi
if [ -n "${PASSWORD}" ]; then PASSWORD=--${DBMS}-password=${PASSWORD}; fi

numaconf="--membind=1 --cpunodebind=1 --physcpubind=6,7,8,9,10,11"
opts="--db-driver=${DBMS} --threads=${THREADS}"

export LD_LIBRARY_PATH=/usr/local/lib

rm -f sysbench_result.txt
set -o pipefail
for test in "${ARRAY_TESTS[@]}"; do
    res=0
    tlog=sysbench_${test}_result.txt
    rm -f $tlog
    maxres=0
    for run in `eval echo {1..$runs}` ; do
        echo "------------ $test ------------ rerun: # $run ------------"
        `dirname $0`/run_tnt.sh >tnt_server.txt 2>&1 || ( cat tnt_server.txt ; exit 1 )

        sysbench $test $opts cleanup >sysbench_output.txt
        sysbench $test $opts prepare >>sysbench_output.txt
 
        numactl $numaconf sysbench $test $opts \
            --time=${TIME} --warmup-time=${WARMUP_TIME} run >>sysbench_output.txt

        numactl $numaconf sysbench $test $opts cleanup >>sysbench_output.txt

        cat sysbench_output.txt | grep -e 'transactions:' | grep -oP '\(\K\S*' | tee $tlog
        tres=`cat $tlog | sed 's#^.*:##g' | sed 's#\..*$##g'`
        res=$(($res+$tres))
        if [[ $tres -gt $maxres ]]; then maxres=$tres ; fi
    done
    res=$(($res/$runs))
    echo "${test}: $res" >>sysbench_result.txt

    echo "Subtest '$test' results:"
    echo "==============================="
    echo "Average result: $res"
    echo "Maximum result: $maxres"
    printf "Diviations (AVG -> MAX): %.2f" `bc <<< "scale = 4; (1 - $res / $maxres) * 100"` ; echo %
done

echo "Overall results:"
echo "================"
cat sysbench_result.txt

