local utils = require 'lib.utils'

local __parser_mt = {}

local function _assert(v, err, extra_level)
	extra_level = tonumber(extra_level) or 0
	utils.assert(v, err, extra_level + 2)
end

local function is_self(s)
	return getmetatable(s) == __parser_mt
end

local function argnames(str)
	local names = {}

	for _, v in pairs(str:split(' ')) do
		if v ~= '' then
			table.insert(names, v)
		end
	end

	_assert(#names > 0, "argument name can not be empty")
	return names
end

local function argconflict(self, names)
	for _, v in pairs(names) do
		if self.__arguments[v] then
			error(("key='%s' was already set for parsing"):format(v))
		end

		if self.__commands[v] then
			error(("key='%s' is conflicting with command"):format(v))
		end

		for k, _ in pairs(self.__kv) do
			if v:sub(1, k:len()) == k then
				error(("key='%s' is conlicting with kv argument '%s'"):format(v, k))
			end
		end
	end
end

local m = {}

-- name of a program and some basic info
function m.add_proginfo(self, name, help)
	_assert(is_self(self), "usage self:method")
	_assert(type(name) == 'string', "argument #1(name) is required to be string")
	_assert(type(help) == 'string', "argument #2(help) is required to be string")

	_assert(self.__proginfo.n == nil, "proginfo is already set")
	self.__proginfo = {
		n = name,
		h = help,
	}

	return self
end

-- parse boolean flags with no value required
function m.add_flag(self, name, help, default)
	_assert(is_self(self), "usage self:method")
	_assert(type(name) == 'string', "argument #1(name) is required to be string")
	_assert(type(help) == 'string', "argument #2(help) is required to be string")

	local names = argnames(name)
	argconflict(self, names)

	local arginfo = {
		t = 'boolean',
		h = help,
		d = not not default,
		n = name,
	}

	for _, v in pairs(names) do
		self.__arguments[v] = arginfo
	end

	self.__arguments[name] = arginfo

	return self
end

local allowed_types = { string = true, number = true }

-- parse normal arguments with values
function m.add_argument(self, name, help, t, default)
	_assert(is_self(self), "usage self:method")
	_assert(type(name)    == 'string', "argument #1(name) is required to be string")
	_assert(type(help)    == 'string', "argument #2(help) is required to be string")
	_assert(type(t)       == 'string', "argument #3(type) is required to be string")
	_assert(allowed_types[t], "argument #3(type) represents forbidden type (string and number allowed)")
	_assert(type(default) == t, ("argument #4(default) is required to be %s"):format(t))

	local names = argnames(name)
	argconflict(self, names)

	local arginfo = {
		t = t,
		h = help,
		d = default,
		n = name,
	}

	self.__arguments[name] = arginfo

	for _, v in pairs(names) do
		self.__arguments[v] = arginfo
	end

	return self
end

-- parse arguments like -DKEY1=VALUE1 -DKEY2=VALUE2
function m.add_kv(self, prefix, help)
	_assert(is_self(self), "usage self:method")
	_assert(type(prefix) == 'string', "argument #1(prefix) is required to be string")
	_assert(type(help)   == 'string', "argument #2(help) is required to be string")

	local names = argnames(prefix)
	_assert(#names == 1, "kv argument can only consist of single prefix")

	argconflict(self, names)

	for k, _ in pairs(self.__arguments) do
		if k:sub(1, prefix:len()) == names[1] then
			error(("key='%s' is conlicting with kv argument '%s'"):format(k, names[1]))
		end
	end

	for k, _ in pairs(self.__commands) do
		if k:sub(1, prefix:len()) == names[1] then
			error(("command='%s' is conlicting with kv argument '%s'"):format(k, names[1]))
		end
	end

	self.__kv[prefix] = {
		t = 'kv',
		n = prefix,
		h = help,
	}

	return self
end

-- any argument that is not parsed as a part of kv/flag/argument is considered
-- to be a command
function m.add_command(self, cmd, help)
	_assert(is_self(self), "usage self:method")
	_assert(type(cmd)  == 'string', "argument #1(cmd) is required to be string")
	_assert(type(help) == 'string', "argument #2(help) is required to be string")

	argconflict(self, { cmd })
	_assert(self.__commands[cmd] == nil, ("command='%s' is already set for parsing"):format(cmd))

	self.__commands[cmd] = {
		n = cmd,
		h = help,
	}

	return self
end

-- perform actual parsing
function m.parse(self, args)
	_assert(is_self(self), "usage self:method")
	_assert(type(args) == 'table', "argument #1(args) is required to be table")
	local curr_arg = false

	for i = 1, #args do
		if curr_arg then
			local n = curr_arg.n
			local v = args[i]
			if curr_arg.t == 'number' then
				local vv = tonumber(v)
				_assert(vv, ("argument='%s' value='%s' is not a number"):format(n, v))
				v = vv
			end

			_assert(self.__parsed_arguments[n] == nil, ("argument='%s' is already parsed"):format(n))
			self.__parsed_arguments[n] = {
				set = true,
				value = v,
			}
			curr_arg = false
		else
			local k = args[i]
			local a = self.__arguments[k]
			if a then
				_assert(self.__parsed_arguments[a.n] == nil, ("argument='%s' is already parsed"):format(a.n))
				if a.t == 'boolean' then
					self.__parsed_arguments[a.n] = {
						set = true,
						value = not a.d,
					}
				else
					curr_arg = a
				end
			else
				local k = args[i]
				local found = false
				for kv, _ in pairs(self.__kv) do
					if k:sub(1, kv:len()) == kv then
						local kvset = k:sub(kv:len() + 1, -1)
						local del = kvset:find('=')
						_assert(del, ("error parsing kv='%s' no '=' symbol found"):format(kv))
						local key = kvset:sub(1, del - 1)
						local value = kvset:sub(del + 1, -1)
						self.__parsed_kv[kv] = self.__parsed_kv[kv] or {}
						self.__parsed_kv[kv][key] = value
						found = true
						break
					end
				end

				if not found then
					local cmdinfo = self.__commands[k]
					_assert(cmdinfo, ("unknown key='%s'"):format(k))
					_assert(not self.__parsed_command, 'only one command is allowed at a time')
					self.__parsed_command = k
				end
			end
		end
	end

	for k, v in pairs(self.__arguments) do
		if not self.__parsed_arguments[v.n] then
			self.__parsed_arguments[v.n] = {
				set = false,
				value = v.d,
			}
		end
	end

	return true
end

function m._get_argument_raw(self, name)
	_assert(is_self(self), "usage self:method", 1)
	_assert(type(name) == 'string', "argument #1(name) is required to be string", 1)

	local arginfo = self.__arguments[name]
	_assert(arginfo, ("unknown argument='%s'"):format(name))

	local longname = arginfo.n

	return self.__parsed_arguments[longname]
end

function m.get_argument(self, name)
	return m._get_argument_raw(self, name).value
end

function m.is_argument_set(self, name)
	return m._get_argument_raw(self, name).set
end

function m.get_kv_argument(self, prefix)
	_assert(is_self(self), "usage self:method")
	_assert(type(prefix) == 'string', "argument #1(prefix) is required to be string")

	local arginfo = self.__kv[prefix]
	_assert(arginfo, ("unknown kv argument='%s'"):format(prefix))

	return self.__parsed_kv[prefix] or {}
end

function m.get_command(self)
	_assert(is_self(self), "usage self:method")
	return self.__parsed_command
end

function m.form_help_message(self)
	_assert(is_self(self), "usage self:method")

	local args = {}

	for _, v in pairs(self.__arguments) do
		args[v] = 1
	end

	local arglist = {}
	for v, _ in pairs(args) do
		table.insert(arglist, v.n)
	end

	local kvlist = {}
	for k, _ in pairs(self.__kv) do
		table.insert(kvlist, k)
	end

	table.sort(arglist)
	table.sort(kvlist)

	local scriptName = 'script'
	local usageInfo = ''
	local hasCommand = ''
	if next(self.__commands) then
		hasCommand = ' [COMMAND]'
	end

	if self.__proginfo.n then
		scriptName = self.__proginfo.n
		usageInfo = self.__proginfo.h
	end

	local help = ("Usage: %s [OPTIONS]%s\n%s\n"):format(
		scriptName, hasCommand, usageInfo
	)

	if next(self.__commands) then
		help = ("%s\nThe commands are:\n"):format(help)
		local cmdList = {}
		for _, v in pairs(self.__commands) do
			table.insert(cmdList, v)
		end
		table.sort(cmdList, function(a, b) return a.n < b.n end)
		for _, cmdinfo in pairs(cmdList) do
			help = ("%s    %s:\n        %s\n"):format(help, cmdinfo.n, cmdinfo.h)
		end
	end

	if #arglist + #kvlist == 0 then
		return help
	end

	help = ("%s\n\nThe options are:"):format(help)

	for _, a in pairs(arglist) do
		local arginfo = self.__arguments[a]
		if arginfo.t == 'boolean' then
			help = ("%s\n    %s (defaults to %s)\n        %s\n"):format(
				help, arginfo.n, arginfo.d, arginfo.h)
		elseif arginfo.t == 'string' then
			help = ("%s\n    %s 'string' (defaults to '%s')\n        %s\n"):format(
				help, arginfo.n, arginfo.d, arginfo.h)
		elseif arginfo.t == 'number' then
			help = ("%s\n    %s number (defaults to %s)\n        %s\n"):format(
				help, arginfo.n, arginfo.d, arginfo.h)
		end
	end

	for _, kv in pairs(kvlist) do
		local kvinfo = self.__kv[kv]
		help = ("%s\n    %sKEY=VALUE\n        %s\n"):format(help, kvinfo.n, kvinfo.h)
	end

	return help
end

__parser_mt = {
	__index = m,
	__call = function(self, ...)
		return self:parse(...)
	end,
}

local function parser()
	return setmetatable({
		__arguments        = {},
		__kv               = {},
		__parsed_arguments = {},
		__parsed_kv        = {},
		__commands         = {},
		__parsed_command   = false,
		__proginfo         = {},
	}, __parser_mt)
end

return parser
