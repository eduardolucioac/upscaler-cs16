#!/bin/bash
#
# test/sources.bash - the source files themselves
#
# Part of the "ez_i" test suite. Sourced by "test/test.bash", never on its
# own: it relies on the harness.
#
# These check the things that are easy to get wrong while editing and that no
# functional test would notice: a stray quote in a docstring, a name that
# escapes the library, a deprecated construct.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

t_group "source files"

declare -a T_SOURCES=("$TESTS_ROOT/ez_i.bash")
for T_PART in "$TESTS_ROOT/ez_i/"*.bash ; do
    T_SOURCES+=("$T_PART")
done

t_equals "every part is there" "11" "${#T_SOURCES[@]}"

for T_SOURCE in "${T_SOURCES[@]}" ; do
    t_equals "$(basename "$T_SOURCE") parses with no warning" \
        "" "$(bash -n "$T_SOURCE" 2>&1)"
done

# NOTE: The file headers and the docstrings are ": '...'" blocks, so an
# apostrophe anywhere inside one closes the string early and the rest of the
# paragraph gets RUN. Sourcing has to stay completely silent.
t_equals "sourcing the library prints nothing at all" "" \
    "$(bash -c "EZ_I_SKIP_ON=1 ; source \"$TESTS_ROOT/ez_i.bash\"" 2>&1)"

# NOTE: "$[...]" was removed from BASH in favour of "$((...))".
t_equals "no deprecated \$[...] arithmetic" "0" \
    "$(cat "${T_SOURCES[@]}" | grep -cE '\$\[[A-Za-z0-9_$ +*/-]+\]')"

t_equals "every function carries a docstring" "" \
    "$(cat "${T_SOURCES[@]}" | awk '
        /^(function[ \t]+)?[a-zA-Z_][a-zA-Z0-9_.]*[ \t]*\(\)[ \t]*\{/ {
            name = $0
            sub(/[ \t]*\(\).*/, "", name)
            sub(/^function[ \t]+/, "", name)
            getline next_line
            if (next_line !~ /^[ \t]*: '"'"'/) print name
        }')"

# NOTE: "declare -A" cannot convert a name that is already an indexed
# array, so two parts reusing one name with different types makes the second
# silently read index 0 for every key. Each part keeps its own names.
t_equals "no test variable is declared with two different types" "" \
    "$(grep -hoE '^declare -[aA] (T_[A-Za-z_]+)' "$TESTS_DIRECTORY"/*.bash \
        | sort -u | awk '{print $3}' | sort | uniq -d)"

t_group "names"

# Everything this library defines is "ez_i.<something>", "ez_i._<something>"
# or "_EZ_I_<SOMETHING>". The one exception is EZ_I_SKIP_ON, which a script
# sets, so it cannot be library private.
#
# The list below is deliberately exact. A name added to it is a name this
# library puts into somebody else's scope, and that is a decision worth
# having to make on purpose rather than by quietly widening a test.
t_equals "no function escapes the \"ez_i.\" namespace" "" \
    "$(bash -c "
        EZ_I_SKIP_ON=1
        BEFORE=\$(declare -F | awk '{print \$3}' | sort)
        source \"$TESTS_ROOT/ez_i.bash\"
        declare -F | awk '{print \$3}' | sort | comm -13 <(echo \"\$BEFORE\") - \
            | grep -v '^ez_i\.'
    " 2>&1)"

t_equals "no variable escapes, bar the documented one" "" \
    "$(bash -c "
        EZ_I_SKIP_ON=1
        BEFORE=\$(compgen -v | sort)
        source \"$TESTS_ROOT/ez_i.bash\"
        compgen -v | sort | comm -13 <(echo \"\$BEFORE\") - \
            | grep -vE '^_EZ_I_|^EZ_I_SKIP_ON\$|^BEFORE\$'
    " 2>&1)"

# A function that takes a target must not be defeated by a caller variable
# that happens to share a name with one of its own locals. Every local of
# such a function carries a suffix for exactly this reason.
#
# BASH scoping is DYNAMIC: a "local" of the caller is visible all the way
# down the call stack, which is what lets a nameref write back to it at all.
# The same rule is what makes shadowing possible, because a local of the
# CALLED function sits nearer on that chain and wins.
t_group "caller variables are never shadowed (global)"

for T_NAME in value text result mode path file target out source answer \
              folder entry needle prompt question ; do
    unset "$T_NAME"
    declare "$T_NAME=UNTOUCHED"
    ez_i.trim "$T_NAME" "  ok  " 2
    t_equals "a global named \"$T_NAME\" is written" "ok" "${!T_NAME}"
done

# NOTE: The case above is a GLOBAL. The one below is a "local" of a calling
# function, which is how a target variable is almost always declared in real
# code and is the case that actually exercises the scope chain.
t_group "caller variables are never shadowed (local of a function)"

function t_local_target() {
    local test_name="$1"
    local target_name="$2"
    local -n t_local_rtn_1b4c="$target_name"
    t_local_rtn_1b4c="UNTOUCHED"
    ez_i.trim "$target_name" "  ok  " 2
    t_equals "$test_name" "ok" "$t_local_rtn_1b4c"
}

# Declared "local" in the function that calls the library, under each of the
# names a caller is most likely to reach for.
function t_shadow_value()   { local value;   t_local_target "a local named \"value\""   value; }
function t_shadow_text()    { local text;    t_local_target "a local named \"text\""    text; }
function t_shadow_result()  { local result;  t_local_target "a local named \"result\""  result; }
function t_shadow_mode()    { local mode;    t_local_target "a local named \"mode\""    mode; }
function t_shadow_target()  { local target;  t_local_target "a local named \"target\""  target; }
function t_shadow_my_var()  { local my_var;  t_local_target "a local named \"my_var\""  my_var; }
t_shadow_value ; t_shadow_text ; t_shadow_result
t_shadow_mode ; t_shadow_target ; t_shadow_my_var

# The same, for each shape a target can take, written the way a real script
# would write it.
function t_local_scalar() {
    local my_var
    ez_i.trim my_var "  ok  " 2
    t_equals "a scalar local is written" "ok" "$my_var"
}
function t_local_array() {
    local -a my_parts=()
    ez_i.split my_parts "a,b,c" ","
    t_equals "an indexed array local is filled" "3" "${#my_parts[@]}"
    t_equals "an indexed array local holds the right item" "b" "${my_parts[1]}"
}
function t_local_assoc() {
    local -A my_result=()
    ez_i.run my_result "echo hello"
    t_equals "an associative array local is filled" "hello" "${my_result[stdout]}"
}
function t_local_predicate() {
    local my_answer
    ez_i.exists my_answer "f" "$TESTS_TMP/a_file"
    t_equals "a predicate writes to a local" "1" "$my_answer"
}
function t_local_nested_inner() { ez_i.trim "$1" "  deep  " 2; }
function t_local_nested() {
    local my_var
    t_local_nested_inner my_var
    t_equals "a local two levels up is still written" "deep" "$my_var"
}
t_local_scalar ; t_local_array ; t_local_assoc
t_local_predicate ; t_local_nested

# And the result must NOT escape: a local stays local.
function t_local_stays_local() { local escaping_var ; ez_i.trim escaping_var "  x  " 2 ; }
t_local_stays_local
t_equals "a local target does not leak to the global scope" \
    "" "${escaping_var+leaked}"
