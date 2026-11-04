#!/bin/bash
#
# json-like/bootstrap.bash - where the library finds itself, and what it loads.
#
# Part of "json-like". Sourced by "json-like.bash" FIRST, because everything
# after it relies on what this defines.
#
# json-like - Nested data structures for BASH "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# Where the library lives, so that the AWK programs are found no matter what
# the current working directory is.
#
# This part is sourced from one directory down, so the root cannot be taken
# from "${BASH_SOURCE[0]}" here: it comes from the entry point, which is the
# file that knows where the project starts.
#
# NOTE: A library private name is used on purpose. A generic one such as
# "SCRIPT_DIRECTORY" would collide with the variable of the script that sources
# this file.
declare _JSON_LIKE_DIR
_JSON_LIKE_DIR="$_JSON_LIKE_ROOT"
if [ -z "$_JSON_LIKE_DIR" ] ; then
    echo "ERROR! Unable to resolve the \"json-like.bash\" directory." >&2
    return 1 2>/dev/null || exit 1
fi

if ! command -v awk > /dev/null 2>&1 ; then
    echo "ERROR! \"json-like.bash\" requires \"awk\"." >&2
    return 1 2>/dev/null || exit 1
fi

# The AWK back end, read once at source time and kept in memory. Passing the
# program as a string avoids both a file read and a process spawn per call.
declare _JSON_LIKE_AWK
if [[ ! -r "$_JSON_LIKE_DIR/awk/json-like-core.awk" ]] ; then
    echo "ERROR! Unable to read \"$_JSON_LIKE_DIR/awk/json-like-core.awk\"." >&2
    return 1 2>/dev/null || exit 1
fi
_JSON_LIKE_AWK=$(< "$_JSON_LIKE_DIR/awk/json-like-core.awk")

declare _JSON_LIKE_CODEC_AWK
if [[ ! -r "$_JSON_LIKE_DIR/awk/json-like-to_json.awk" ]] ; then
    echo "ERROR! Unable to read \"$_JSON_LIKE_DIR/awk/json-like-to_json.awk\"." >&2
    return 1 2> /dev/null || exit 1
fi
_JSON_LIKE_CODEC_AWK=$(< "$_JSON_LIKE_DIR/awk/json-like-to_json.awk")

declare _JSON_LIKE_FROM_JSON_AWK
if [[ ! -r "$_JSON_LIKE_DIR/awk/json-like-from_json.awk" ]] ; then
    echo "ERROR! Unable to read \"$_JSON_LIKE_DIR/awk/json-like-from_json.awk\"." >&2
    return 1 2> /dev/null || exit 1
fi
_JSON_LIKE_FROM_JSON_AWK=$(< "$_JSON_LIKE_DIR/awk/json-like-from_json.awk")

# Whether "${!name@a}" is available (BASH 5.1 and up).
#
# "json_like.get" has to know whether the variable it was handed is an
# associative array. The portable way of asking is to capture "declare -p",
# which costs a FORK on every single read; "${!name@a}" answers the same
# question for free. The fallback below keeps BASH 4.3 working.
declare -i _JSON_LIKE_HAS_ATTR_EXPANSION=0
if ((BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1))); then
    _JSON_LIKE_HAS_ATTR_EXPANSION=1
fi

# HANDING A VALUE BACK >>>>>>

# A function returns a value by writing through a nameref to a variable the
# caller named. BASH scoping is DYNAMIC, so that reaches a "local" of the
# caller at any depth, which is what makes the idiom work at all.
#
# It also cuts the other way. A nameref resolves against the scope chain AT
# THE MOMENT IT IS WRITTEN, and a local of the function doing the writing
# sits NEARER on that chain than the caller variable. A function with a
# plain "local uuid" therefore swallows the result of "json_like.set_obj
# uuid" in silence: the write lands in its own local, which vanishes when it
# returns.
#
# A function CAN unset a local of the function that called IT, which takes
# that local off the chain. So the offending local is removed just before
# the nameref is bound, and only when the target really is one of that
# function locals - unsetting anything else would destroy the caller
# variable outright, attributes and all.
#
# Each function locals are read ONCE, at source time, out of what "declare
# -f" prints. Nothing is computed per call, and a local declared inside an
# "if" is seen just the same, because what is read is the body and not the
# running scope.

