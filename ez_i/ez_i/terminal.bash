#!/bin/bash
#
# ez_i/terminal.bash - drawing on the terminal and paging what is too long
#
# Part of "ez_i". Sourced by "ez_i.bash", never on its own: it relies on what
# the parts before it defined.
#
# Everything in here is silenced by EZ_I_SKIP_ON, since none of it means
# anything to a script running unattended.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# SECTIONS >>>>>>

function ez_i.indent() {
    : 'Indent whatever is piped through it.

    ARGUMENTS
        $1 - integer, required. How many spaces: 2, 4 or 8.

    RETURNS
        0 on success, 1 on an unsupported level.

    Usage: echo "$MY_TEXT" | ez_i.indent 4
    '

    case "$1" in
        2) sed 's/^/  /' ;;
        4) sed 's/^/    /' ;;
        8) sed 's/^/        /' ;;
        *)
            echo "ERROR! \"$1\" is not an indent level. Use 2, 4 or 8." >&2
            return 1
        ;;
    esac
}

function ez_i.divider() {
    : 'Print a divider inside a section.

    RETURNS
        0 always.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0
    echo "----------------------------------"
}

function ez_i.open_section() {
    : 'Print the opening of a section.

    ARGUMENTS
        $1 - string, optional. Section title. The title and the divider
             under it are left out when it is empty.

    RETURNS
        0 always.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0
    echo "> ------------------------------------------------"
    if [ -n "$1" ] ; then
        echo "$1"
        ez_i.divider
        echo ""
    fi
}

function ez_i.close_section() {
    : 'Print the closing of a section.

    RETURNS
        0 always.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0
    echo "< ------------------------------------------------"
    echo ""
}

function ez_i.open_main_section() {
    : 'Print the opening of a main section, which groups other sections.

    ARGUMENTS
        $1 - string, optional. Section title. The title and the divider
             under it are left out when it is empty.

    RETURNS
        0 always.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0
    echo "> =================================================================="
    if [ -n "$1" ] ; then
        echo "$1"
        ez_i.divider
        echo ""
    fi
}

function ez_i.close_main_section() {
    : 'Print the closing of a main section.

    RETURNS
        0 always.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0
    echo "< =================================================================="
    echo ""
}

function ez_i.sub_section() {
    : 'Print a subsection.

    ARGUMENTS
        $1 - string, required. Subsection title.
        $2 - string, required. Subsection body, indented under the title.

    RETURNS
        0 always.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0
    echo "> $1" | ez_i.indent 2
    echo ""
    echo "$2" | ez_i.indent 4
    echo ""
}

# <<<<<< SECTIONS

# PAGING >>>>>>

declare _EZ_I_PAGER_KEYS
_EZ_I_PAGER_KEYS="
[ NAVIGATE: "$(echo -e '\U2193')" down arrow | "$(echo -e '\U2191')" up arrow | "$(echo -e '\U21DF')" page down | "$(echo -e '\U21DE')" page up | "$(echo -e '\U2195')" mouse wheel ]
[ CONTINUE: q ]
"

function ez_i.print_long() {
    : 'Print text, paging it when it is taller than the terminal.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 when the
             text was paged and 0 when it was not, or "" to discard that.
        $2 - string, required. The text.

    RETURNS
        0 always.

    Knowing whether the text was paged is what lets a caller decide to clear
    the screen afterwards, which is why it is reported.

    Paging needs a terminal, both to measure against and for "less" itself.
    Without one - a pipe, a cron job, a CI run - the text is printed whole
    and 0 is reported. A terminal that reports a nonsense size is treated
    the same way.
    '

    local target=$1
    local text=$2

    if ((EZ_I_SKIP_ON == 1)) ; then
        ez_i.emit_bool "$target" 0 > /dev/null 2>&1
        return 0
    fi

    if ((_EZ_I_HAS_TERMINAL == 0)) ; then
        echo "$text"
        [ -n "$target" ] && ez_i.emit_bool "$target" 0
        return 0
    fi

    local rows=0
    local columns=0
    read -r rows columns < <(stty size 2> /dev/null)
    if [ -z "$rows" ] || [ -z "$columns" ] \
        || [ "$rows" -lt 2 ] ; then
        echo "$text"
        [ -n "$target" ] && ez_i.emit_bool "$target" 0
        return 0
    fi

    local length=$(( ${#_EZ_I_PAGER_KEYS} + ${#text} ))
    local lines=0
    lines=$(echo -n "$_EZ_I_PAGER_KEYS$text" | grep -c '^')
    local capacity=$(( (rows - 1) * columns ))

    if [ "$length" -gt "$capacity" ] \
        || [ "$lines" -gt $((rows - 1)) ] ; then
        echo -n "$_EZ_I_PAGER_KEYS$text" | less -F

        # NOTE: Printed again so that the last screenful stays visible after
        # "less" gives the terminal back.
        echo "$_EZ_I_PAGER_KEYS$text"

        [ -n "$target" ] && ez_i.emit_bool "$target" 1
        return 0
    fi

    echo "$text"
    [ -n "$target" ] && ez_i.emit_bool "$target" 0
    return 0
}

# <<<<<< PAGING
