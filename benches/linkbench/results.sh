#!/bin/bash

set -euo pipefail

IFS=: read -ra result < linkbench.ssd_result.txt

printf '{"k":"linkbench","v":%0.3f,"m":{}}\n' "${result[1]}"
