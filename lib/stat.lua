local stat = {}

function stat.max(t)
	return math.max(unpack(t))
end

function stat.min(t)
	return math.min(unpack(t))
end

function stat.avg(t)
	local sum = 0
	local cnt = 0

	for _, v in pairs(t) do
		sum = sum + v
		cnt = cnt + 1
	end

	return sum/cnt
end

function stat.mean(t)
	local tt = table.deepcopy(t)
	table.sort(tt)
	local idx = math.ceil(#tt / 2)
	return tt[idx]
end

function stat.stdev(t, mean)
	mean = mean or stat.mean(t)

	local sum = 0
	for _, v in pairs(t) do
		sum = sum + (v - mean)^2
	end

	return math.sqrt(sum/#t)
end

function stat.cv(t, mean, stdev)
	mean = mean or stat.mean(t)
	stdev = stdev or stat.stdev(t, mean)
	return stdev / math.abs(mean)
end

function stat.diff(a, b, order)
	order = order or 1
	if order < 0 then
		order = -1
	end

	if a > b then
		order = order * -1
	end
	a, b = math.min(a, b), math.max(a, b)

	-- special case for a == b == 0
	local res
	if a == b then
		res = 0
	else
		res = order * (1 - a/b)
	end

	return res
end

return stat
