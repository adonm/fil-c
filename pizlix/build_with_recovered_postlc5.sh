#!/bin/bash

set -e
set -x

./build_recover_postlc5.sh
./build_postlc6_continuation.sh

echo OK