# Function name -> the names of its locals, each surrounded by spaces so a
# whole word match is a plain "case" pattern.
declare -A _JSON_LIKE_LOCALS=()

function json_like._scan_locals() {
    : 'Record the names of the locals of every "json_like." function.

    RETURNS
        0 on success, 1 when nothing could be read, which would leave every
        function unprotected.

    SIDE EFFECTS
        Fills "_JSON_LIKE_LOCALS".

    Called once by "json-like.bash", after every part has been sourced.
    '

    local function_name=""
    local local_name=""
    local pairs=0

    while IFS=$'\t' read -r function_name local_name ; do
        _JSON_LIKE_LOCALS["$function_name"]+="$local_name "
        pairs=$((pairs + 1))
    done < <(
        # shellcheck disable=SC2046
        declare -f $(compgen -A function "json_like.") 2> /dev/null | awk '
            # Only names are wanted, never values, so the value of an
            # assignment is skipped whole - honouring quotes and
            # parentheses, because "local -A m=([k]=\"v 1\")" must yield "m"
            # and not "k".
            function skip_value(s,   c, q, depth) {
                q = ""; depth = 0
                while (length(s) > 0) {
                    c = substr(s, 1, 1)
                    if (q != "") {
                        if (c == "\\") { s = substr(s, 3); continue }
                        if (c == q) q = ""
                    } else if (c == "\"" || c == "\047") {
                        q = c
                    } else if (c == "(") {
                        depth++
                    } else if (c == ")") {
                        depth--
                        if (depth == 0) { s = substr(s, 2); break }
                    } else if (depth == 0 && (c == " " || c == "\t" || c == ";")) {
                        break
                    }
                    s = substr(s, 2)
                }
                return s
            }
            /^[A-Za-z_][A-Za-z0-9_.]*[ \t]*\(\)[ \t]*$/ { fn = $1; next }
            /^\}/ { fn = "" }
            fn != "" && /^[ \t]*local[ \t]/ {
                line = $0
                sub(/^[ \t]*local[ \t]+/, "", line)

                # A nameref is NEVER recorded. "unset" on one destroys the
                # variable it POINTS AT, not the binding, so unsetting an
                # internal nameref would take the library own state with
                # it. Leaving it out means a target named after one simply
                # comes back unwritten, which is a harmless failure.
                if (match(line, /^-[A-Za-z]*n[A-Za-z]*[ \t]+/)) next

                while (match(line, /^-[A-Za-z]+[ \t]+/)) line = substr(line, RLENGTH + 1)
                while (length(line) > 0) {
                    sub(/^[ \t]+/, "", line)
                    if (!match(line, /^[A-Za-z_][A-Za-z0-9_]*/)) break
                    name = substr(line, 1, RLENGTH)
                    line = substr(line, RLENGTH + 1)
                    printf "%s\t%s\n", fn, name
                    if (substr(line, 1, 1) == "=") line = skip_value(substr(line, 2))
                    else if (substr(line, 1, 1) == ";") break
                }
            }'
    )

    if ((pairs == 0)) ; then
        echo "ERROR! \"json-like.bash\" could not read its own function bodies." >&2
        return 1
    fi

    for function_name in "${!_JSON_LIKE_LOCALS[@]}" ; do
        _JSON_LIKE_LOCALS["$function_name"]=" ${_JSON_LIKE_LOCALS[$function_name]}"
    done
}

