#!/bin/bash
#
# test/test.bash - Test suite for the "json-like" BASH library.
#
# Run it directly:
#
#     ./test/test.bash           # integrity tests
#     ./test/test.bash --perf    # integrity tests + performance tests
#
# Exits 0 when every test passed, 1 otherwise, so it can be wired into a
# pre-commit hook or a CI job.
#
# The suite is split into parts under "test/". This file is the entry point
# and the only one to run; the parts use the counters and assertions the
# harness defines, so none of them stands on its own.
#
# The order is fixed and spelled out below rather than looped over: they are
# known, and a list in a variable would only hide which one failed.
#
# json-like - Nested data structures for BASH "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

TESTS_DIRECTORY="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
TESTS_ROOT="$( cd -- "$TESTS_DIRECTORY/.." && pwd )"

# shellcheck source=../json-like.bash
source "$TESTS_ROOT/json-like.bash" || exit 1

# shellcheck source=../util/try-catch.bash
source "$TESTS_ROOT/util/try-catch.bash" || exit 1

# The library does not install traps. Scripts that use "try-catch.bash" are the
# ones responsible for clearing the temporary files it may leave behind.
trap 'prog_concepts.cleanup' EXIT

RUN_PERFORMANCE_TESTS=0
if [[ "$1" == "--perf" ]] ; then
    RUN_PERFORMANCE_TESTS=1
fi

# shellcheck source=harness.bash
source "$TESTS_DIRECTORY/harness.bash" || exit 1

# shellcheck source=basics.bash
source "$TESTS_DIRECTORY/basics.bash" || exit 1

# shellcheck source=characters.bash
source "$TESTS_DIRECTORY/characters.bash" || exit 1

# shellcheck source=notation.bash
source "$TESTS_DIRECTORY/notation.bash" || exit 1

# shellcheck source=containers.bash
source "$TESTS_DIRECTORY/containers.bash" || exit 1

# shellcheck source=deleting.bash
source "$TESTS_DIRECTORY/deleting.bash" || exit 1

# shellcheck source=json_text.bash
source "$TESTS_DIRECTORY/json_text.bash" || exit 1

# shellcheck source=shadowing.bash
source "$TESTS_DIRECTORY/shadowing.bash" || exit 1

# shellcheck source=sources.bash
source "$TESTS_DIRECTORY/sources.bash" || exit 1

echo
echo "============================================================"
printf ' TOTAL %s | PASSED %s | FAILED %s\n' "$TESTS_TOTAL" "$TESTS_PASSED" "$TESTS_FAILED"
if ((TESTS_FAILED > 0)) ; then
    echo " FAILED TESTS:"
    for FAILED_NAME in "${TESTS_FAILED_NAMES[@]}" ; do
        printf '   . %s\n' "$FAILED_NAME"
    done
fi
echo "============================================================"

# > --------------------------------------------------------------------------
# The POSIX awk pass.
# --------------------------------------

# "awk" is a NAME shared by several different programs. It is gawk on Arch and
# Fedora, mawk on Debian and Ubuntu, busybox awk on Alpine, BWK awk on the
# BSDs. gawk accepts the POSIX language PLUS a large set of GNU extensions, so
# a suite that only ever runs under gawk cannot tell a portable program from
# one that quietly leans on GNU, and the difference only shows up on somebody
# else's machine.
#
# That is not hypothetical. "0xD800" is a GNU hexadecimal literal and POSIX awk
# reads it as 0. In "json-like" it turned every "\u" escape into rubbish while
# the suite went on reporting green, because the one test that could have
# caught it had been written with literal UTF-8 bytes instead of an escape.
#
# So the whole suite runs a SECOND time with an "awk" on PATH that is
# "gawk --posix", which refuses every extension. It needs nothing installed
# beyond the gawk that is already here, and it is skipped silently when gawk
# is absent - under mawk or busybox awk the first pass IS the strict one.
#
# Set SKIP_POSIX_AWK_PASS=1 to leave it out.

POSIX_AWK_FAILED=0
if [ -z "$IN_POSIX_AWK_PASS" ] && [ "$SKIP_POSIX_AWK_PASS" != "1" ] \
    && command -v gawk > /dev/null 2>&1 ; then

    POSIX_SHIM_DIRECTORY="$(mktemp -d "${TMPDIR:-/tmp}/posix-awk-shim.XXXXXX")"
    printf '#!/bin/sh\nexec %s --posix "$@"\n' "$(command -v gawk)" \
        > "$POSIX_SHIM_DIRECTORY/awk"
    chmod +x "$POSIX_SHIM_DIRECTORY/awk"

    # NOTE: A child process rather than this one, because PATH has to change
    # before the library is sourced and every "awk" it will ever call has to
    # go through the shim. Only the summary is shown: the detail of a pass
    # that agrees with the first one is noise.
    POSIX_AWK_OUTPUT="$(IN_POSIX_AWK_PASS=1 PATH="$POSIX_SHIM_DIRECTORY:$PATH" \
        bash "$TESTS_DIRECTORY/test.bash" 2>&1)"
    POSIX_AWK_FAILED=$?
    rm -rf "$POSIX_SHIM_DIRECTORY"

    echo
    echo "============================================================"
    echo ' POSIX AWK PASS ("gawk --posix" - every GNU extension refused)'
    echo "$POSIX_AWK_OUTPUT" | sed -n '/^ TOTAL /p ; /^ FAILED TESTS:/,/^=====/ { /^=====/d ; /^ TOTAL /d ; p }'
    echo "============================================================"
fi

# < --------------------------------------------------------------------------

if ((RUN_PERFORMANCE_TESTS == 0)) ; then
    echo
    echo ' Run with "--perf" to also time the operations.'
    echo
    ((TESTS_FAILED == 0 && POSIX_AWK_FAILED == 0)) && exit 0
    exit 1
fi

# shellcheck source=performance.bash
source "$TESTS_DIRECTORY/performance.bash" || exit 1

echo
((TESTS_FAILED == 0 && POSIX_AWK_FAILED == 0)) && exit 0
exit 1
