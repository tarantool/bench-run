#!/usr/bin/env bash

set -xeuo pipefail

git clone https://github.com/tarantool/YCSB.git "$PWD"
mvn clean package
