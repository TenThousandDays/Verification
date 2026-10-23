#!/usr/bin/env bash
set -eo pipefail
cd "$(dirname "$0")"

spin -a booking.pml
cc -DMEMLIM=1024 -O2 -DCOLLAPSE -o pan pan.c > /dev/null 2>&1

failed=0
for claim in S1 S2 S3 S4 S5 S6 L1 L2 L3 L4; do
    printf '\nChecking claim #%s...\n' "$claim"
    if output=$(./pan -m10000 -a -N "$claim" -b 2>&1) &&
       [[ "$output" == *"errors: 0"* && "$output" != *"Search not completed"* ]]; then
        printf '\033[32mclaim #%s ... OK\033[0m\n' "$claim"
    elif [[ "$output" == *"MEMLIM bound"* ]]; then
        printf '\033[31mclaim #%s ... FAIL (memory limit; search incomplete)\033[0m\n' "$claim"
        failed=1
    else
        printf '\033[31mclaim #%s ... FAIL\033[0m\n' "$claim"
        failed=1
    fi
done
exit "$failed"
