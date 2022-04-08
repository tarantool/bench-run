#!/bin/bash

set -euo pipefail

IFS=: read -ra line < tpc.c_result.txt

printf '{"k":"tpcc","v":%0.3f,"m":{}}\n' "${line[1]}"
