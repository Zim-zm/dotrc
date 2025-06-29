#!/bin/bash

set -Eeuo pipefail

current_dir="$(cd "$(dirname "$1")" && pwd -P)"
build_dir="$(git -C "$current_dir" rev-parse --show-toplevel)"/tis-analyzer

make -C "$build_dir"
make -C "$build_dir" install
