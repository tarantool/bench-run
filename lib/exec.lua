local fiber  = require 'fiber'
local output = require 'lib.output'
local utils  = require 'lib.utils'

local ok, popen = pcall(require, 'popen')
if not ok then
	print(output.version_message())
	os.exit(100)
end

local defaultOpts = {
	raise     = true,
	raw       = false,
	timeout   = -1,
	directory = false,
	output    = 'INHERIT',
}

local exec = { silent = false }

local function escape(v)
	-- TODO implement actual escaping
	return tostring(v)
end

local function _exec(argv, opts)
	opts = opts or {}

	assert(type(argv) == 'table', 'array table required as argument #1')
	assert(type(opts) == 'table', 'kv table required as argument #2')

	local cmdLine = ''
	for _, v in ipairs(argv) do
		cmdLine = ('%s %s'):format(cmdLine, escape(v))
	end

	cmdLine = cmdLine:lstrip(' ')

	local o = table.deepcopy(opts)
	for k, v in pairs(defaultOpts) do
		if o[k] == nil then
			o[k] = v
		end
	end

	-- could have done fio.chdir, but I do not have
	-- enough faith in popen module that there is no some
	-- strange race condition where you can chdir back fast
	-- enough so the process will run in your starting directory
	if o.directory then
		cmdLine = ('cd %s && %s'):format(o.directory, cmdLine)
	end

	local outopt
	if exec.silent then
		outopt = popen.opts.DEVNULL
	else
		outopt = popen.opts[o.output]
	end

	local cmd = popen.new({cmdLine}, {
		shell  = true,
		stdout = outopt,
		stderr = outopt,
		env    = utils.merge_tables(os.environ(), o.env),
	})

	if o.raw then
		return cmd
	end

	local ch = fiber.channel()

	fiber.new(function()
		cmd:wait()
		ch:put(true, 0)
	end)

	if o.timeout >= 0 then
		fiber.new(function()
			fiber.sleep(o.timeout)
			ch:put(false, 0)
		end)
	end

	local timeout_ok = ch:get()
	if not timeout_ok then
		error("timeout")
	end

	if o.raise then
		if cmd.status.exit_code ~= 0 then
			output.error(("script='%s' failed with ec='%d'"):format(cmdLine, cmd.status.exit_code))
			error(cmd)
		end
	end

	return cmd
end

setmetatable(exec, {
	__call = function (self, ...)
		return _exec(...)
	end,
})

return exec
