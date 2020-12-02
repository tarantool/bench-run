# path to tarantool executable
export TARANTOOL_EXECUTABLE=tarantool

# location of tests to be run
export BENCH_WORKDIR="$PWD/.benchdir"

# cbench parameters
export CBENCH_DIR="$HOME/work/cbench/"
export CBENCH_VINYL_WORKLOAD=50
export CBENCH_MEMTX_WORKLOAD=10000

# linkbench parameters
export LINKBENCH_DIR="$HOME/work/linkbench/"
export LINKBENCH_REQUESTERS=1
export LINKBENCH_REQUESTS=1000
export LINKBENCH_WORKLOAD_SIZE=1000

# linkbench parameters
export NOSQLBENCH_DIR="$HOME/work/nosqlbench/"

# linkbench parameters
export SYSBENCH_DIR="$HOME/work/sysbench/"
export SYSBENCH_RUNS=1
export SYSBENCH_TIME=5

# tpcc parameters
export TPCC_DIR="$HOME/work/tpcc/"
export TPCC_TIME=20
export TPCC_WARMUPTIME=5
export TPCC_WAREHOUSES=15
export TPCC_FROMSNAPSHOT="/tmp/00000000000000033515.snap"

# tpcc parameters
export TPCH_DIR="$HOME/work/tpch/"
export TPCH_SKIP_SQLITE=1

# tpcc parameters
export YCSB_DIR="$HOME/work/ycsb/"
export YCSB_OPERATIONCOUNT=1000
export YCSB_RECORDCOUNT=1000
export YCSB_RUNS=1
