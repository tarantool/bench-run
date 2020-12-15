local debug = require 'debug'
local fio   = require 'fio'

local dir = fio.dirname(debug.getinfo(1, "S").source:match('^@(.+)'))
local installPath = fio.pathjoin(dir, '.installed')

local function strict(v, path)
	return setmetatable(v, {
		__index = function(self, k)
			error(("key='%s' is not set in %s"):format(k, path), 2)
		end
	})
end

local M = {
	RUNNERS_DIR             = fio.pathjoin(dir,         'benches'),
	RESULT_DIR              = fio.pathjoin(dir,         '.runs'),
	BENCH_WORKDIR           = fio.pathjoin(dir,         '.benchdir'),
	CBENCH_DIR              = fio.pathjoin(installPath, 'cbench'),
	LINKBENCH_DIR           = fio.pathjoin(installPath, 'linkbench'),
	NOSQLBENCH_DIR          = fio.pathjoin(installPath, 'nosqlbench'),
	SYSBENCH_DIR            = fio.pathjoin(installPath, 'sysbench'),
	TPCC_DIR                = fio.pathjoin(installPath, 'tpcc'),
	TPCH_DIR                = fio.pathjoin(installPath, 'tpch'),
	YCSB_DIR                = fio.pathjoin(installPath, 'ycsb'),

	-- Following params are going to be exported as ENV variables
	-- to benchmark run scripts
	env = {
		TARANTOOL_EXECUTABLE    = 'tarantool',
		TARANTOOLCTL_EXECUTABLE = 'tarantoolctl',

		-- ----------------- BENCHMARK PARAMS -----------------
		-- Fill free to delete all the params as long as all
		-- the benchmarks have their own defaults set in run.sh

		-- cbench parameters
		CBENCH_VINYL_WORKLOAD=50,
		CBENCH_MEMTX_WORKLOAD=10000,

		-- linkbench parameters
		LINKBENCH_REQUESTERS=1,
		LINKBENCH_REQUESTS=1000,
		LINKBENCH_WORKLOAD_SIZE=1000,

		-- nosqlbench parameters
		NOSQLBENCH_TIMELIMIT=20,
		NOSQLBENCH_BATCHCOUNT=10,
		NOSQLBENCH_RPS=20000,
		NOSQLBENCH_WORKLOADSIZE=100000,

		-- sysbench parameters
		SYSBENCH_RUNS=1,
		SYSBENCH_TIME=5,
		SYSBENCH_TESTS='all',

		-- tpcc parameters
		TPCC_TIME=20,
		TPCC_WARMUPTIME=5,
		TPCC_WAREHOUSES=15,
		---- possible to start tpcc benchmark from snapshot wich I higly recommend
		---- as tpcc_load takes a good portion of time to load the data
		-- TPCC_FROMSNAPSHOT="/tmp/00000000000000033515.snap"

		-- tpch parameters
		TPCH_SKIP_SQLITE=1,

		-- ycsb parameters
		YCSB_OPERATIONCOUNT=1000,
		YCSB_RECORDCOUNT=1000,
		YCSB_RUNS=1,
	}
}

strict(M,     'config')
strict(M.env, 'config.env')

return M
