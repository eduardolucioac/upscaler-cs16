#!/bin/bash
#
# ez_i/strings.bash - splitting, trimming, reversing and "sed"
#
# Part of "ez_i". Sourced by "ez_i.bash", never on its own: it relies on what
# the parts before it defined.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# STRINGS >>>>>>

function ez_i.trim() {
    : 'Remove whitespace from the start and/or the end of a string.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - string, required. The string to trim.
        $3 - integer, optional. 0 - leading only; 1 - trailing only;
             2 - both ends. Default 0.

    RETURNS
        0 on success, 1 when the target is empty.

    Pure BASH, so no sub process is spawned however often it is called.
    '

    local target=$1
    local value=$2
    local mode=$3
    if [ -z "$mode" ] ; then
        mode=0
    fi

    case $mode in
        0)
            value="${value#"${value%%[![:space:]]*}"}"
        ;;
        1)
            value="${value%"${value##*[![:space:]]}"}"
        ;;
        2)
            value="${value#"${value%%[![:space:]]*}"}"
            value="${value%"${value##*[![:space:]]}"}"
        ;;
        *)
            echo "ERROR! \"$mode\" is not a trim mode. Use 0, 1 or 2." >&2
            return 1
        ;;
    esac
    ez_i.emit_scalar "$target" "$value"
}

function ez_i.reverse() {
    : 'Reverse a string, lines and characters alike.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - string, required. The string to reverse.

    RETURNS
        0 on success, 1 when the target is empty.

    Reversing the result gives the original back. "tac" reverses the lines
    and "rev" the characters within each one, which together reverse the
    whole string.

    IMPORTANT: Trailing newlines do not survive, because command
    substitution strips them.
    '

    local target=$1
    local value=""
    value=$(echo "$2" | tac | rev)
    ez_i.emit_scalar "$target" "$value"
}

