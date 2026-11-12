#!/bin/bash
#
# ez_i/bootstrap.bash - where the library finds itself, and how it hands
# values back without ever touching a variable of yours by accident.
#
# Part of "ez_i". Sourced by "ez_i.bash" FIRST, because everything after it
# relies on what this defines.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# LIBRARY STATE >>>>>>

# Where the library lives.
#
# This part is sourced from one directory down, so the root cannot be taken
# from "${BASH_SOURCE[0]}" here: it comes from the entry point, which is the
# file that knows where the project starts.
#
# NOTE: A library private name is used on purpose. A generic one such as
# "SCRIPT_DIRECTORY" would collide with the variable of the script that
# sources this file.
declare _EZ_I_DIR
_EZ_I_DIR="$_EZ_I_ROOT"
if [ -z "$_EZ_I_DIR" ] ; then
    echo "ERROR! Unable to resolve the \"ez_i.bash\" directory." >&2
    return 1 2> /dev/null || exit 1
fi

# Set this to 1 BEFORE sourcing the library and everything that would ask a
# question or draw on the terminal becomes a no op, so the same script runs
# unattended. The functions that compute something still do.
#
# NOTE: This is the ONE public name that is not a function. A script sets it,
# so it cannot be library private.
if [ -z "${EZ_I_SKIP_ON+x}" ] ; then
    declare -i EZ_I_SKIP_ON=0
fi

# The process id of the running "ez_i.progress" animation, 0 when there is
# none.
declare -i _EZ_I_ANIMATION_PID=0

# Whether the shell is attached to a terminal on both ends. Paging, prompting
# and animating all need one, and a script in a pipe, a cron job or a CI run
# has none.
declare -i _EZ_I_HAS_TERMINAL=0
if [ -t 0 ] && [ -t 1 ] ; then
    _EZ_I_HAS_TERMINAL=1
fi

# Whether there is a SCREEN to draw on, which is a weaker thing: only the
# output end has to be a terminal.
#
# The two are not the same and conflating them hides a real case. A script
# fed its answers from a file or a pipe has no terminal to READ from, so it
# must not try to ask anything - but its output is still a terminal someone
# is watching, and there is no reason to stop drawing progress on it.
declare -i _EZ_I_HAS_SCREEN=0
if [ -t 1 ] ; then
    _EZ_I_HAS_SCREEN=1
fi

# Function name -> the names of its locals, each surrounded by spaces so a
# whole word match is a plain "case" pattern. Filled once, at source time, by
# "ez_i._scan_locals". See HANDING A VALUE BACK.
declare -A _EZ_I_LOCALS=()

# <<<<<< LIBRARY STATE

# HANDING A VALUE BACK >>>>>>

# THE PROBLEM
#
# A function returns a value by writing through a nameref to a variable the
# caller named. BASH scoping is DYNAMIC, so that works at any depth: a
# "local" of the caller is reachable all the way down the call stack.
#
#     my_func() {
#         local my_var
#         ez_i.trim my_var "  padded  " 2      # my_var is written
#     }
#
# The same rule is what makes it fragile. A nameref resolves against the
# scope chain AT THE MOMENT IT IS WRITTEN, and a local of the function doing
# the writing sits NEARER on that chain than the caller's variable. A library
# function with a plain "local value" therefore swallows the result of
# "ez_i.trim value ..." in silence: the write lands in the library own local,
# which vanishes when it returns.
#
# Suffixing every local ("value_d412") hides the names at the cost of
# legibility on every line. Prefixing them ("_value") costs a rule the caller
# has to honour. Neither is needed.
#
# THE ANSWER
#
# A function CAN unset a local of the function that called IT, which takes
# that local off the scope chain and lets the nameref reach what the caller
# meant. Doing the same to its own local does NOT work: the name stays
# scoped, merely unset, and the write recreates it.
#
# So the write is delegated to "ez_i.emit_scalar" and its relatives, one frame
# down, and they unset the offending local before binding. They must unset
# ONLY when the target really is a local of their caller - unsetting anything
# else would destroy the caller variable outright, attributes and all, and an
# associative array would come back a plain indexed one. That is what
# "_EZ_I_LOCALS" is for.
#
# Each function locals are read ONCE, at source time, out of what "declare
# -f" prints. Nothing is computed per call, nothing has to be written inside
# the functions themselves, and a local declared inside an "if" is seen just
# the same, because what is read is the body and not the running scope.
#
# WHY EVERY FUNCTION IS SCANNED, NOT ONLY THE ONES THAT RETURN SOMETHING
#
# "ez_i._unshadow" only ever looks up the entry of the function that called
# an emitter, so the entries of the rest are never read. Recording only the
# emitters would therefore be correct - and is not worth doing.
#
#   . The failure mode is ASYMMETRIC. A spare entry is never consulted and
#     costs nothing. A MISSING one is a silent loss of protection, and that
#     is what a filter risks the day a fifth emitter is added, or a function
#     starts returning something, and the filter is not updated with it.
#   . It would be no faster. Deciding whether a function emits means reading
#     its whole body before printing anything, so the scan has to buffer;
#     measured, it came out slower.
#   . This table is also what GENERATES the shadowing tests. Dropping the
#     functions that only READ an array - "ez_i.array_to_file" and its like -
#     would drop their tests with them, and those have a hazard of their own.

