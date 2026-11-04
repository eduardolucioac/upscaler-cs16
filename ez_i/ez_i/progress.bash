#!/bin/bash
#
# ez_i/progress.bash - showing that something long is still running
#
# Part of "ez_i". Sourced by "ez_i.bash", never on its own: it relies on what
# the parts before it defined.
#
# Two separate things live here. "ez_i.progress" is an animation for work
# whose length is unknown. The "ez_i.task_stats_*" family is for a loop whose
# length IS known, and reports how far along it is and how long is left.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# ANIMATION >>>>>>

function ez_i._working_animation() {
    : 'Draw the spinner, forever, until killed.

    RETURNS
        Never returns on its own.

    Run in the background by "ez_i.progress" and killed by it.
    '

    local -a frames=("|" "W" "O" "R" "K" "I" "N" "G" "." "." "." "|")
    local i=0
    while : ; do
        echo -n "|          |"
        sleep 0.2
        printf "\r"
        for ((i = 0; i <= 11; i++)); do
            echo -n "${frames[$i]}"
            sleep 0.2
        done
        printf "\r"
    done
}

# [Ref(s).: https://stackoverflow.com/q/12498304/3223785 ,
# https://stackoverflow.com/a/5722850/3223785 ]
function ez_i.progress() {
    : 'Start or stop the "something is happening" animation.

    ARGUMENTS
        $1 - string, required. "a" to start it, "o" to stop it.
        $2 - string, optional. A line printed above the animation when
             starting, saying what is happening.

    RETURNS
        0 on success, 1 on an unknown action.

    SIDE EFFECTS
        Starts or kills a background process.

    Stopping an animation that is not running is harmless, which matters
    because the library installs a trap that stops it on the way out however
    the script ends.

    IMPORTANT: Does not nest. One animation at a time.

    EXAMPLE
        ez_i.progress "a" " > Extracting..."
        tar -xzf package.tar.gz
        ez_i.progress "o"
    '

    ((EZ_I_SKIP_ON == 1)) && return 0

    case "$1" in
        "a")
            if [ -n "$2" ] ; then
                echo "$2"
            fi
            ez_i._working_animation &
            _EZ_I_ANIMATION_PID=$!
        ;;
        "o")
            if ((_EZ_I_ANIMATION_PID > 0)) ; then
                { kill -9 "$_EZ_I_ANIMATION_PID" && wait "$_EZ_I_ANIMATION_PID"; } \
                    > /dev/null 2>&1
                printf "\r"
            fi
            _EZ_I_ANIMATION_PID=0
        ;;
        *)
            echo "ERROR! \"$1\" is not a progress action. Use \"a\" or \"o\"." >&2
            return 1
        ;;
    esac
}

# <<<<<< ANIMATION

# TASK STATISTICS >>>>>>

# How far a loop has got and how much longer it is likely to take.
#
# The state lives in an associative array the CALLER declares and passes in,
# which is what lets two nested loops each keep their own count. There is no
# global set of counters to fall back on, so nesting cannot be got wrong.
#
#     declare -A MY_TASK=()
#     ez_i.task_stats_init MY_TASK "${#ITEMS[@]}"
#     for ITEM in "${ITEMS[@]}" ; do
#         ez_i.task_stats_begin MY_TASK
#         do_something_slow "$ITEM"
#         declare STATS
#         ez_i.task_stats_end STATS MY_TASK
#         echo "$STATS"
#     done
#
# IMPORTANT: No floating point. The smallest unit is the millisecond, so a
# loop whose iterations are faster than that reports nothing useful.

# [Ref(s).: https://stackoverflow.com/a/16908136/3223785 ,
# https://stackoverflow.com/a/16961051/3223785 ,
# https://askubuntu.com/a/385532/134723 ]
function ez_i.task_stats_init() {
    : 'Set up the counters for a loop.

    ARGUMENTS
        $1 - string, required. The NAME of an ASSOCIATIVE array to hold the
             state. Declare it "-A" first; it is emptied here.
        $2 - integer, required. How many items the loop will go through, NOT
             zero based.
        $3 - integer, optional. How much the loop counter advances each
             iteration. Default 1.
        $4 - integer, optional. Which position the count starts at, zero
             based. Default 0.

    RETURNS
        0 on success, 1 when the target is empty or the length is not a
        positive number.
    '

    if [ -z "$1" ] ; then
        echo "ERROR! A target associative array name is required." >&2
        return 1
    fi
    local length=$2
    local increment=$3
    local start_at=$4

    if ! [[ "$length" =~ ^[0-9]+$ ]] ; then
        echo "ERROR! \"$length\" is not a task length." >&2
        return 1
    fi
    if [ -z "$increment" ] ; then
        increment=1
    fi
    if [ -z "$start_at" ] ; then
        start_at=0
    fi

    local -A counters=(
        [length]="$length"
        [increment]="$increment"
        [counter]="$start_at"
        [started_at]=0
        [total_time]=0
        [total_items]=$((length / increment))
        [skipped]=0
    )
    ez_i._emit_assoc "$1" counters
}

