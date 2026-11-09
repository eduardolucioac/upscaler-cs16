#!/bin/bash
#
# ez_i/presentation.bash - opening, closing, warning and exiting
#
# Part of "ez_i". Sourced by "ez_i.bash", never on its own: it relies on what
# the parts before it defined.
#
# These are the screens a script shows at its edges: what it is before it
# starts, what it did when it finishes, and why it stopped when it could not.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# OPENING AND CLOSING >>>>>>

function ez_i.start() {
    : 'Print the opening screen of a product.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 when the
             screen had to be paged and 0 when it did not, or "" to discard
             that.
        $2 - string, required. Title.
        $3 - string, required. Version.
        $4 - string, required. What the product is.
        $5 - string, required. What the user should know before carrying on.
        $6 - string, required. Who makes it.

    RETURNS
        0 always.

    SIDE EFFECTS
        Clears the terminal, before and - when it had to page - after.

    Use it at the very start of the run.
    '

    local target=$1

    ((EZ_I_SKIP_ON == 1)) && return 0

    clear
    local screen=""
    screen=$(
        ez_i.open_section "$2 ($3)"
        ez_i.sub_section "ABOUT:" "$4"
        ez_i.sub_section "WARNINGS:" "$5"
        ez_i.divider
        echo "$6"
        ez_i.close_section
    )

    local paged=0
    ez_i.print_long paged "$screen"
    if [ "$paged" -eq 1 ] ; then
        clear
    fi
    if [ -n "$target" ] ; then
        ez_i._bool "$target" "$paged"
    fi
    return 0
}

function ez_i.end() {
    : 'Print the closing screen of a product.

    ARGUMENTS
        $1 - string, required. Title.
        $2 - string, required. Anything useful to know now that it is done.

    RETURNS
        0 always.

    Use it at the very end of the run.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0

    local screen=""
    screen=$(
        ez_i.open_section "$1"
        ez_i.sub_section "USEFUL INFORMATION:" "$2"
        ez_i.close_section
    )
    ez_i.print_long "" "$screen"
}

function ez_i.terms() {
    : 'Print the licence and terms, and ask the user to accept them.

    ARGUMENTS
        $1 - string, required. The licence and terms text.

    RETURNS
        0 when the user accepts. Does not return otherwise: the process
        exits with 0, because declining is not a failure.

    SIDE EFFECTS
        Clears the terminal first.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0

    clear
    local screen=""
    screen=$(
        ez_i.open_section "LICENSE/TERMS:"
        echo "$1" | ez_i.indent 2
    )
    ez_i.print_long "" "$screen"
    ez_i.divider

    local accepted=0
    ez_i.ask_yes_no accepted \
        "BY ANSWERING YES (y) YOU WILL AGREE WITH TERMS AND CONDITIONS PRESENTED! PROCEED?"
    ez_i.close_section
    sleep 1
    if [ "$accepted" -eq 0 ] ; then
        exit 0
    fi
    return 0
}

function ez_i.instructions() {
    : 'Print instructions about a product.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 when the
             screen had to be paged and 0 when it did not, or "" to discard
             that.
        $2 - string, required. The instructions.

    RETURNS
        0 always.

    SIDE EFFECTS
        Clears the terminal, before and - when it had to page - after.
    '

    local target=$1

    ((EZ_I_SKIP_ON == 1)) && return 0

    local screen=""
    screen=$(
        ez_i.open_section "INSTRUCTIONS:"
        echo "$2" | ez_i.indent 2
        echo ""
        ez_i.close_section
    )
    clear

    local paged=0
    ez_i.print_long paged "$screen"
    if [ "$paged" -eq 1 ] ; then
        clear
    fi
    if [ -n "$target" ] ; then
        ez_i._bool "$target" "$paged"
    fi
    return 0
}

# <<<<<< OPENING AND CLOSING

# WARNING AND EXITING >>>>>>

# SIGNALLING BY EAR >>>>>>

