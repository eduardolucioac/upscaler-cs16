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

# The frames the "working" animation turns through. All the same width, so a
# line redrawn in place does not jitter as the word fills in.
declare -a _EZ_I_WORKING_FRAMES=(
    "|          |" "|          |" "|W         |" "|WO        |"
    "|WOR       |" "|WORK      |" "|WORKI     |" "|WORKIN    |"
    "|WORKING   |" "|WORKING.  |" "|WORKING.. |" "|WORKING...|"
)

# Which frame "ez_i.progress_draw" shows next, and whether it has drawn
# anything that still needs clearing.
declare -i _EZ_I_DRAW_FRAME=0
declare -i _EZ_I_DRAWING=0

function ez_i._working_animation() {
    : 'Draw the spinner, forever, until killed.

    RETURNS
        Never returns on its own.

    Run in the background by "ez_i.progress" and killed by it.
    '

    local i=0
    while : ; do
        for ((i = 0; i < ${#_EZ_I_WORKING_FRAMES[*]}; i++)); do
            printf '\r%s' "${_EZ_I_WORKING_FRAMES[$i]}"
            sleep 0.2
        done
    done
}

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
            if ((_EZ_I_DRAWING == 1)) ; then
                echo "ERROR! \"ez_i.progress_draw\" is already drawing. The \
two write to the same place on screen; clear one before starting the other." >&2
                return 1
            fi
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
function ez_i.progress_draw() {
    : 'Say what is being worked on and how far it has got, in place.

    ARGUMENTS
        $1 - string, required. What the step is doing.
        $2 - string, required. The item being worked on.
        $3 - string, required. Where the loop got to, as
             "ez_i.task_stats_end" writes it.

    RETURNS
        0 on success, 1 when "ez_i.progress" is already animating.

    TWO ROWS, BOTH REWRITTEN WHERE THEY ARE, so a loop over hundreds of items
    does not scroll everything else off the screen. The item goes on the
    first and the counters on the second, because an animation, a label, a
    path and the counters do not fit on one row of any ordinary terminal.

    Call it REPEATEDLY: each call advances the animation by one frame, and
    the frame is the only thing that says the work is alive. Calling it once
    per item finished is not enough - on a slow machine an item can take many
    seconds, and a spinner that only moves between items looks exactly like
    one that has stopped. "ez_i.progress_wait" is the way to drive it from
    work that is still running.

    The cursor is hidden while this draws, because the terminal would
    otherwise park it in the middle of the first row, where it blinks like a
    mistake. "ez_i.progress_clear" puts it back, and the library traps the
    ways out of a script so an interrupted run never leaves a terminal
    without one.

    IMPORTANT: NOT compatible with "ez_i.progress". That one animates from a
    BACKGROUND process writing to the same place, and the two would fight
    over it. Whichever starts second is refused.

    Does nothing with EZ_I_SKIP_ON set, and nothing when the output is not a
    terminal, so the same script stays readable in a pipe or a cron job.
    Note that the test is on the OUTPUT only: a script reading its answers
    from a file still has a screen worth drawing on.

    EXAMPLE
        declare -A TASK=() ; declare STATS=""
        ez_i.task_stats_init TASK "${#FILES[@]}"
        for FILE in "${FILES[@]}" ; do
            ez_i.task_stats_begin TASK
            convert_it "$FILE" &
            ez_i.progress_wait $! "Converting" "$FILE" "$STATS"
            ez_i.task_stats_end STATS TASK
        done
        ez_i.progress_clear
    '

    ((EZ_I_SKIP_ON == 1)) && return 0

    # NOTE: Checked BEFORE the terminal is, so that using the two together is
    # reported wherever it happens and not only where it would show. A
    # mistake that only surfaces on a machine with a terminal is a mistake
    # found by a user rather than by the author. By Questor
    if ((_EZ_I_ANIMATION_PID > 0)) ; then
        echo "ERROR! \"ez_i.progress\" is already animating. The two write to \
the same place on screen; stop one before starting the other." >&2
        return 1
    fi
    ((_EZ_I_HAS_SCREEN == 0)) && return 0

    local label=$1
    local item=$2
    local stats=$3

    _EZ_I_DRAWING=1

    # NOTE: "\033[?25l" hides the cursor, "\033[K" wipes what a previous and
    # longer line left behind, and "\033[1A" goes back up to the first of the
    # two rows - followed by "\r", because going up a line does not go back
    # to the first column.
    printf '\033[?25l\r\033[K %s %s: %s\n\r\033[K%s\033[1A\r' \
        "${_EZ_I_WORKING_FRAMES[$_EZ_I_DRAW_FRAME]}" "$label" "$item" "$stats"
    _EZ_I_DRAW_FRAME=$(((_EZ_I_DRAW_FRAME + 1) % ${#_EZ_I_WORKING_FRAMES[*]}))
    return 0
}

function ez_i.progress_clear() {
    : 'Wipe both rows and give the cursor back.

    RETURNS
        0 always.

    Harmless when nothing was drawn, which is what lets the library trap it
    on the ways out of a script.
    '

    ((_EZ_I_DRAWING == 0)) && return 0
    _EZ_I_DRAWING=0
    ((_EZ_I_HAS_SCREEN == 0)) && return 0
    printf '\r\033[K\n\r\033[K\033[1A\r\033[?25h'
    return 0
}

function ez_i.progress_wait() {
    : 'Wait for a background job, keeping the two rows moving while it runs.

    ARGUMENTS
        $1 - integer, required. The process id to wait for.
        $2 - string, required. What the step is doing.
        $3 - string, required. The item being worked on.
        $4 - string, required. Where the loop got to.

    RETURNS
        The job'"'"'s exit status, or 1 when no process id was given.

    This is what makes the animation turn DURING the work rather than
    between items. Drawing and working cannot be the same thing: while a
    foreground command runs, nothing redraws. So the work goes into the
    background and this waits for it, drawing as it goes.

    IMPORTANT: a job in the background cannot stop the calling script. Where
    the work would normally exit on failure, CHECK WHAT THIS RETURNS.

    With nothing to draw on it simply waits, with no polling.
    '

    local job_pid=$1
    local label=$2
    local item=$3
    local stats=$4

    if [ -z "$job_pid" ] ; then
        echo "ERROR! A process id is required." >&2
        return 1
    fi
    if ((EZ_I_SKIP_ON == 1)) || ((_EZ_I_HAS_SCREEN == 0)) ; then
        wait "$job_pid"
        return
    fi
    while kill -0 "$job_pid" 2> /dev/null ; do
        ez_i.progress_draw "$label" "$item" "$stats"
        sleep 0.2
    done
    wait "$job_pid"
}

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
