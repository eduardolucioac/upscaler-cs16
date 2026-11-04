#!/bin/bash
#
# test/shadowing.bash - that a target is written whatever it is called
#
# Part of the "json-like" test suite. Sourced by "test/test.bash", never on
# its own: it relies on the harness.
#
# A nameref resolves against the scope chain at the moment it is written, so
# a local of the library would shadow a caller variable of the same name and
# swallow the result. "json_like._unshadow" takes that local off the chain,
# using the list "json_like._scan_locals" built at source time.
#
# These tests are GENERATED from that very list, so every local name of
# every public function is tried as a target. Adding a local to the library
# adds a test here by itself.
#
# json-like - Nested data structures for BASH "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

t_equals "the scan ran" "1" \
    "$([ "${#_JSON_LIKE_LOCALS[@]}" -gt 0 ] && echo 1 || echo 0)"

# A nameref is left out on purpose: "unset" on one destroys the variable it
# POINTS AT rather than the binding, so unsetting an internal nameref would
# take the object data with it.
t_equals "no nameref is recorded" "" \
    "$(echo "${_JSON_LIKE_LOCALS[@]}" | tr ' ' '\n' \
        | grep -E '_ref$|_ref_[0-9a-f]+$' | sort -u | tr '\n' ' ')"

declare SHADOW_OBJ
json_like.set_obj SHADOW_OBJ
json_like.set "$SHADOW_OBJ" "s.VALUE" "o.window" "o.title"
json_like.set "$SHADOW_OBJ" "s.kde"   "o.window" "o.tags" "i.+"
declare SHADOW_JSON
json_like.to_json SHADOW_JSON "$SHADOW_OBJ"

for SHADOW_NAME in ${_JSON_LIKE_LOCALS[json_like.set_obj]} ; do
    unset "$SHADOW_NAME" ; declare "$SHADOW_NAME="
    json_like.set_obj "$SHADOW_NAME"
    if [ -n "${!SHADOW_NAME}" ] ; then
        t_report 0 "set_obj into \"$SHADOW_NAME\""
        json_like.unset_obj "$SHADOW_NAME"
    else
        t_report 1 "set_obj into \"$SHADOW_NAME\""
    fi
done

for SHADOW_NAME in ${_JSON_LIKE_LOCALS[json_like.get]} ; do
    unset "$SHADOW_NAME" ; declare "$SHADOW_NAME="
    json_like.get "$SHADOW_NAME" "$SHADOW_OBJ" "window" "title"
    t_equals "get into \"$SHADOW_NAME\"" "VALUE" "${!SHADOW_NAME}"
done

# The same function, asked for a whole subtree. How the target was declared
# is what decides, and that has to be read before any local of the library
# exists to be mistaken for it.
for SHADOW_NAME in ${_JSON_LIKE_LOCALS[json_like.get]} ; do
    unset "$SHADOW_NAME" ; declare -A "$SHADOW_NAME=()"
    json_like.get "$SHADOW_NAME" "$SHADOW_OBJ" "window"
    declare -n SHADOW_REF="$SHADOW_NAME"
    if [ "${#SHADOW_REF[@]}" -gt 0 ] ; then
        t_report 0 "get a subtree into \"$SHADOW_NAME\""
    else
        t_report 1 "get a subtree into \"$SHADOW_NAME\"" "came back empty"
    fi
    unset -n SHADOW_REF
done

for SHADOW_NAME in ${_JSON_LIKE_LOCALS[json_like.get_length]} ; do
    unset "$SHADOW_NAME" ; declare "$SHADOW_NAME="
    json_like.get_length "$SHADOW_NAME" "$SHADOW_OBJ" "window" "tags"
    t_equals "get_length into \"$SHADOW_NAME\"" "1" "${!SHADOW_NAME}"
done

for SHADOW_NAME in ${_JSON_LIKE_LOCALS[json_like.to_json]} ; do
    unset "$SHADOW_NAME" ; declare "$SHADOW_NAME="
    json_like.to_json "$SHADOW_NAME" "$SHADOW_OBJ"
    case "${!SHADOW_NAME}" in
        *'"window"'*) t_report 0 "to_json into \"$SHADOW_NAME\"" ;;
        *) t_report 1 "to_json into \"$SHADOW_NAME\"" "got [${!SHADOW_NAME}]" ;;
    esac
done

for SHADOW_NAME in ${_JSON_LIKE_LOCALS[json_like.from_json]} ; do
    unset "$SHADOW_NAME" ; declare "$SHADOW_NAME="
    json_like.from_json "$SHADOW_NAME" "$SHADOW_JSON"
    if [ -n "${!SHADOW_NAME}" ] ; then
        t_report 0 "from_json into \"$SHADOW_NAME\""
        json_like.unset_obj "$SHADOW_NAME"
    else
        t_report 1 "from_json into \"$SHADOW_NAME\""
    fi
done

# The case the whole mechanism exists for: a target declared "local" in the
# function that calls the library.
function t_shadow_caller_local() {
    local json_like_obj=""
    json_like.get json_like_obj "$SHADOW_OBJ" "window" "title"
    t_equals "a caller local named after a library local is written" \
        "VALUE" "$json_like_obj"
}
function t_shadow_caller_subtree() {
    local -A path=()
    json_like.get path "$SHADOW_OBJ" "window"
    t_equals "a caller local subtree is filled" "1" \
        "$([ "${#path[@]}" -gt 0 ] && echo 1 || echo 0)"
}
t_shadow_caller_local
t_shadow_caller_subtree

json_like.unset_obj SHADOW_OBJ