# What each kind sounds like: the frequency in hertz, how long one tone
# lasts, and how many of them. Low and repeated for trouble, one short high
# one for things going right - the shape carries the meaning even from the
# next room, which is the whole point of signalling by ear.
declare -A _EZ_I_TONE_HZ=([success]=660 [warning]=440 [error]=220)
declare -A _EZ_I_TONE_COUNT=([success]=1 [warning]=2 [error]=3)
declare _EZ_I_TONE_SECONDS="0.18"

function ez_i._one_tone() {
    : 'Play one tone, or ring the terminal bell when that is not possible.

    ARGUMENTS
        $1 - integer, required. Frequency in hertz.

    RETURNS
        0 always.

    "speaker-test" is killed after a moment rather than asked for a length,
    because it has no option for one: left alone it plays until stopped.

    IMPORTANT: KILLED WITH -9. It IGNORES SIGTERM - a plain "kill" returns
    success and the tone goes on playing for ever, one leaked process per
    call. Measured: SIGTERM leaves it running, SIGKILL ends it.

    When it is NOT there to kill - not installed, or no sound device for it
    to open - it has already exited by the time the kill is tried, and that
    failure is what says to fall back to the bell.
    '

    speaker-test --test sine --frequency "$1" > /dev/null 2>&1 &
    local tone_pid=$!
    sleep "$_EZ_I_TONE_SECONDS"
    if kill -9 "$tone_pid" > /dev/null 2>&1 ; then
        wait "$tone_pid" > /dev/null 2>&1
    else
        printf '\a'
    fi
    return 0
}

function ez_i.sound() {
    : 'Signal how something went, by sound.

    ARGUMENTS
        $1 - string, required. "success", "warning" or "error".

    RETURNS
        0 on success, 1 when the kind is not one of the three.

    The sound is made in the BACKGROUND: a script that has just finished
    should not then wait around for a noise. It lasts under a second and a
    half even for the longest of the three.

    There is no flag to silence this. Sound is asked for a call at a time,
    so a script that wants none simply does not ask; and a script that wants
    to offer the choice has its own configuration to offer it in, which is
    where a decision about one machine belongs - not in the library.

    Sounds under EZ_I_SKIP_ON too. That flag means NOBODY IS THERE TO
    ANSWER, not "say nothing", and the run nobody is watching is the one
    most worth hearing.

    EXAMPLE
        long_job && ez_i.sound "success" || ez_i.sound "error"
    '

    local kind=$1
    if [ -z "${_EZ_I_TONE_HZ[$kind]+x}" ] ; then
        echo "ERROR! \"$kind\" is not a kind of sound. Use \"success\", \
\"warning\" or \"error\"." >&2
        return 1
    fi
    local hertz="${_EZ_I_TONE_HZ[$kind]}"
    local count="${_EZ_I_TONE_COUNT[$kind]}"
    (
        local i=0
        for ((i = 0; i < count; i++)); do
            ((i > 0)) && sleep "$_EZ_I_TONE_SECONDS"
            ez_i._one_tone "$hertz"
        done
    ) > /dev/null 2>&1 &

    # NOTE: Disowned so that the shell does not announce the background job,
    # and does not wait for it on the way out. By Questor
    disown 2> /dev/null
    return 0
}

# <<<<<< SIGNALLING BY EAR

# What each kind of message is headed with. The sound of the same name goes
# with it, which is why there are three of each and not three of one and two
# of the other.
declare -A _EZ_I_MESSAGE_TITLE=(
    [success]="S U C C E S S !"
    [warning]="W A R N I N G !"
    [error]="E R R O R !"
)

