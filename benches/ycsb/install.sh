#!/usr/bin/env bash

set -euo pipefail

git clone https://github.com/tarantool/YCSB.git "$PWD"
mvn clean package
