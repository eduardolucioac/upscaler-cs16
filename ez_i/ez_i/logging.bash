#!/bin/bash
#
# ez_i/logging.bash - writing output and error logs
#
# Part of "ez_i". Sourced by "ez_i.bash", never on its own: it relies on what
# the parts before it defined.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# LOGGING >>>>>>

function ez_i.log() {
    : 'Write an entry to a log file, creating the file and its folder.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving the path of
             the log that was written, or "" to discard it. KEEP IT on the
             first call of a timestamped log and pass it back as $4, which
             is how every later entry reaches the same file.
        $2 - string, required. The entry. It is prefixed with the time.
        $3 - string, optional. Which log: 0 - the output log; 1 - the error
             log. Default 0.
        $4 - string, optional. Where it goes:
                 "" ................ "<folder>/output.log" or
                                     "<folder>/error.log", appended to
                 "new" ............. a new timestamped file, "output-D....log"
                 "<prefix>" ........ a new timestamped file named after the
                                     prefix, "<prefix>-D....log"
                 "<path>/<file>" ... exactly that file, appended to. This is
                                     what the first call gave back.
             Default "".
        $5 - string, optional. The folder to create the log in. Default a
             "logs" folder beside the library.
        $6 - integer, optional. 1 - also print the entry on screen; 0 - do
             not. Default 0.

    RETURNS
        0 on success, 1 when the log cannot be written.

    SIDE EFFECTS
        Creates the folder when it is missing, and appends one line.

    EXAMPLE
        declare MY_LOG
        ez_i.log MY_LOG "Started." 0 "new" "$PWD/logs" 1
        ez_i.log "" "Step one done." 0 "$MY_LOG" "" 1
        ez_i.log "" "Step two done." 0 "$MY_LOG" "" 1
    '

    local target=$1
    local entry=$2
    local kind=$3
    local mode=$4
    local folder=$5
    local on_screen=$6

    if [ -z "$kind" ] ; then
        kind=0
    fi
    if [ -z "$on_screen" ] ; then
        on_screen=0
    fi

    local file=""
    local suffix=""

    if [[ "$mode" == */* ]] ; then

        # A path was given, which is what the first call handed back. The
        # folder already exists in that case, so nothing else is decided.
        file="$mode"
    else
        if [ -z "$folder" ] ; then
            folder="$_EZ_I_DIR/logs"
        fi
        if [ ! -d "$folder" ] ; then
            mkdir -p "$folder" || {
                echo "ERROR! Unable to create the log folder \"$folder\"." >&2
                return 1
            }
        fi

        case "$mode" in
            "")
                if [ "$kind" -eq 1 ] ; then
                    file="$folder/error.log"
                else
                    file="$folder/output.log"
                fi
            ;;
            "new")
                # [Ref(s).: https://www.tutorialkart.com/bash-shell-scripting/bash-date-format-options-examples/ ]
                suffix=$(date +"-D%Y-%m-%d-T%H-%M-%S")
                if [ "$kind" -eq 1 ] ; then
                    file="$folder/error$suffix.log"
                else
                    file="$folder/output$suffix.log"
                fi
            ;;
            *)
                suffix=$(date +"-D%Y-%m-%d-T%H-%M-%S")
                file="$folder/$mode$suffix.log"
            ;;
        esac
    fi

    if [ "$on_screen" -eq 1 ] ; then
        echo "$entry"
    fi

    echo "$(date +"D%Y-%m-%d-T%H-%M-%S-%N") - $entry" >> "$file" || {
        echo "ERROR! Unable to write to the log \"$file\"." >&2
        return 1
    }

    if [ -n "$target" ] ; then
        ez_i.emit_scalar "$target" "$file"
    fi
}

function ez_i.clean_old_logs() {
    : 'Delete all but the most recent logs of a folder.

    ARGUMENTS
        $1 - string, required. The log folder.
        $2 - integer, required. How many of the most recent files to KEEP.

    RETURNS
        0 on success, 1 when the folder is not there or the count is not a
        positive number.

    SIDE EFFECTS
        Removes files. Subfolders are left alone.

    The most recent are kept by MODIFICATION TIME, not by the timestamp in
    the name, so a log that is still being appended to counts as recent.
    '

    local folder=$1
    local keep=$2

    if [ ! -d "$folder" ] ; then
        return 0
    fi
    if ! [[ "$keep" =~ ^[0-9]+$ ]] ; then
        echo "ERROR! \"$keep\" is not a number of logs to keep." >&2
        return 1
    fi

    # [Ref(s).: https://stackoverflow.com/a/34862475/3223785 ,
    # https://stackoverflow.com/a/3572628/3223785 ]
    find "$folder" -maxdepth 1 -type f -printf '%T@ %p\0' 2> /dev/null \
        | sort -zrn \
        | tail -z -n "+$((keep + 1))" \
        | cut -z -d' ' -f2- \
        | xargs -0 -r rm -f --
}

# <<<<<< LOGGING
