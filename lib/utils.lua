local fio    = require 'fio'
local json   = require 'json'
local output = require 'lib.output'

local utils = {}

function utils.uniq(t)
	t = t or {}
	local r = {}

	for _, v in pairs(t) do
		r[v] = 1
	end

	return r
end

function utils.keys(t)
	t = t or {}
	local r = {}

	for k, _ in pairs(t) do
		table.insert(r, k)
	end

	return r
end

function utils.assert(v, err, extra_level)
	extra_level = tonumber(extra_level) or 0
	if not v then
		error(err, extra_level + 2)
	end

	return v
end

local safePaths = {
	'/home/',
	'/tmp/',
	'/opt/',
}

-- raises error if path is not under /home, /opt or /tmp
-- used to verify path before exectuting fio.rmtree not to
-- delete something important by accident
function utils.is_path_safe(path, extra_level)
	extra_level = tonumber(extra_level) or 0
	path = fio.abspath(path)

	local ok = false
	for _, sp in pairs(safePaths) do
		if path:sub(1, sp:len()) == sp then
			ok = true
			break
		end
	end

	if not ok then
		output.error(("directory='%s' is"):format(path))
		output.error("neither under /home/")
		output.error("nor under /opt/")
		output.error("nor under /tmp/")
		output.error("any other installation/run path is considered to be unsafe")
		output.error("as it is required to run rm -rf on the whole directory")
		output.error("if you think this is an error, consider patching the script yourself")
		output.error("if this is not the case, consider changing paths in config")
		error(("unsafe directory='%s' detected"):format(path), 2 + extra_level)
	end
end

-- removes both files and directories
-- raises on errors
-- returns false if path did not exist
function utils.rm(...)
	local path = fio.pathjoin(...)
	utils.is_path_safe(path, 1)
	if fio.path.exists(path) then
		output.debug(("rm path='%s'"):format(path))
		if fio.path.is_dir(path) then
			local ok, err = fio.rmtree(path)
			return utils.assert(ok, err, 1)
		else
			local ok, err = fio.unlink(path)
			return utils.assert(ok, err, 1)
		end
	end

	return false
end

-- almost the same as fio.mktree, but raises error if needed
function utils.mkdir(...)
	local path = fio.abspath(fio.pathjoin(...))
	output.debug(("mkdir path='%s'"):format(path))
	local ok, err = fio.mktree(path)
	return utils.assert(ok, err, 1)
end

-- copies both files and directories
-- raises on errors
function utils.cp(src, dst)
	utils.assert(fio.path.exists(src), ("src='%s' does not exist"):format(src), 1)

	output.debug(("copy src='%s' dst='%s'"):format(src, dst))
	if fio.path.is_dir(src) then
		local ok, err = fio.copytree(src, dst)
		return utils.assert(ok, err, 1)
	else
		local ok, err = fio.copyfile(src, dst)
		return utils.assert(ok, err, 1)
	end
end

function utils.merge_tables(...)
	local res = {}
	for _, t in pairs({ ... }) do
		for k, v in pairs(t) do
			res[k] = v
		end
	end

	return res
end

-- creates file if needed
-- append content to file (by default)
-- raises errors
function utils.write_file(name, content, m)
	local mode = { 'O_CREAT', 'O_WRONLY' }
	if m then
		table.insert(mode, m)
	end
	name = fio.abspath(name)
	output.debug(("writing mode='%s' path='%s'"):format(tostring(m), name))
	local fh, err = fio.open(name, mode, tonumber('666', 8))
	utils.assert(fh, err, 1)
	local ok, err = fh:write(tostring(content) .. '\n')
	utils.assert(ok, err, 1)
	return utils.assert(fh:close(), "Failed to close fh", 1)
end

function utils.read_file(...)
	local name = fio.abspath(fio.pathjoin(...))
	output.debug(("reading file path='%s'"):format(name))
	local fh, err = fio.open(name, { 'O_RDONLY' })
	utils.assert(fh, err, 1)
	local content, err = fh:read()
	utils.assert(not err, content, 1)
	output.debug(("read %d bytes of content"):format(content:len()))
	utils.assert(fh:close(), "Failed to close fh", 1)
	return content
end

local function is_array(t)
	local mt = getmetatable(t)
	if mt and mt.__serialize == 'seq' then
		return true
	end

	for k, _ in pairs(t) do
		if type(k) ~= 'number' then
			return false
		end
	end

	return true
end

local indentSymbol = '    '
local function json_encode(vv, indent)
	if indent > 100 then
		error("The structure is too deep: 100")
	end

	if type(vv) == 'string' then
		-- TODO: remove slash escaping
		return json.encode(vv)
	elseif type(vv) == 'number' then
		if vv % 1 == 0 then
			return tostring(vv)
		else
			return ('%.15f'):format(vv)
		end
	elseif type(vv) == 'table' then
		if is_array(vv) then
			if #vv == 0 then
				return '[]'
			end
			local t = {}
			for _, elem in ipairs(vv) do
				table.insert(t, json_encode(elem, indent + 1))
			end
			local str = '['
			if indent >= 0 then
				str = str .. '\n' .. indentSymbol:rep(indent + 1)
					.. table.concat(t, ',\n' .. indentSymbol:rep(indent + 1))
					.. '\n' .. indentSymbol:rep(indent) .. ']'
			else
				str = str .. table.concat(t, ',') .. ']'
			end

			return str
		else
			local values = {}
			for k, v in pairs(vv) do
				if type(k) == 'string' then
					table.insert(values, { k, v })
				elseif type(k) == 'number' then
					table.insert(values, { tostring(k), v })
				else
					error(("Unsupported Lua type '%s'"):format(type(k)))
				end
			end
			table.sort(values, function(a, b) return a[1] < b[1] end)
			local strList = {}
			for _, elem in pairs(values) do
				local template = "%s:%s"

				-- indent == fancy
				if indent >= 0 then
					template = "%s: %s"
				end

				table.insert(
					strList,
					template:format(json_encode(elem[1], -1/0), json_encode(elem[2], indent + 1))
				)
			end
			local str = '{'

			if indent >= 0 then
				str = str .. '\n' .. indentSymbol:rep(indent + 1)
					.. table.concat(strList, ',\n' .. indentSymbol:rep(indent + 1))
					.. '\n' .. indentSymbol:rep(indent) .. '}'
			else
				str = str .. table.concat(strList, ',') .. '}'
			end

			return str
		end
	else
		error(("Unsupported Lua type '%s'"):format(type(vv)))
	end
end

-- as json.encode but
-- does not encode small floats in this(1.4543533325195e-05) annoying notation
-- that is impossible to parse by looking at it
--
-- all keys are sorted so that every json line with the same schema looks consistent
--
-- has indentation
function utils.pretty_json(v)
	return json_encode(v, 0)
end

-- as pretty_json but not pretty
function utils.json(v)
	return json_encode(v, -1/0)
end

function utils.read_all(h)
	local res = ''
	local str, err = h:read()
	while not err and str ~= '' do
		utils.assert(not err, str, 1)
		res = res .. str
		str, err = h:read()
	end

	return res
end

return utils