function ez_i.notify() {
    : 'Put a message in front of the user, and wait for them to take it in.

    ARGUMENTS
        $1 - string, required. "success", "warning" or "error". Chooses the
             heading and, when $4 asks for it, the sound.
        $2 - string, required. The message.
        $3 - integer, optional. How to leave the message on screen:
             1 - ask whether to carry on, and exit when the answer is no;
             0 - wait for enter; -1 - do not wait at all. Default 0.

             Anything else is refused rather than taken for the default. A
             message that was meant to stop the run and silently did not is
             the kind of mistake that only shows up in front of somebody.
        $4 - integer, optional. 1 - sound it as well; 0 - do not. Default 0.
             Which sound is not asked for: it is the one of $1.

    RETURNS
        0 when the user carries on, 1 when the kind is not one of the three.
        Does not return when $3 is 1 and the answer is no.

    SHOWN EVEN WITH EZ_I_SKIP_ON SET. That flag means nobody is there to
    answer, not "say nothing", and a message worth putting in a box is worth
    putting in the log of an unattended run too. What it does NOT do then is
    WAIT - there would be nobody to wait for. The sound is made either way,
    for the same reason: the run nobody is watching is the one most likely
    to be noticed by ear.

    "ez_i.success", "ez_i.warning" and "ez_i.error" are this with the kind
    already filled in, and are what to reach for.

    IMPORTANT: None of the three stops the script. To report and stop, use
    "ez_i.fail_exit".
    '

    local kind=$1
    if [ -z "${_EZ_I_MESSAGE_TITLE[$kind]+x}" ] ; then
        echo "ERROR! \"$kind\" is not a kind of message. Use \"success\", \
\"warning\" or \"error\"." >&2
        return 1
    fi

    # NOTE: Checked BEFORE a word is printed, so a call that is wrong does
    # not half happen. By Questor
    local wait_mode=$3
    if [ -z "$wait_mode" ] ; then
        wait_mode=0
    fi
    case "$wait_mode" in
        -1|0|1) ;;
        *)
            echo "ERROR! \"$wait_mode\" is not a way to wait. Use 1 to ask \
whether to carry on, 0 to wait for enter, or -1 not to wait." >&2
            return 1
        ;;
    esac
    if [ -n "$4" ] && [ "$4" -eq 1 ] ; then
        ez_i.sound "$kind"
    fi

    local was_skipping=$EZ_I_SKIP_ON
    EZ_I_SKIP_ON=0
    echo ""
    ez_i.open_section "${_EZ_I_MESSAGE_TITLE[$kind]}"
    echo "$2"
    echo ""
    ez_i.close_section

    EZ_I_SKIP_ON=$was_skipping
    ((EZ_I_SKIP_ON == 1)) && return 0

    case "$wait_mode" in
        1) ez_i.ask_continue ;;
        0) ez_i.enter_to_continue ;;
    esac
    return 0
}

function ez_i.success() {
    : 'Say that something went well. See "ez_i.notify" for the arguments,
    which are its own minus the kind.'

    ez_i.notify "success" "$1" "$2" "$3"
}

function ez_i.warning() {
    : 'Warn about something. See "ez_i.notify" for the arguments, which are
    its own minus the kind.'

    ez_i.notify "warning" "$1" "$2" "$3"
}

function ez_i.error() {
    : 'Report that something went wrong. See "ez_i.notify" for the
    arguments, which are its own minus the kind.'

    ez_i.notify "error" "$1" "$2" "$3"
}

function ez_i.okay_exit() {
    : 'Print why the run is stopping and exit, successfully.

    ARGUMENTS
        $1 - string, optional. What made it stop.

    RETURNS
        Does not return. The process exits with 0.

    For a run that ended on purpose, cancelled by the user for instance.
    Use "ez_i.fail_exit" for one that went wrong.
    '

    EZ_I_SKIP_ON=0
    local message="THE EXECUTION WAS TERMINATED!"
    if [ -n "$1" ] ; then
        message="$message
CAUSE: $1"
    fi
    echo ""
    ez_i.open_main_section "I N F O R M A T I O N !"
    echo "$message"
    echo ""
    ez_i.close_main_section
    exit 0
}

function ez_i.fail_exit() {
    : 'Print what went wrong and exit, unsuccessfully.

    ARGUMENTS
        $1 - string, optional. The detail of the error.

    RETURNS
        Does not return. The process exits with 1.
    '

    EZ_I_SKIP_ON=0
    local message="AN ERROR OCCURRED AND THE EXECUTION WAS TERMINATED!"
    if [ -n "$1" ] ; then
        message="$message
----
$1
----"
    fi
    echo ""
    ez_i.open_main_section "E R R O R !"
    echo "$message"
    echo ""
    ez_i.close_main_section
    exit 1
}

# <<<<<< WARNING AND EXITING
