#!/usr/bin/env bash

set -xeuo pipefail

# FIXME: review and merge branch in master
git clone https://github.com/tarantool/linkbench.git -b update-fixes "$PWD"

luarocks install https://raw.githubusercontent.com/tarantool/gperftools/master/rockspecs/gperftools-scm-1.rockspec \
    --tree .rocks --lua-version 5.1
