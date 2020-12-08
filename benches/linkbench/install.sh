#!/usr/bin/env bash

set -euo pipefail

git clone https://github.com/tarantool/linkbench.git -b update-fixes "$PWD"

luarocks install https://raw.githubusercontent.com/tarantool/gperftools/master/rockspecs/gperftools-scm-1.rockspec \
    --tree .rocks --lua-version 5.1
