#!/bin/bash

set -euo pipefail

while read -ra line; do
	k="${line[0]%:}"
	v="${line[1]}"
	printf '{"k":"%s","v":%f,"m":{}}\n' "$k" "$v"
done < Sysbench_result.txt