function ez_i.task_stats_begin() {
    : 'Mark the start of one iteration.

    ARGUMENTS
        $1 - string, required. The NAME of the associative array passed to
             "ez_i.task_stats_init".

    RETURNS
        0 on success, 1 when the target is empty.
    '

    if [ -z "$1" ] ; then
        echo "ERROR! A target associative array name is required." >&2
        return 1
    fi
    # NOTE: Read, changed and written back rather than mutated through a
    # nameref, so that "ez_i._emit_assoc" can take the target off the scope
    # chain first. A counter array named after one of the locals below would
    # otherwise never be updated. See "ez_i/bootstrap.bash".
    # NOTE: An ASSOCIATIVE array has to be copied key by key, so the
    # destination exists BEFORE the first read - and if it had a plain name
    # the caller might have picked it, making the nameref read that empty
    # local instead of their array. The snapshot therefore carries a library
    # private name. An indexed array needs none of this: "local -a x=(
    # "${ref[@]}" )" evaluates the right hand side first.
    local -n _ez_i_src_ref="$1"
    local -A _ez_i_counters=()
    local _ez_i_key=""
    for _ez_i_key in "${!_ez_i_src_ref[@]}" ; do
        _ez_i_counters["$_ez_i_key"]="${_ez_i_src_ref[$_ez_i_key]}"
    done
    unset -n _ez_i_src_ref

    _ez_i_counters[started_at]=$(($(date +%s%N) / 1000000))
    ez_i._emit_assoc "$1" _ez_i_counters
}

function ez_i._task_stats_close() {
    : 'Finish one iteration and build the line that describes where it got to.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - string, required. The NAME of the associative array.
        $3 - integer, required. 1 when the iteration counted towards the
             time estimate, 0 when it was skipped.

    RETURNS
        0 on success, 1 when either name is empty.
    '

    if [ -z "$2" ] ; then
        echo "ERROR! A target associative array name is required." >&2
        return 1
    fi

    # NOTE: Copied in first, changed, then written back, for the reason
    # given in "ez_i.task_stats_begin".
    # NOTE: An ASSOCIATIVE array has to be copied key by key, so the
    # destination exists BEFORE the first read - and if it had a plain name
    # the caller might have picked it, making the nameref read that empty
    # local instead of their array. The snapshot therefore carries a library
    # private name. An indexed array needs none of this: "local -a x=(
    # "${ref[@]}" )" evaluates the right hand side first.
    local -n _ez_i_src_ref="$2"
    local -A _ez_i_counters=()
    local _ez_i_key=""
    for _ez_i_key in "${!_ez_i_src_ref[@]}" ; do
        _ez_i_counters["$_ez_i_key"]="${_ez_i_src_ref[$_ez_i_key]}"
    done
    unset -n _ez_i_src_ref

    local target=$1
    local counted=$3

    ((_ez_i_counters[counter]++))

    # NOTE: A task set up with a length of zero has nothing to report, and
    # dividing by it would print a BASH error into the caller's output.
    if ((_ez_i_counters[total_items] <= 0)) ; then
        ez_i._emit_assoc "$2" _ez_i_counters
        ez_i._emit "$target" "ITEMS LEFT 0/0 (100% SO FAR) / TIME LEFT 0ms"
        return 0
    fi

    local left=$((_ez_i_counters[total_items] - _ez_i_counters[counter]))
    local percent=$((_ez_i_counters[counter] * 100 / _ez_i_counters[total_items]))
    local time_left="<SKIPPED ITEM>"

    if ((counted == 1)) ; then
        local now=$(($(date +%s%N) / 1000000))
        _ez_i_counters[total_time]=$((
            _ez_i_counters[total_time] + now - _ez_i_counters[started_at]
        ))

        # NOTE: The average is over the iterations that actually ran, so the
        # skipped ones do not drag the estimate down.
        local counted_items=$((_ez_i_counters[counter] - _ez_i_counters[skipped]))
        if ((counted_items > 0)) ; then
            local average=$((_ez_i_counters[total_time] / counted_items))
            ez_i.format_time time_left $((average * left))
        else
            time_left="0ms"
        fi
    else
        ((_ez_i_counters[skipped]++))
    fi

    ez_i._emit_assoc "$2" _ez_i_counters
    ez_i._emit "$target" \
"ITEMS LEFT $left/${_ez_i_counters[total_items]} ($percent% SO FAR) / TIME LEFT $time_left"
}

function ez_i.task_stats_end() {
    : 'Mark the end of one iteration and describe where the loop got to.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - string, required. The NAME of the associative array passed to
             "ez_i.task_stats_init".

    RETURNS
        0 on success, 1 when either name is empty.

    The line reads "ITEMS LEFT 3/4 (25% SO FAR) / TIME LEFT 1m 20s". The time
    is an average of the iterations that have run so far, so it settles down
    as the loop goes on.
    '

    ez_i._task_stats_close "$1" "$2" 1
}

function ez_i.task_stats_skip() {
    : 'Mark one iteration as skipped and describe where the loop got to.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - string, required. The NAME of the associative array passed to
             "ez_i.task_stats_init".

    RETURNS
        0 on success, 1 when either name is empty.

    Use this for an item that was found to need no work. It still counts
    towards the progress, and deliberately does NOT count towards the time
    estimate, which would otherwise read as far faster than the real work is.
    '

    ez_i._task_stats_close "$1" "$2" 0
}

# <<<<<< TASK STATISTICS
