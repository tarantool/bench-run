#!/bin/bash

set -eou pipefail

function _get_workload_info {
	case "$1" in
		a)
			echo 'r50u50';;
		b)
			echo 'r95u5';;
		c)
			echo 'r100';;
		d)
			echo 'r95i5';;
		e)
			echo 's95i5';;
		f)
			echo 'r50rmw50';;
		*)
			echo "Unknown workload='$1'"
			exit 100;;
	esac
}

for f in results/ycsb.*_result.txt; do
	engine="${f#results/ycsb.}"
	engine="${engine%_result.txt}"

	while read -ra line; do
		workload=
		workload="$(_get_workload_info "${line[0]}")"
		run="${line[1]}"
		run="${run%:}"
		value="${line[2]}"
		printf '{"k":"ycsb.%s.%s","v":%0.3f,"m":{"run":%d}}\n' "$engine" "$workload" "$value" "$run"
	done < "$f"
done