function ez_i._scan_locals() {
    : 'Record the names of the locals of every "ez_i." function.

    RETURNS
        0 on success, 1 when nothing could be read, which would leave every
        function unprotected.

    SIDE EFFECTS
        Fills "_EZ_I_LOCALS".

    Called once by "ez_i.bash", after every part has been sourced. It reads
    what "declare -f" prints rather than the files on disk, so it sees the
    functions as BASH itself parsed them: one statement per line, values
    quoted, options normalised.
    '

    local function_name=""
    local local_name=""
    local pairs=0
    local wanted=""

    # NOTE: One named function, or every "ez_i." one when nothing is named.
    # The same awk serves both, which is why it is not written twice.
    # By Questor
    local wanted="$1"
    if [ -z "$wanted" ] ; then
        wanted=$(compgen -A function "ez_i.")
    fi

    while IFS=$'\t' read -r function_name local_name ; do
        _EZ_I_LOCALS["$function_name"]+="$local_name "
        pairs=$((pairs + 1))
    done < <(
        # shellcheck disable=SC2086
        declare -f $wanted 2> /dev/null | awk '
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
        echo "ERROR! \"ez_i.bash\" could not read its own function bodies." >&2
        return 1
    fi

    # NOTE: Surrounded by spaces so that a whole word match is a plain
    # "case" pattern, with no risk of "mode" matching inside "mode_two".
    for function_name in "${!_EZ_I_LOCALS[@]}" ; do
        _EZ_I_LOCALS["$function_name"]=" ${_EZ_I_LOCALS[$function_name]}"
    done
}

function ez_i._unshadow() {
    : 'Take the target off the scope chain when it is a local of the caller.

    ARGUMENTS
        $1 - string, required. The target variable name.
        $2 - string, required. The name of the function that is returning
             the value.

    RETURNS
        0 always.

    SIDE EFFECTS
        May unset one local of a function further up the stack, and may add
        that function to "_EZ_I_LOCALS".

    IMPORTANT: The target is unset ONLY when it is one of that function
    locals. Unsetting anything else would destroy the caller variable,
    attributes and all.
    '

    # NOTE: A function this has never seen is read NOW and remembered.
    #
    # The sweep at load time covers this library. It cannot cover a caller
    # that did not exist yet - anybody using "ez_i.emit_scalar" and its
    # relatives in their OWN functions, which is what those are public for.
    # Without this, their locals would be invisible here and their callers
    # would go unprotected, silently.
    #
    # Measured at about 1.4 ms, paid once per function and then cached. The
    # one thing it does not survive is a function REDEFINED after its first
    # emit: the entry would then describe the old body. Accepted - redefining
    # a function mid run is not something this library sets out to support.
    # By Questor
    if [ -z "${_EZ_I_LOCALS[$2]+x}" ] ; then
        ez_i._scan_locals "$2"
    fi

    case "${_EZ_I_LOCALS[$2]}" in
        *" $1 "*) unset "$1" ;;
    esac
    return 0
}

function ez_i.emit_scalar() {
    : 'Hand a value back the way the caller asked for it.

    ARGUMENTS
        $1 - string, required. The target: a variable NAME, or "-" to print
             the value to stdout with no trailing newline.
        $2 - string, required. The value.

    RETURNS
        0 on success, 1 when the target is empty.

    Call it as the LAST thing a function does. Several calls are fine, one
    per target, for a function that returns more than one value.
    '

    if [ -z "$1" ] ; then
        echo "ERROR! A target variable name, or \"-\", is required." >&2
        return 1
    fi
    if [[ "$1" == "-" ]] ; then
        printf '%s' "$2"
        return 0
    fi
    ez_i._unshadow "$1" "${FUNCNAME[1]}"
    local -n _ez_i_rtn_ref="$1"
    _ez_i_rtn_ref="$2"
}

function ez_i.emit_bool() {
    : 'Hand a true or false answer back the way the caller asked for it.

    ARGUMENTS
        $1 - string, required. The target: a variable NAME, or "" to answer
             through the exit status.
        $2 - integer, required. The answer, 1 for true and 0 for false.

    RETURNS
        With an EMPTY target, the answer itself: 0 for true, 1 for false,
        the way "test" and "grep -q" behave.

        With a NAMED target, 0 always, because the answer went into the
        variable and the status then only reports that the check was made.
        That is what keeps the named form safe under "set -e".

    The two forms read opposite ways round on purpose: "0" from a command
    means success, "0" in a variable means false, and each half follows the
    convention of where it lives.
    '

    if [ -z "$1" ] ; then
        (( $2 == 1 )) && return 0
        return 1
    fi
    ez_i._unshadow "$1" "${FUNCNAME[1]}"
    local -n _ez_i_bool_ref="$1"
    _ez_i_bool_ref="$2"
    return 0
}

