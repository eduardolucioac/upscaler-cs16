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

function ez_i.warning() {
    : 'Print a warning, and wait for the user to take it in.

    ARGUMENTS
        $1 - string, required. The warning.
        $2 - integer, optional. 1 - ask whether to carry on, and exit when
             the answer is no; 0 - only wait for enter. Default 0.

    RETURNS
        0 when the user carries on. Does not return when $2 is 1 and the
        answer is no.

    NOTE: A warning is shown even with EZ_I_SKIP_ON set, because the point
    of a warning is to be seen. What it does NOT do then is wait.
    '

    local was_skipping=$EZ_I_SKIP_ON
    EZ_I_SKIP_ON=0

    echo ""
    ez_i.open_section "W A R N I N G !"
    echo "$1"
    echo ""
    ez_i.close_section

    EZ_I_SKIP_ON=$was_skipping
    ((EZ_I_SKIP_ON == 1)) && return 0

    if [ -n "$2" ] && [ "$2" -eq 1 ] ; then
        ez_i.ask_continue
    else
        ez_i.enter_to_continue
    fi
    return 0
}

function ez_i.okay_exit() {
    : 'Print why the run is stopping and exit, successfully.

    ARGUMENTS
        $1 - string, optional. What made it stop.

    RETURNS
        Does not return. The process exits with 0.

    For a run that ended on purpose, cancelled by the user for instance.
    Use "ez_i.error_exit" for one that went wrong.
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

function ez_i.error_exit() {
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
