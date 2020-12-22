#!/usr/bin/env bash

set -xeuo pipefail

git clone https://github.com/tarantool/cbench.git "$PWD"

cmake . -DCMAKE_BUILD_TYPE=RelWithDebInfo
make -j