function ez_i.emit_array() {
    : 'Hand an INDEXED array back to the caller.

    ARGUMENTS
        $1 - string, required. The target variable NAME.
        $2 - string, required. The NAME of the indexed array holding the
             result, normally a local of whoever calls this.

    RETURNS
        0 on success, 1 when either name is empty.

    IMPORTANT: The contents are COPIED into this function before anything is
    unset. Without that, a target named after the source - "ez_i.split
    parts" where the source is also called "parts" - would have its data
    destroyed by the very unset meant to reveal the caller variable.
    '

    if [ -z "$1" ] || [ -z "$2" ] ; then
        echo "ERROR! A target and a source array name are required." >&2
        return 1
    fi
    local -n _ez_i_src_ref="$2"
    local -a _ez_i_copy=("${_ez_i_src_ref[@]}")
    unset -n _ez_i_src_ref

    ez_i._unshadow "$1" "${FUNCNAME[1]}"
    local -n _ez_i_dst_ref="$1"
    _ez_i_dst_ref=("${_ez_i_copy[@]}")
}

function ez_i.emit_assoc() {
    : 'Hand an ASSOCIATIVE array back to the caller.

    ARGUMENTS
        $1 - string, required. The target variable NAME.
        $2 - string, required. The NAME of the associative array holding the
             result, normally a local of whoever calls this.

    RETURNS
        0 on success, 1 when either name is empty.

    IMPORTANT: As with "ez_i.emit_array", the contents are copied first.

    NOTE: The copy is key by key, so a large associative array costs.
    Nothing in this library returns one of more than a handful of keys.
    '

    if [ -z "$1" ] || [ -z "$2" ] ; then
        echo "ERROR! A target and a source array name are required." >&2
        return 1
    fi
    local -n _ez_i_src_ref="$2"
    local -A _ez_i_copy=()
    local _ez_i_key=""
    for _ez_i_key in "${!_ez_i_src_ref[@]}" ; do
        _ez_i_copy["$_ez_i_key"]="${_ez_i_src_ref[$_ez_i_key]}"
    done
    unset -n _ez_i_src_ref

    ez_i._unshadow "$1" "${FUNCNAME[1]}"
    local -n _ez_i_dst_ref="$1"
    _ez_i_dst_ref=()
    for _ez_i_key in "${!_ez_i_copy[@]}" ; do
        _ez_i_dst_ref["$_ez_i_key"]="${_ez_i_copy[$_ez_i_key]}"
    done
}

# RECEIVING AN ARRAY
#
# A function that READS an array the caller named has the mirror image of the
# problem, and the opposite answer: there is nothing to unset, because
# unsetting would destroy the input. It binds the nameref and copies out of
# it as its FIRST two statements, while no local of its own exists yet to
# shadow the name:
#
#     function ez_i.array_to_file() {
#         local -n _ez_i_src_ref="$2"
#         local -a items=("${_ez_i_src_ref[@]}")
#         unset -n _ez_i_src_ref
#         local file=$1                       # locals from here on, freely
#         ...
#     }

# <<<<<< HANDING A VALUE BACK

# TRAPS >>>>>>

# [Ref(s).: https://stackoverflow.com/a/7287873/3223785 ,
# https://opensource.com/article/20/6/bash-trap ]
function ez_i.trap_add() {
    : 'Add a command to one or more traps, keeping whatever is already there.

    ARGUMENTS
        $1  - string, required. The command the trap should run.
        $2+ - string, at least one, required. Signal names, one per
              argument. "trap -l" lists them.

    RETURNS
        0 always.

    SIDE EFFECTS
        Replaces each named trap with the command it already had followed by
        the new one.

    Plain "trap" REPLACES, which is how a library and the script that uses it
    end up quietly destroying each others handlers. This recovers the command
    already installed out of what "trap -p" prints and puts it back first.
    '

    local trap_command=$1
    shift
    local trap_signal=""
    for trap_signal in "$@" ; do
        # shellcheck disable=SC2064
        trap -- "$(

            # NOTE: Recovers the command already on this trap, if any, out of
            # what "trap -p" prints, so that adding one never drops it.
            ez_i._extract_trap_command() { printf '%s\n' "$3"; }

            eval "ez_i._extract_trap_command $(trap -p "$trap_signal")"
            printf '%s\n' "$trap_command"
        )" "$trap_signal"
    done
}

# NOTE: Marked for tracing so that the trap survives into subshells and
# functions that run under "set -T".
declare -f -t ez_i.trap_add

# <<<<<< TRAPS
