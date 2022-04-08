#!/usr/bin/env bash

set -xeuo pipefail

git clone https://github.com/tarantool/tpcc.git "$PWD"
cd src
make -j
cd ..
