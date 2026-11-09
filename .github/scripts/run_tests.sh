#!/usr/bin/env bash
# Runs the gdUnit4 tests in the given res:// directory and fails on test failures, missing tests or compile errors.
# Usage: run_tests.sh res://tests/unit
set -o pipefail
log="$(basename "$1").log"
"$GODOT_BIN" --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a "$1" 2>&1 | tee "$log" || exit 1
# gdUnit exits with 0 when it finds no tests at all, e.g. because a test script does not compile
if grep -q "No test cases found" "$log"; then exit 1; fi
# Scripts that fail to compile do not always fail a test
if grep -E "SCRIPT ERROR: (Parse|Compile) Error" "$log"; then exit 1; fi
exit 0