# [Ref(s).: https://stackoverflow.com/a/73263419/3223785 ,
# https://stackoverflow.com/a/73225463/10971581 ]
function ez_i.split() {
    : 'Split a string into an array.

    ARGUMENTS
        $1 - string, required. The NAME of an INDEXED array to fill. Declare
             it "-a" first; it is emptied before anything is written.
        $2 - string, required. The string to split.
        $3 - string, optional. The delimiter, taken LITERALLY. Default a
             single space.

    RETURNS
        0 on success, 1 when the target is empty.

    Empty fields are kept, so "a,,b" gives three items and a trailing
    delimiter gives a trailing empty one. A string with no delimiter in it
    comes back as a single item.

    IMPORTANT: "\n" between DOUBLE QUOTES is a backslash followed by an "n",
    not a line break. Pass $'"'"'\n'"'"' to split into lines. Getting this wrong
    returns the whole string as one item, silently.

    Pure BASH, no "awk", no "tr", no subshell.
    '

    if [ -z "$1" ] ; then
        echo "ERROR! A target array name is required." >&2
        return 1
    fi
    local remaining="$2"
    local delimiter="$3"
    if [ -z "$delimiter" ] ; then
        delimiter=" "
    fi

    local -a parts=()
    local item=""
    while
        item="${remaining%%"$delimiter"*}"
        parts+=("$item")
        remaining="${remaining:${#item}}"
        ((${#remaining}))
    do
        remaining="${remaining:${#delimiter}}"
    done
    ez_i.emit_array "$1" parts
}

# <<<<<< STRINGS

# "SED" >>>>>>

# [Ref(s).: https://stackoverflow.com/a/2705678/3223785 ]
function ez_i.sed_escape() {
    : 'Escape a string so "sed" takes it literally.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - string, required. The value to escape.
        $3 - integer, required. 0 - for the PATTERN side; 1 - for the
             REPLACEMENT side. The two need different characters escaped.

    RETURNS
        0 on success, 1 when the target is empty.

    Escaped sequences are processed as written, so "sed" should be given the
    "-z" flag when the value may span lines. "ez_i.sed_str" and
    "ez_i.sed_file" already do that.
    '

    local target=$1
    local value=$2
    local side=$3

    # NOTE: The operational characters of "sed" are escaped, and single
    # quotes with them.
    if [ "$side" -eq 0 ] ; then
        value=$(echo "$value" \
            | sed 's/[]\/$*.^[]/\\&/g' \
            | sed "s/'/\\\x27/g" \
            | sed ':a;N;$!ba;s/\n/\\n/g')
    else
        value=$(echo "$value" \
            | sed 's/[\/&]/\\&/g' \
            | sed "s/'/\\\x27/g" \
            | sed ':a;N;$!ba;s/\n/\\n/g')
    fi
    ez_i.emit_scalar "$target" "$value"
}

function ez_i._sed_program() {
    : 'Build the "sed" program for a replacement.

    ARGUMENTS
        $1 - string, required. Target variable NAME.
        $2 - string, required. The pattern, ALREADY escaped.
        $3 - string, required. The replacement, ALREADY escaped.
        $4 - integer, required. Which occurrence: 1~n the nth, 0 every one,
             -1 the last.

    RETURNS
        0 on success.
    '

    local target=$1
    local pattern=$2
    local replacement=$3
    local nth=$4
    local program=""

    if [ "$nth" -eq -1 ] ; then

        # NOTE: Kept as its own case because it performs better than
        # reversing the input when only the last occurrence is wanted.
        # [Ref(s).: https://linuxhint.com/use-sed-replace-last-occurrence/ ,
        # https://unix.stackexchange.com/a/713866/61742 ]
        program="'s/\(.*\)$pattern/\1$replacement/'"
    elif [ "$nth" -gt 0 ] ; then
        # [Ref(s).: https://unix.stackexchange.com/a/587924/61742 ]
        program="'s/$pattern/$replacement/$nth'"
    else
        program="'s/$pattern/$replacement/g'"
    fi
    ez_i.emit_scalar "$target" "$program"
}

# [Ref(s).: https://stackoverflow.com/a/24134488/3223785 ,
# https://stackoverflow.com/a/21740695/3223785 ,
# https://unix.stackexchange.com/a/655558/61742 ,
# https://unix.stackexchange.com/a/525524/61742 ]
function ez_i.sed_str() {
    : 'Replace in a string, matching literally.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - string, required. The string to work on.
        $3 - string, required. What to replace, taken LITERALLY.
        $4 - string, required. What to replace it with, taken LITERALLY.
        $5 - integer, optional. Which occurrence: 1~n the nth; 0 every one;
             -1 the last; below -1 the nth from the end. Default 1.

    RETURNS
        0 on success, 1 when the target is empty.

    Both sides are escaped for you, so a dot, a slash or an ampersand in
    either is just that character.

    IMPORTANT: Trailing newlines of the result do not survive, because
    command substitution strips them.
    '

    local target=$1
    local source=$2
    local pattern=$3
    local replacement=$4
    local nth=$5
    if [ -z "$nth" ] ; then
        nth=1
    fi

    # Counting from the end, past the last one, is done by reversing
    # everything, counting from the start, and reversing the result back.
    local reversed=0
    if [ "$nth" -lt -1 ] ; then
        reversed=1
        ez_i.reverse pattern "$pattern"
        ez_i.reverse replacement "$replacement"
        ez_i.reverse source "$source"
        nth=$((-nth))
    fi

    ez_i.sed_escape pattern "$pattern" 0
    ez_i.sed_escape replacement "$replacement" 1

    local program=""
    ez_i._sed_program program \
        "$pattern" "$replacement" "$nth"

    # NOTE: "-z" because the pattern is always literal and may span lines.
    local result=""
    result=$(echo "$source" | eval "sed -z $program")

    if [ "$reversed" -eq 1 ] ; then
        ez_i.reverse result "$result"
    fi
    ez_i.emit_scalar "$target" "$result"
}

function ez_i.sed_file() {
    : 'Replace in a file, in place, matching literally.

    ARGUMENTS
        $1 - string, required. The file.
        $2 - string, required. What to replace, taken LITERALLY.
        $3 - string, required. What to replace it with, taken LITERALLY.
        $4 - integer, optional. Which occurrence: 1~n the nth; 0 every one;
             -1 the last; below -1 the nth from the end. Default 1.

    RETURNS
        0 on success, 1 when the file cannot be read.

    SIDE EFFECTS
        Rewrites the file.

    Both sides are escaped for you, so a dot, a slash or an ampersand in
    either is just that character.
    '

    local file=$1
    local pattern=$2
    local replacement=$3
    local nth=$4
    if [ -z "$nth" ] ; then
        nth=1
    fi
    if [ ! -f "$file" ] ; then
        echo "ERROR! \"$file\" is not a file." >&2
        return 1
    fi

    local reversed=0
    if [ "$nth" -lt -1 ] ; then
        reversed=1
        ez_i.reverse pattern "$pattern"
        ez_i.reverse replacement "$replacement"
        nth=$((-nth))
    fi

    ez_i.sed_escape pattern "$pattern" 0
    ez_i.sed_escape replacement "$replacement" 1

    local program=""
    ez_i._sed_program program \
        "$pattern" "$replacement" "$nth"

    if [ "$reversed" -eq 0 ] ; then
        eval "sed -i -z $program \"\$file\""
    else
        local reversed_text=""
        reversed_text=$(tac "$file" | rev \
            | eval "sed -z $program" | tac | rev)
        printf '%s\n' "$reversed_text" > "$file"
    fi
}

# <<<<<< "SED"
