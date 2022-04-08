#!/usr/bin/env bash

set -xeuo pipefail

git clone https://github.com/tarantool/sysbench.git "$PWD"
./autogen.sh
./configure --with-tarantool --without-mysql
make -j
