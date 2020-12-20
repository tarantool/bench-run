local output = require 'lib.output'
local utils  = require 'lib.utils'
local exec   = require 'lib.exec'
local stat   = require 'lib.stat'
local json   = require 'json'
local fio    = require 'fio'

local commands = {}

local function _list_benchmarks(opts, config)
	local dir = config.RUNNERS_DIR
	local list = {}
	for _, d in pairs(fio.listdir(dir)) do
		output.debug(d)
		if fio.path.is_dir(fio.pathjoin(dir, d)) then
			table.insert(list, d)
		end
	end

	return list
end

local function _list_required_benchmarks(opts, config)
	local allBenches = _list_benchmarks(opts, config)
	local benchList = opts.benchmarks

	if benchList == 'all' then
		benchList = allBenches
	else
		benchList = opts.benchmarks:split(',')
		local available = utils.uniq(allBenches)
		for _, b in pairs(benchList) do
			utils.assert(available[b], ("benchmark='%s' doest not exist"):format(b), 1)
		end
	end

	return benchList
end

local function _get_bench_install_path(config, benchmark)
	return utils.assert(
		config[benchmark:upper() .. '_DIR'],
		("%s_DIR is not set in config"):format(benchmark:upper()),
		1
	)
end

local function _get_runinfo_filename(config)
	return fio.abspath(fio.pathjoin(config.BENCH_WORKDIR, 'runinfo.json'))
end

local function _get_tarantool_version(config)
	local e = exec({ config.env.TARANTOOL_EXECUTABLE, '--version'}, { output = 'PIPE' })
	local res = utils.read_all(e)
	return tostring(res:split('\n')[1]:split(' ')[2])
end

local function _list_results(config, verbose)
	utils.mkdir(config.RESULT_DIR)
	local list = fio.listdir(config.RESULT_DIR)
	table.sort(list, function(a, b) return a > b end)
	if verbose then
		for i = 1, #list do
			local ok = pcall(function()
				local runinfo = utils.read_file(config.RESULT_DIR, list[i], 'runinfo.json')
				runinfo = json.decode(runinfo)
				list[i] = ("%s    %s    %s"):format(
					list[i],
					tostring(runinfo.tarantool_version),
					os.date('%Y-%m-%dT%H:%M:%S', runinfo.start)
				)
			end)
			if not ok then
				list[i] = ("%s    broken"):format(list[i])
			end
		end
	end
	return list
end

local _runid
local function _get_run_id(config)
	if _runid then
		return _runid
	end

	local rList = _list_results(config)
	_runid = tonumber(rList[1]) or 0
	_runid = ("%05d"):format(_runid + 1)
	return _runid
end

local function _read_metrics(run, runInfo)
	if not runInfo then
		runInfo = json.decode(utils.read_file(run, 'runinfo.json'))
	end
	local metrics = {}
	local metricsRaw = utils.read_file(run, 'metrics.jsons')
	for _, l in pairs(metricsRaw:split('\n')) do
		if l ~= '' then
			local ok, data = pcall(json.decode, l)
			if not ok then
				output.debug(("line='%s'"):format(l))
				error(("failed at line=%d run=%s: %s"):format(_, run, data))
			end
			data.m.run = runInfo.runid
			if data.v == box.NULL then
				local order = data.m.order or 1
				data.v = (-1 * order) / 0
			end
			table.insert(metrics, data)
		end
	end

	return metrics
end

function commands.list_benchmarks(opts, config)
	return table.concat(_list_benchmarks(opts, config), "\n")
end

function commands.run(opts, config)
	local benchList = _list_required_benchmarks(opts, config)
	output.debug('Running benchmarks', benchList)

	local wd = config.BENCH_WORKDIR
	local rundir = config.RUNNERS_DIR
	local runid = _get_run_id(config)
	utils.rm(wd)
	utils.mkdir(wd)
	utils.write_file(_get_runinfo_filename(config), utils.pretty_json({
		start             = os.time(),
		runid             = runid,
		tarantool_version = _get_tarantool_version(config),
		benchmarks        = benchList,
		config            = config,
	}), 'O_APPEND')

	for _, b in pairs(benchList) do
		utils.cp(_get_bench_install_path(config, b), fio.pathjoin(wd, b))
		utils.cp(fio.pathjoin(rundir, b), fio.pathjoin(wd, b))
	end
	utils.cp(fio.pathjoin(rundir, 'common.sh'), fio.pathjoin(wd, 'common.sh'))

	-- error("QWE")

	output.info(config.env)
	for _, b in pairs(benchList) do
		local benchRunDir = fio.pathjoin(wd, b)
		local script = fio.pathjoin(wd, b, 'run.sh')
		exec(
			{ script },
			{ directory = benchRunDir, env = config.env }
		)
	end

	if not opts.skip_save then
		commands.save(opts, config)
	end
end

function commands.install(opts, config)
	local benchList = _list_required_benchmarks(opts, config)
	output.debug('Installing benchmarks', benchList)

	if not opts.force then
		for _, b in pairs(benchList) do
			local path = _get_bench_install_path(config, b)
			if fio.path.exists(path) then
				error(("install path='%s' is not empty, consider using --force flag"):format(path))
			end
		end
	end

	for _, b in pairs(benchList) do
		local path = _get_bench_install_path(config, b)
		local script = fio.pathjoin(config.RUNNERS_DIR, b, 'install.sh')
		utils.rm(path)
		utils.mkdir(path)
		output.info(("installing bench='%s' using script='%s' at path='%s'"):format(
			b, script, path
		))
		exec(
			{ script },
			{ directory = path, env = config.env }
		)
	end

	return
end

