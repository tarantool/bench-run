# path to tarantool executable
export TARANTOOL_EXECUTABLE=tarantool

# path to tarantoolctl executable
export TARANTOOLCTL_EXECUTABLE=tarantoolctl

# location of tests to be run
# all the tests will be copied and run in this directory
export BENCH_WORKDIR="$PWD/.benchdir"

export CBENCH_DIR="$HOME/work/cbench/"
export LINKBENCH_DIR="$HOME/work/linkbench/"
export NOSQLBENCH_DIR="$HOME/work/nosqlbench/"
export SYSBENCH_DIR="$HOME/work/sysbench/"
export TPCC_DIR="$HOME/work/tpcc/"
export TPCH_DIR="$HOME/work/tpch/"
export YCSB_DIR="$HOME/work/ycsb/"

# ----------------- BENCHMARK PARAMS -----------------
# Fill free to delete all the params as long as all
# the benchmarks have their own defaults set in run.sh

# cbench parameters
export CBENCH_VINYL_WORKLOAD=50
export CBENCH_MEMTX_WORKLOAD=10000

# linkbench parameters
export LINKBENCH_REQUESTERS=1
export LINKBENCH_REQUESTS=1000
export LINKBENCH_WORKLOAD_SIZE=1000

# nosqlbench parameters
export NOSQLBENCH_TIMELIMIT=20000
export NOSQLBENCH_BATCHCOUNT=10
export NOSQLBENCH_RPS=20000

# sysbench parameters
export SYSBENCH_RUNS=1
export SYSBENCH_TIME=5

# tpcc parameters
export TPCC_TIME=20
export TPCC_WARMUPTIME=5
export TPCC_WAREHOUSES=15
## possible to start tpcc benchmark from snapshot wich I higly recommend
## as tpcc_load takes a good portion of time to load the data
# export TPCC_FROMSNAPSHOT="/tmp/00000000000000033515.snap"

# tpch parameters
export TPCH_SKIP_SQLITE=1

# ycsb parameters
export YCSB_OPERATIONCOUNT=1000
export YCSB_RECORDCOUNT=1000
export YCSB_RUNS=1
