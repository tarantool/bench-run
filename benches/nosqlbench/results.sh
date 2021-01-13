#!/bin/bash

set -euo pipefail

for f in noSQLbench.*_result.txt; do
	engine="${f#noSQLbench.}"
	engine="${engine%_result.txt}"
	while read -ra line; do
		# transform 'op/s' to 'op'
		metric="${line[0]%/s}"
		value="${line[2]}"
		printf '{"k":"nosqlbench.%s.%s","v":%0.3f,"m":{}}\n' "$engine" "$metric" "$value"
	done < "$f"
done
