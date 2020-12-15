local yaml = require 'yaml'

local M = {}

local debug  = false
local silent = false

local function _str(v)
	if type(v) == 'table' then
		return yaml.encode(v)
	else
		return tostring(v)
	end
end

function M.set_silent(v)
	silent = not not v
end

function M.set_debug(v)
	debug = not not v
end

local function _print(fh, pfx, ...)
	if pfx ~= '' then
		pfx = ("[%s] "):format(pfx)
	end

	for _, v in pairs({ ... }) do
		for _, s in pairs(_str(v):split("\n")) do
			fh:write(("%s%s\n"):format(pfx, s))
		end
	end

	fh:flush()
end

function M.raw(...)
	if silent then
		return
	end

	_print(io.stdout, '', ...)
end

function M.debug(...)
	if silent then
		return
	end

	if not debug then
		return
	end

	_print(io.stderr, 'DEBUG', ...)
end

function M.info(...)
	if silent then
		return
	end

	_print(io.stderr, 'INFO', ...)
end

function M.error(...)
	if silent then
		return
	end

	_print(io.stderr, 'ERROR', ...)
end

function M.version_message()
	local t = {
		'',
		'                ██████████████████████',
		'            ████░░    ████░░░░      ▒▒████',
		'          ██    ░░        ██░░░░░░▒▒▒▒▒▒▒▒██',
		'        ██  ░░░░▒▒▒▒▒▒      ██▒▒▒▒▒▒▒▒▒▒▒▒▒▒██',
		'      ██  ░░░░▒▒░░    ▒▒      ██░░░░        ▒▒██',
		'    ██░░░░░░▒▒░░▒▒      ▒▒      ██▒▒▒▒░░░░░░▒▒▒▒██',
		'    ██  ░░▒▒░░░░  ██▓▓    ▒▒    ██▒▒▒▒▓▓▒▒▒▒▒▒▒▒██',
		'  ██░░░░░░▒▒░░░░██████▒▒  ▒▒    ░░██░░░░░░░░░░░░▒▒██',
		'  ██  ░░▒▒░░▒▒██▒▒▒▒▒▒██▒▒░░▒▒    ██░░░░░░░░░░░░▒▒██',
		'  ██  ░░▒▒░░██▒▒        ██▒▒▒▒    ██▒▒▒▒▒▒▒▒▒▒▒▒▒▒██',
		'██░░  ▓▓▒▒░░██▒▒        ██▒▒  ▓▓▒▒░░██            ▒▒██',
		'██    ▒▒░░░░██▒▒              ▒▒▒▒  ██░░░░░░░░░░░░▒▒██',
		'██  ░░▒▒░░    ██▓▓            ▓▓░░  ██▓▓▒▒▒▒▒▒▒▒▒▒▒▒██',
		'██  ░░▒▒░░      ████▒▒        ▒▒░░  ██░░░░░░░░  ░░▒▒██',
		'██░░░░▒▒            ██▒▒    ░░▒▒▒▒  ██░░░░░░░░▒▒░░▒▒██',
		'██░░░░▒▒              ██▒▒  ░░▒▒░░░░██▒▒▒▒▒▒▒▒▒▒▒▒▒▒██',
		'██░░░░▒▒                ██▓▓░░▒▒░░░░██            ▒▒██',
		'██░░░░▒▒    ██▒▒        ██▒▒░░▒▒░░░░██░░░░░░░░░░░░▒▒██',
		'  ██    ▓▓  ██▒▒        ██▒▒▒▒░░░░██▒▒▒▒▒▒▒▒▒▒▒▒▒▒██',
		'  ██    ▒▒  ░░██▒▒    ▓▓▓▓▒▒▒▒░░░░██░░░░░░░░░░░░▒▒██',
		'  ██      ▓▓    ██████▒▒░░▒▒░░░░░░██░░▒▒░░░░░░░░▒▒██',
		'    ██    ▒▒      ██▒▒░░░░▒▒░░░░██▒▒▒▒▒▒▒▒▒▒▒▒▒▒██',
		'    ██    ░░▓▓      ░░░░▒▒░░░░░░██            ▒▒██',
		'      ▓▓    ░░▒▒    ░░▒▒▒▒░░░░██░░░░░░░░░░░░▒▒██',
		'        ██      ▒▒▓▓▒▒░░░░░░██▒▒▒▒▒▒▒▒▒▒▒▒▒▒██',
		'          ██      ░░▒▒▒▒░░██  ░░░░░░  ▒▒▒▒██',
		'            ████▒▒░░░░████░░░░░░░░░░▒▒████',
		'                ▓▓████████▓▓██▓▓▓▓▓▓██',
		'                ░░░░▒▒  ░░░░░░░░░░░░░░',
		'',
		'',
		'Here is a coin, kid',
		'Go buy yourself some real tarantool with popen module (2.4+)',
	}

	return table.concat(t, '\n')
end

return M
