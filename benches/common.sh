#!/bin/bash

# will not work if not under root
# if benches are run locally by a developer droping caches might not be too
# important
function maybe_drop_cache {
	if test -w /proc/sys/vm/drop_caches; then
		echo 3 > /proc/sys/vm/drop_caches
	else
		echo "disk cache was not dropped"
	fi
}

# returns numactl options as string
# available modes are
#    tarantool - returns options for the first 3 cores
#    benchmark - returns options for every core available except for first 3
function get_numa_cpu_option {
	local mode="$1"
	case "$mode" in
		tarantool)
			true;;
		benchmark)
			true;;
		*)
			echo "Incorrect mode for numactl='$mode', available are 'tarantool', 'benchmark'"
			return 1;;
	esac

	if which numactl 1>/dev/null 2>/dev/null; then
		read -ra numacpu <<< "$(numactl --show | grep physcpubind | awk -F: '{ print $2 }')"
		local ncpus="${#numacpu[@]}"

		# it is useless to balance benchmark on cores if there are only 3 or less
		# TODO: discuss - maybe it is useless to try to balance cores on even bigger core amounts
		if [ "$ncpus" -le 3 ]; then
			echo ""
		fi

		local option=
		option="$(seq -s, 0 2)"
		if [ "$mode" == 'benchmark' ]; then
			option="$(seq -s, 3 "$(( ncpus - 1 ))")"
		fi
		echo "--physcpubind=$option"
	else
		echo ""
	fi
}

# runs either tarantool or benchmark under numactl
# if there are enough cores on the machine, this will ensure
# that tarantool and the benchmark do not share cores
function under_numa {
	local mode="$1"
	shift
	local option
	option="$(get_numa_cpu_option "$mode")"
	if [ -z "$option" ]; then
		"$@"
	else
		numactl "$option" -- "$@"
	fi
}

function get_owner_pid_port {
	local port="$1"
	netstat -lpn 2>/dev/null | grep ":$port" | awk '{ print $7 }' | sed 's#/.*$##'
}

function get_owner_pid_file {
	local f="$1"
	lsof "$f" 2>/dev/null | awk '{ print $2 }' | grep -v PID | sort | uniq
}

function get_owner_pid {
	local identifier="$1"
	if [[ "$identifier" =~ ^[0-9]+$ ]]; then
		get_owner_pid_port "$identifier"
		return 0
	fi

	get_owner_pid_file "$identifier"
}

function get_tarantool_version {
	"$TARANTOOL_EXECUTABLE" -v | grep -e "Tarantool" |  grep -oP '\s\K\S*'
}

# remove snapshots, wal-logs and vinyl directories
function clean_tarantool {
	rm -rf \
		./*.snap \
		./*.xlog \
		./*.vylog \
		5*
}

function sync_disk {
	sync && echo "sync passed" || echo "sync failed with error: $?"
}

function kill_tarantool {
	(
		for pid in $(get_owner_pid "$1"); do
			kill "$pid" || true
		done
	) || true
}

function error {
	local _caller
	_caller=( $(caller 0) )
	echo "${_caller[2]} line=${_caller[0]} fn=${_caller[1]} ERROR:" "$@"
	exit 100
}

function stop_and_clean_tarantool {
	kill_tarantool "$1"
	clean_tarantool
	sync_disk
}

function wait_for_file_release {
	local f="$1"
	local t="$2"
	local tt=0

	[ ! -f "$f" ] && return 0

	while [ "$tt" -lt "$t" ]; do
		if ! lsof "$f" 1>/dev/null 2>/dev/null; then
			return 0
		fi

		tt=$(( tt + 1 ))
		sleep 1
	done

	return 1
}

function wait_for_port_release {
	local p="$1"
	local t="$2"
	local tt=0

	while [ "$tt" -lt "$t" ]; do
		if ! netstat -lpn 2>/dev/null | grep -q ":$p"; then
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
