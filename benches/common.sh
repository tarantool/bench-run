# will not work if not under root
# if benches are run localy by a developer droping caches might not be too important
function maybe_drop_cache {
	if test -w /proc/sys/vm/drop_caches; then
		echo 3 > /proc/sys/vm/drop_caches
	fi
}

function can_be_run_under_numa {
	numactl "$@" true 1>/dev/null 2>/dev/null
}

# not every local machine has numa enabled on it
# not every local machine has enough hardware units to run with intended configuration
#
# usage:
# maybe_under_numactl numaoptions -- command to run
# example:
# maybe_under_numactl --membind=1 --cpunodebind=1 --physcpubind=11 -- echo qwe
function maybe_under_numactl {
	local numaoptions=()
	local cmdoptions=()
	local parsing_numa=1
	for option in "$@"; do
		if [ -n "$parsing_numa" ]; then
			if [ "$option" == -- ]; then
				parsing_numa=
			else
				numaoptions+=( "$option" )
			fi
		else
			cmdoptions+=( "$option" )
		fi
	done

	if which numactl 1>/dev/null 2>/dev/null; then
		# check if it is even runable with given numactl options
		if can_be_run_under_numa "${numaoptions[@]}"; then
			numactl "${numaoptions[@]}" "${cmdoptions[@]}"
		else
			"${cmdoptions[@]}"
		fi
	else
		"${cmdoptions[@]}"
	fi
}

function get_tarantool_version {
	"$TARANTOOL_EXECUTABLE" -v | grep -e "Tarantool" |  grep -oP '\s\K\S*'
}

function clean_tarantool {
	rm -rf ./*.snap
	rm -rf ./*.xlog
	rm -rf ./*.vylog
	rm -rf 5*
}

function sync_disk {
	sync && echo "sync passed" || echo "sync failed with error: $?"
}

function kill_tarantool {
	killall tarantool 2>/dev/null || true
}

function error {
	local _caller
	_caller=( $(caller 0) )
	echo "${_caller[2]} line=${_caller[0]} fn=${_caller[1]} ERROR:" "$@"
	exit 100
}

function stop_and_clean_tarantool {
	kill_tarantool
	clean_tarantool
	sync_disk
}

function wait_for_file_release {
	local f="$1"
	local t="$2"
	local tt=0
	while [ "$tt" -lt "$t" ]; do
		if ! lsof "$f" 1>/dev/null 2>/dev/null; then
			return 0
		fi

		tt=$(( tt + 1 ))
		sleep 1
	done

	return 1
}

function wait_for_tarantool_runnning {
	local creds="$1"
	local t="$2"
	local tt=0

	while [ "$tt" -lt "$t" ]; do
		if echo 'if type(box.cfg) ~= "function" then return box.info().status end' | "$TARANTOOLCTL_EXECUTABLE" connect "$creds" 2>/dev/null | grep -q 'running'; then
			return 0
		fi

		tt=$(( tt + 1 ))
		sleep 1
	done

	return 1
}

function is_directory_empty {
	local d="$1"

	[ ! -d "$d" ] && error "no such directory '$d'"

	if find "$d/" -maxdepth 1 -mindepth 1 | grep -q .; then
		return 1
	else
		return 0
	fi
}
