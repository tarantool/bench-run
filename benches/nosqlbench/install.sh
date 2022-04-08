#!/usr/bin/env bash

set -xeuo pipefail

git clone --recursive https://github.com/tarantool/nosqlbench.git "$PWD"
git submodule foreach --recursive
cmake .
make -j
