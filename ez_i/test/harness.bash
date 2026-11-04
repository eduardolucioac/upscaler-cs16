#!/bin/bash
#
# test/harness.bash - the counters and the assertions every part uses.
#
# Part of the "ez_i" test suite. Sourced by "test/test.bash" FIRST, because
# every other part relies on what this defines.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
declare -a TESTS_FAILED_NAMES=()

# A scratch folder for the parts that need real files. Removed on the way out
# by "test/test.bash".
TESTS_TMP="$(mktemp -d "${TMPDIR:-/tmp}/ez_i-test.XXXXXX")"

# Reports the outcome of one test.
#
#     $1 .. 0 for pass, anything else for fail
#     $2 .. test name
#     $3 .. optional detail printed on failure
function t_report() {
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    if (($1 == 0)) ; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        printf ' [ PASS ] %s\n' "$2"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_FAILED_NAMES+=("$2")
        printf ' [ FAIL ] %s\n' "$2"
        if [ -n "$3" ] ; then
            printf '          %s\n' "$3"
        fi
    fi
}

# Prints the name of a group of tests.
function t_group() {
    echo ""
    echo " --- $1 ---"
}

# Asserts that two strings are equal.
function t_equals() {
    local test_name="$1"
    local expected="$2"
    local obtained="$3"
    if [[ "$expected" == "$obtained" ]] ; then
        t_report 0 "$test_name"
    else
        t_report 1 "$test_name" "expected [$expected] but got [$obtained]"
    fi
}

# Asserts that a command succeeds.
function t_succeeds() {
    local test_name="$1"
    shift
    if "$@" > /dev/null 2>&1 ; then
        t_report 0 "$test_name"
    else
        t_report 1 "$test_name" "expected exit 0, got $?"
    fi
}

# Asserts that a command fails.
function t_fails() {
    local test_name="$1"
    shift
    if "$@" > /dev/null 2>&1 ; then
        t_report 1 "$test_name" "expected a non zero exit, got 0"
    else
        t_report 0 "$test_name"
    fi
}

# Runs a command IN THE CURRENT SHELL, capturing its streams to files.
#
# NOTE: Command substitution would be shorter, but it runs the command in a
# subshell, so every mutation it performs would be rolled back the moment it
# returned. That silently turns "delete then check it is gone" into a test of
# nothing at all.
#
# Fills in "T_RUN_STDOUT", "T_RUN_STDERR" and "T_RUN_RTN_CODE".
T_RUN_STDOUT=""
T_RUN_STDERR=""
T_RUN_RTN_CODE=0
function t_run() {
    local stdout_file
    local stderr_file
    stdout_file=$(mktemp "$TESTS_TMP/out.XXXXXX")
    stderr_file=$(mktemp "$TESTS_TMP/err.XXXXXX")

    "$@" > "$stdout_file" 2> "$stderr_file"
    T_RUN_RTN_CODE="$?"

    T_RUN_STDOUT=$(< "$stdout_file")
    T_RUN_STDERR=$(< "$stderr_file")
    rm -f "$stdout_file" "$stderr_file"
}
