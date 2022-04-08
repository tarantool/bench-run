local fio    = require 'fio'
local output = require 'lib.output'

local function read_config(file, overwrites)
	file = fio.readlink(file) or file
	file = fio.abspath(file)
	output.debug(("Config full path='%s'"):format(file))

	local _, err = fio.stat(file)
	if err then
		error(("%s: %s"):format(file, err), 2)
	end

	local cfg = dofile(file)
	for k, v in pairs(overwrites) do
		cfg.env[k] = v
	end

	-- popen does not allow to pass non-string params as env
	for k, v in pairs(cfg.env) do
		cfg.env[k] = tostring(v)
	end

	return cfg
end

return read_config
