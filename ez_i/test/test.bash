#!/bin/bash
#
# test/test.bash - Test suite for the "ez_i" BASH library.
#
# Run it directly:
#
#     ./test/test.bash
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
# WHAT IS NOT COVERED, AND WHY
#
#     ez_i.ask, ez_i.read, ez_i.ask_option, ez_i.ask_yes_no,
#     ez_i.enter_to_continue, ez_i.ask_continue, ez_i.terms
#         .. wait on a real person. Their EZ_I_SKIP_ON path is checked.
#     ez_i.start, ez_i.end, ez_i.instructions, ez_i.warning
#         .. clear the terminal and page, which a suite has no terminal for.
#     ez_i.package_installed, ez_i.check_distro_status
#         .. need a specific distribution and its package manager.
#     ez_i.iptables_rule
#         .. needs root.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

TESTS_DIRECTORY="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
TESTS_ROOT="$( cd -- "$TESTS_DIRECTORY/.." && pwd )"

# NOTE: Sourced with the flag OFF, because the drawing functions are part of
# what is being tested. The parts that would wait on a person are not called.
EZ_I_SKIP_ON=0

# shellcheck source=../ez_i.bash
source "$TESTS_ROOT/ez_i.bash" || exit 1

# shellcheck source=harness.bash
source "$TESTS_DIRECTORY/harness.bash" || exit 1

# NOTE: The library installs an EXIT trap of its own, and "ez_i.trap_add" is
# what keeps this one from replacing it.
ez_i.trap_add "rm -rf \"$TESTS_TMP\"" EXIT

# shellcheck source=strings.bash
source "$TESTS_DIRECTORY/strings.bash" || exit 1

# shellcheck source=numbers.bash
source "$TESTS_DIRECTORY/numbers.bash" || exit 1

# shellcheck source=files.bash
source "$TESTS_DIRECTORY/files.bash" || exit 1

# shellcheck source=system.bash
source "$TESTS_DIRECTORY/system.bash" || exit 1

# shellcheck source=terminal.bash
source "$TESTS_DIRECTORY/terminal.bash" || exit 1

# shellcheck source=unattended.bash
source "$TESTS_DIRECTORY/unattended.bash" || exit 1

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
echo

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

((TESTS_FAILED == 0 && POSIX_AWK_FAILED == 0)) && exit 0
exit 1