function commands.save(opts, config)
	local runInfoFile = _get_runinfo_filename(config)
	utils.assert(
		fio.path.exists(runInfoFile),
		("no info file='%s'"):format(runInfoFile)
	)

	local fh = utils.assert(fio.open(runInfoFile, { 'O_RDONLY' }))
	local j = utils.assert(fh:read())
	local runInfo = json.decode(j)
	local runid=runInfo.runid
	utils.assert(runid, ("info file='%s' is broken"):format(runInfoFile))
	local benchList = utils.assert(
		runInfo.benchmarks,
		("info file='%s' is broken"):format(runInfoFile)
	)

	utils.rm(config.RESULT_DIR, runid)
	utils.mkdir(config.RESULT_DIR, runid)
	utils.cp(runInfoFile, fio.pathjoin(config.RESULT_DIR, runid, 'runinfo.json'))

	local wd = config.BENCH_WORKDIR
	for _, b in pairs(benchList) do
		local e = exec({
			fio.pathjoin(wd, b, 'results.sh')
		}, {
			output = 'PIPE',
			directory = fio.pathjoin(wd, b),
		})

		local res = utils.read_all(e)
		local metrics = {}
		for _, v in pairs(res:split('\n')) do
			if v ~= '' then
				table.insert(metrics, v)
			end
		end

		-- jsons is not a typo, file is not a json file
		-- it consists of multiple lines
		-- each of the line is a json
		utils.write_file(
			fio.pathjoin(config.RESULT_DIR, runid, 'metrics.jsons'),
			table.concat(metrics, '\n'),
			'O_APPEND'
		)
	end
end

function commands.list_results(opts, config)
	return table.concat(_list_results(config, true), '\n')
end

function commands.delete_results(opts, config)
	local delList = opts.runs
	if #delList == 0 then
		error("empty run list provided")
	end

	if delList[1] == 'all' then
		delList = _list_results(config)
	end

	for _, run in pairs(delList) do
		local rmPath = fio.abspath(fio.pathjoin(config.RESULT_DIR, run))
		if rmPath:sub(1, config.RESULT_DIR:len()) ~= config.RESULT_DIR then
			error(("remove path='%s' is not under result path='%s'"):format(
				rmPath, config.RESULT_DIR
			))
		end
		utils.rm(fio.pathjoin(config.RESULT_DIR, run))
	end
end

function commands.cat(opts, config)
	local catList = opts.runs

	if catList[1] == 'last' then
		local l = _list_results(config)
		catList = { l[1] }
	end
	utils.assert(#catList > 0, "no runs specifed")

	local t = {}
	for _, run in pairs(catList) do
		for _, m in pairs(_read_metrics(fio.pathjoin(config.RESULT_DIR, run))) do
			table.insert(t, utils.json(m))
		end
	end

	return table.concat(t, '\n')
end

function commands.diff(opts, config)
	local diffList = opts.runs

	if diffList[1] == 'last' then
		local l = _list_results(config)
		diffList = { l[2], l[1] }
	end

	if #diffList ~= 2 then
		error(("Exactly 2 runs required, got %d"):format(#diffList))
	end

	local resDirs = {}
	for _, v in pairs(diffList) do
		table.insert(resDirs, fio.abspath(fio.pathjoin(config.RESULT_DIR, v)))
	end

	local runInfos = {}
	local runIDs   = {}
	local metrics  = {}

	for _, d in pairs(resDirs) do
		local rInfo = utils.read_file(d, 'runinfo.json')
		rInfo = json.decode(rInfo)
		utils.assert(rInfo.runid, ("run='%s' is broken: no runid"):format(d))
		table.insert(runIDs, rInfo.runid)
		table.insert(runInfos, rInfo)

		for _, m in pairs(_read_metrics(d, rInfo)) do
			table.insert(metrics, m)
		end
	end

	local metricsByName = {}
	for _, m in pairs(metrics) do
		metricsByName[m.k] = metricsByName[m.k] or {
			runs  = {},
			order = m.m.order and m.m.order or 1,
		}
		local metric = metricsByName[m.k]
		metric.runs[m.m.run] = metric[m.m.run] or {}
		table.insert(metric.runs[m.m.run], m.v)
	end

	local diffs = {}
	for mName, metric in pairs(metricsByName) do
		local diff = {
			metric = mName,
			order  = metric.order,
			runs   = {}
		}

		for run, runValues in pairs(metric.runs) do
			local calc = {}
			calc.avg   = stat.avg(runValues)
			calc.max   = stat.max(runValues)
			calc.min   = stat.min(runValues)
			calc.mean  = stat.mean(runValues)
			calc.stdev = stat.stdev(runValues, calc.mean)
			calc.cv    = stat.cv(runValues, calc.mean, calc.stdev)
			diff.runs[run] = calc
		end

		table.insert(diffs, diff)
	end

	table.sort(diffs, function(a, b) return a.metric < b.metric end)

	local result = {}
	for _, diff in pairs(diffs) do
		local v = { diff.metric, {} }
		local base = diff.runs[runIDs[1]]
		for i = 2, #runIDs do
			local run = diff.runs[runIDs[i]]
			local diffVerbose = {}
			for _, calc in pairs({ 'min', 'max', 'avg', 'mean' }) do
				diffVerbose[calc] = stat.diff(base[calc], run[calc], diff.order)
			end

			for _, calc in pairs({ 'stdev', 'cv' }) do
				diffVerbose[calc] = stat.diff(base[calc], run[calc], 1)
			end
			table.insert(v[2], diffVerbose)
		end

		table.insert(result, utils.json(v))
	end

	table.sort(result)
	return table.concat(result, '\n')
end

return commands
