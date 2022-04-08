#!/bin/bash

set -euo pipefail

while IFS=: read -ra line; do
	metric="${line[0]}"
	value="${line[1]}"
	if [ "$value" == 0 ]; then
		value='null'
	else
		value="$(printf '%0.3f' "$value")"
	fi
	# a way to say 'smaller is better'
	meta='{"order":-1}'

	printf '{"k":"tpch.%s","v":%s,"m":%s}\n' "$metric" "$value" "$meta"
done < tpc.h_result.txt