function json_like._unshadow() {
    : 'Take the target off the scope chain when it is a local of the caller.

    ARGUMENTS
        $1 - string, required. The target variable name.
        $2 - string, required. The name of the function that is returning
             the value, which is "${FUNCNAME[0]}" where this is called.

    RETURNS
        0 always.

    SIDE EFFECTS
        May unset one local of a function further up the stack.

    IMPORTANT: Only a name that really is one of that function locals is
    unset. Anything else would be the caller own variable.

    IMPORTANT: This is for namerefs bound to a CALLER SUPPLIED name. The
    ones bound to "JL_DATA_$id" and its like address the library own state
    and must never go through here.
    '

    case "${_JSON_LIKE_LOCALS[$2]}" in
        *" $1 "*) unset "$1" ;;
    esac
    return 0
}

function json_like._emit() {
    : 'Hand a value back to the caller.

    ARGUMENTS
        $1 - string, required. The target variable NAME.
        $2 - string, required. The value.

    RETURNS
        0 on success, 1 when the target is empty.

    IMPORTANT: The value arrives as an ARGUMENT, so it is already safe when
    the shadowing local is unset. Writing through a nameref after unsetting
    a local the value was still being read from would lose it.
    '

    if [ -z "$1" ] ; then
        echo "ERROR! A target variable name is required." >&2
        return 1
    fi
    json_like._unshadow "$1" "${FUNCNAME[1]}"
    local -n json_like_emit_rtn_6a2d="$1"
    json_like_emit_rtn_6a2d="$2"
}

function json_like._emit_assoc() {
    : 'Hand an ASSOCIATIVE array back to the caller.

    ARGUMENTS
        $1 - string, required. The target variable NAME.
        $2 - string, required. The NAME of the associative array holding the
             result, normally a local of whoever calls this.

    RETURNS
        0 on success, 1 when either name is empty.

    IMPORTANT: The contents are COPIED before anything is unset, so a target
    named after the source still arrives.
    '

    if [ -z "$1" ] || [ -z "$2" ] ; then
        echo "ERROR! A target and a source array name are required." >&2
        return 1
    fi
    local -n json_like_src_ref_6a2d="$2"
    local -A json_like_copy_6a2d=()
    local json_like_key_6a2d=""
    for json_like_key_6a2d in "${!json_like_src_ref_6a2d[@]}" ; do
        json_like_copy_6a2d["$json_like_key_6a2d"]="${json_like_src_ref_6a2d[$json_like_key_6a2d]}"
    done
    unset -n json_like_src_ref_6a2d

    json_like._unshadow "$1" "${FUNCNAME[1]}"
    local -n json_like_dst_ref_6a2d="$1"
    json_like_dst_ref_6a2d=()
    for json_like_key_6a2d in "${!json_like_copy_6a2d[@]}" ; do
        json_like_dst_ref_6a2d["$json_like_key_6a2d"]="${json_like_copy_6a2d[$json_like_key_6a2d]}"
    done
}

function json_like._target_kind() {
    : 'Say how the caller declared the variable it named.

    ARGUMENTS
        $1 - string, required. The target variable name.

    RETURNS
        2 when it is an associative array, 1 when it is an indexed one,
        0 otherwise.

    IMPORTANT: Call this as the FIRST statement of a function, before it
    declares any local of its own. What it reports decides the SHAPE of the
    result, and a local named like the target would be what gets inspected
    instead - a caller asking for a subtree would silently be answered with
    a single value.
    '

    local target_attrs_9e4c=""
    if ((_JSON_LIKE_HAS_ATTR_EXPANSION == 1)) ; then
        target_attrs_9e4c="${!1@a}"
    else
        # BASH 4.3/4.4/5.0: no attribute expansion, so pay for the fork.
        target_attrs_9e4c="$(declare -p "$1" 2>/dev/null)"
        target_attrs_9e4c="${target_attrs_9e4c#declare -}"
        target_attrs_9e4c="${target_attrs_9e4c%% *}"
    fi
    case "$target_attrs_9e4c" in
        *A*) return 2 ;;
        *a*) return 1 ;;
    esac
    return 0
}

# <<<<<< HANDING A VALUE BACK
