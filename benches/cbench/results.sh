#!/bin/bash

set -euo pipefail

for f in cbench_output_*.txt; do
	engine="${f#cbench_output_}"
	engine="${engine%.txt}"
	while read -r line; do
		metric="$(echo "$line" | grep -oP 'name=cb\.\K[\w\.]*')"
		value="$(echo "$line" | grep -oP 'param=\K\d*')"
		printf '{"k":"cbench.%s.%s","v":%0.3f,"m":{}}\n' "$engine" "$metric" "$value"
	done <<< "$(grep '^\?' "$f")"
done
