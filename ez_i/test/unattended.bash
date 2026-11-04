#!/bin/bash
#
# test/unattended.bash - what happens with EZ_I_SKIP_ON set
#
# Part of the "ez_i" test suite. Sourced by "test/test.bash", never on its
# own: it relies on the harness.
#
# A script running unattended must get PAST every prompt rather than hang on
# one, and must not be taken to have agreed to anything. These run each
# asking function in a subshell with a closed stdin, so a function that
# forgot to honour the flag shows up as a failure and not as a suite that
# never finishes.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

t_group "unattended (EZ_I_SKIP_ON=1)"

# Runs a snippet with the library loaded, the flag set and NO stdin, giving
# up after a few seconds. A prompt that is still waiting cannot pass.
function t_unattended() {
    local test_name="$1"
    local snippet="$2"
    local expected="$3"
    local obtained=""
    obtained=$(timeout 5 bash -c "
        EZ_I_SKIP_ON=1
        source \"$TESTS_ROOT/ez_i.bash\" || exit 1
        $snippet
    " < /dev/null 2>&1)
    local status=$?
    if ((status == 124)) ; then
        t_report 1 "$test_name" "it blocked waiting for input"
        return
    fi
    t_equals "$test_name" "$expected" "$obtained"
}

t_unattended "ez_i.read returns without asking" \
    'declare A="DEFAULT" ; ez_i.read A "Name? " ; echo "$A"' \
    "DEFAULT"

t_unattended "ez_i.ask returns without asking" \
    'declare A="DEFAULT" ; ez_i.ask A "Name?" ; echo "$A"' \
    "DEFAULT"

t_unattended "ez_i.ask_option returns without asking" \
    'declare -a O=("y" "Yes" "n" "No") ; declare A="DEFAULT"
     ez_i.ask_option A "" "Pick?" O ; echo "$A"' \
    "DEFAULT"

# A timeout running out and EZ_I_SKIP_ON being set are the same situation -
# nobody answered - so they take the same answer, $4. It has no default: what
# an unanswered question should do belongs to the QUESTION ("update your
# distro?" wants yes, "disable SELinux?" wants no), and any constant the
# library picked would be silently wrong for one of them.
t_unattended "ez_i.ask_yes_no takes yes from \$4, through a variable" \
    'declare A=9 ; ez_i.ask_yes_no A "Update the distro?" "" 1 ; echo "$A"' \
    "1"

t_unattended "ez_i.ask_yes_no takes yes from \$4, through the exit status" \
    'if ez_i.ask_yes_no "" "Update the distro?" "" 1 ; then echo "YES" ; else echo "NO" ; fi' \
    "YES"

t_unattended "ez_i.ask_yes_no takes no from \$4" \
    'declare A=9 ; ez_i.ask_yes_no A "Disable SELinux?" "" 0 ; echo "$A"' \
    "0"

# Left out, it is NOT guessed at. A question nobody can answer and that did
# not say what to do is a mistake in the calling script, and is reported as
# one - the target is left alone rather than filled with an invention.
t_unattended "a question with no answer to fall back on is refused" \
    'declare A=9 ; ez_i.ask_yes_no A "Delete everything?" ; echo "A=$A"' \
    'ERROR! "ez_i.ask_yes_no" has nobody to answer it (EZ_I_SKIP_ON) and was given no answer to use.
A=9'

t_unattended "and through the exit status it is a failure, not a no" \
    'if ez_i.ask_yes_no "" "Delete everything?" 2> /dev/null ; then echo "YES" ; else echo "exit=$?" ; fi' \
    "exit=1"

t_unattended "an answer that is neither 1 nor 0 is refused" \
    'declare A=9 ; ez_i.ask_yes_no A "Carry on?" "" 7 ; echo "A=$A"' \
    'ERROR! The answer "ez_i.ask_yes_no" is to use when nobody answers must be 1 or 0.
A=9'

# The timeout half is checked with EZ_I_SKIP_ON OFF, because that is the
# point of checking it there: a question that COULD go unanswered is caught
# on the first ordinary run, not on the first unattended one.
T_OUT="$(timeout 5 bash -c "
    source \"$TESTS_ROOT/ez_i.bash\" || exit 1
    declare A=9
    ez_i.ask_yes_no A 'Carry on?' 30
    echo \"A=\$A\"
" < /dev/null 2>&1)"
t_equals "a timeout with no answer to fall back on is refused" \
    'ERROR! "ez_i.ask_yes_no" was given a timeout but no answer to use when it runs out.
A=9' "$T_OUT"

# Same rule for "ez_i.read", and for the same reason: a timeout running out
# has to leave something in the target. An empty answer is not one - it
# cannot be told apart from a bare enter, and it reads as ("" in N seconds)
# in the prompt, which tells nobody anything.
T_OUT="$(timeout 5 bash -c "
    source \"$TESTS_ROOT/ez_i.bash\" || exit 1
    declare A=PRE
    ez_i.read A 'Name? ' 0 30
    echo \"A=\$A\"
" < /dev/null 2>&1)"
t_equals "ez_i.read refuses a timeout with no answer to fall back on" \
    'ERROR! "ez_i.read" was given a timeout but no answer to use when it runs out.
A=PRE' "$T_OUT"

# And with one, the timeout running out is what the prompt said it would be.
T_OUT="$(timeout 5 bash -c "
    source \"$TESTS_ROOT/ez_i.bash\" || exit 1
    declare A=PRE
    ez_i.read A 'Name? ' 0 1 'FALLBACK' > /dev/null
    echo \"A=\$A\"
" < /dev/null 2>&1)"
t_equals "ez_i.read falls back to the announced answer" "A=FALLBACK" "$T_OUT"

t_unattended "ez_i.enter_to_continue returns without waiting" \
    'ez_i.enter_to_continue "Something happened." ; echo "PAST IT"' \
    "PAST IT"

t_unattended "ez_i.ask_continue carries on rather than exiting" \
    'ez_i.ask_continue ; echo "PAST IT"' \
    "PAST IT"

t_unattended "ez_i.terms carries on rather than exiting" \
    'ez_i.terms "Some licence." ; echo "PAST IT"' \
    "PAST IT"

t_unattended "ez_i.start draws nothing" \
    'ez_i.start "" "T" "1.0" "A" "W" "C" ; echo "PAST IT"' \
    "PAST IT"

t_unattended "ez_i.end draws nothing" \
    'ez_i.end "T" "I" ; echo "PAST IT"' \
    "PAST IT"

t_unattended "ez_i.instructions draws nothing" \
    'ez_i.instructions "" "Do this." ; echo "PAST IT"' \
    "PAST IT"

t_unattended "ez_i.progress animates nothing" \
    'ez_i.progress "a" "Working..." ; ez_i.progress "o" ; echo "PAST IT"' \
    "PAST IT"

# NOTE: A warning is shown even unattended, because the point of a warning is
# to be seen. What it does not do is WAIT.
t_unattended "a warning is still shown, and does not wait" \
    'ez_i.warning "LOOK OUT!" ; echo "PAST IT"' \
    "
> ------------------------------------------------
W A R N I N G !
----------------------------------

LOOK OUT!

< ------------------------------------------------

PAST IT"

# The functions that compute something still do, flag or no flag.
t_unattended "the computing functions still work" \
    'declare A ; ez_i.trim A "  x  " 2 ; echo "$A"' \
    "x"
