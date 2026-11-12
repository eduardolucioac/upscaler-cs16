#!/bin/bash
#
# ez_i/files.bash - files, folders, arrays on disk and backups
#
# Part of "ez_i". Sourced by "ez_i.bash", never on its own: it relies on what
# the parts before it defined.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# CHECKING >>>>>>

function ez_i.exists() {
    : 'Check whether a file or a folder is there.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 when it is
             there and 0 when it is not, or "" to answer through the exit
             status.
        $2 - string, required. "f" to check for a file, "d" for a directory.
        $3 - string, required. The path. A relative one works.

    RETURNS
        See "ez_i.emit_bool". With an empty target: 0 when it is there.
        2 on an unknown type, which is neither answer.

    A path that exists but is of the other kind answers false, not true: a
    file is not a directory.

    EXAMPLE
        ez_i.exists "" "d" "$TARGET" || ez_i.fail_exit "No target folder!"

        declare IS_THERE
        ez_i.exists IS_THERE "f" "$CONFIG"
        if [ "$IS_THERE" -eq 1 ] ; then ... ; fi
    '

    case "$2" in
        "f")
            [ -f "$3" ] && { ez_i.emit_bool "$1" 1; return; }
        ;;
        "d")
            [ -d "$3" ] && { ez_i.emit_bool "$1" 1; return; }
        ;;
        *)
            echo "ERROR! \"$2\" is not a check type. Use \"f\" or \"d\"." >&2
            return 2
        ;;
    esac
    ez_i.emit_bool "$1" 0
}

function ez_i.file_contains() {
    : 'Check whether a file contains a given string.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 when it does
             and 0 when it does not, or "" to answer through the exit
             status.
        $2 - string, required. The file to look in.
        $3 - string, required. The string to look for, matched LITERALLY.
        $4 - integer, optional. 1 - invert the check; 0 - do not. Default 0.

    RETURNS
        See "ez_i.emit_bool". With an empty target: 0 when it does contain it.

    The string is matched literally, so a dot, a bracket or an asterisk in it
    is just that character and nothing has to be escaped first.

    NOTE: This only answers. A predicate that could also stop to show the
    user a message would be a surprise in the middle of a condition.
    '

    local file=$2
    local needle=$3
    local invert=$4
    if [ -z "$invert" ] ; then
        invert=0
    fi

    local found=0
    if grep -qF -- "$needle" "$file" 2> /dev/null ; then
        found=1
    fi
    if [ "$invert" -eq 1 ] ; then
        found=$((1 - found))
    fi
    ez_i.emit_bool "$1" "$found"
}

# [Ref(s).: https://stackoverflow.com/a/23122112/3223785 ]
function ez_i.delete_if_empty() {
    : 'Delete a folder, but only if it is empty.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 when the
             folder was deleted and 0 when it was not, or "" to answer
             through the exit status.
        $2 - string, required. The folder.
        $3 - integer, optional. 1 - treat a folder holding nothing but
             hidden files as empty; 0 - do not. Default 0.

    RETURNS
        See "ez_i.emit_bool". With an empty target: 0 when it was deleted.

    SIDE EFFECTS
        Removes the folder when it is empty. A folder that is not empty, or
        that is not there at all, is left exactly as it was.
    '

    local folder=$2
    local ignore_hidden=$3
    if [ -z "$ignore_hidden" ] ; then
        ignore_hidden=0
    fi

    if [ ! -d "$folder" ] ; then
        ez_i.emit_bool "$1" 0
        return
    fi

    if [ "$ignore_hidden" -eq 0 ] ; then

        # NOTE: "rmdir" refuses a folder that is not empty, which is exactly
        # the test, and makes the check and the removal one atomic step.
        if rmdir "$folder" 2> /dev/null ; then
            ez_i.emit_bool "$1" 1
            return
        fi
    elif [ -z "$(find "$folder" -mindepth 1 -not -path '*/.*')" ] ; then
        rm -rf "${folder:?}"
        ez_i.emit_bool "$1" 1
        return
    fi
    ez_i.emit_bool "$1" 0
}

# <<<<<< CHECKING

# ARRAYS ON DISK >>>>>>

function ez_i.array_to_file() {
    : 'Write an array to a file, one element per line.

    ARGUMENTS
        $1 - string, required. The file to write. It is overwritten.
        $2 - string, required. The NAME of the array to write.

    RETURNS
        0 on success, 1 when the array name is empty or the write fails.

    IMPORTANT: One element per line, so an element containing a NEWLINE
    comes back as several. Use it for lists of paths, names and flags, which
    is what it is for.
    '

    if [ -z "$2" ] ; then
        echo "ERROR! A source array name is required." >&2
        return 1
    fi

    # NOTE: Bound and copied FIRST, while no local of this function exists
    # yet to shadow the name the caller gave. See "ez_i/bootstrap.bash",
    # RECEIVING AN ARRAY.
    local -n _ez_i_src_ref="$2"
    local -a items=("${_ez_i_src_ref[@]}")
    unset -n _ez_i_src_ref

    # [Ref(s).: https://stackoverflow.com/a/20243503/3223785 ]
    printf "%s\n" "${items[@]}" > "$1"
}

function ez_i.file_to_array() {
    : 'Read a file into an array, one line per element.

    ARGUMENTS
        $1 - string, required. The NAME of an INDEXED array to fill. Declare
             it "-a" first; it is emptied before anything is read.
        $2 - string, required. The file to read.

    RETURNS
        0 on success, 1 when the target is empty or the file cannot be read.

    The line endings are dropped; everything else on the line is kept,
    leading and trailing spaces included.
    '

    if [ -z "$1" ] ; then
        echo "ERROR! A target array name is required." >&2
        return 1
    fi
    if [ ! -r "$2" ] ; then
        echo "ERROR! Unable to read \"$2\"." >&2
        return 1
    fi
    local -a lines=()
    # [Ref(s).: https://stackoverflow.com/a/11395181/3223785 ]
    readarray -t lines < "$2"
    ez_i.emit_array "$1" lines
}

# <<<<<< ARRAYS ON DISK

# BACKUPS >>>>>>

function ez_i.backup() {
    : 'Move or copy a file or folder aside, under a timestamped name.

    ARGUMENTS
        $1 - string, required. The NAME of an ASSOCIATIVE array to receive
             where it went, or "" to discard that. Declare it "-A" first; it
             is emptied here. The keys written are:
                 [name] .. the new name, without its folder
                 [path] .. the folder it sits in
                 [full] .. the two joined, which is the usual thing to want
        $2 - string, required. The file or folder to back up.
        $3 - integer, optional. 0 - RENAME it, leaving nothing behind;
             1 - COPY it, leaving the original in place. Default 0.
        $4 - integer, optional. 1 - only work out the name and write
             nothing at all; 0 - do the backup. Default 0.

    RETURNS
        0 on success, 1 when the source is not there or the move fails.

    The suffix is "-D%Y-%m-%d-T%H-%M-%S_BAK", which sorts chronologically.

    IMPORTANT: The timestamp has a resolution of one SECOND, so two backups
    of the same path within the same second resolve to the same name.

    EXAMPLE
        declare -A WENT_TO=()
        ez_i.backup WENT_TO "$MY_FOLDER"
        echo "Backed up to ${WENT_TO[full]}"
    '

    local target=$1
    local source=$2
    local copy=$3
    local name_only=$4
    if [ -z "$copy" ] ; then
        copy=0
    fi
    if [ -z "$name_only" ] ; then
        name_only=0
    fi

    local new=""
    new="$source$(date +'-D%Y-%m-%d-T%H-%M-%S')_BAK"

    if [ "$name_only" -eq 0 ] ; then
        if [ ! -e "$source" ] ; then
            echo "ERROR! \"$source\" is not there." >&2
            return 1
        fi
        if [ "$copy" -eq 0 ] ; then
            mv "$source" "$new" || return 1
        else
            cp -r "$source" "$new" || return 1
        fi
    fi

    if [ -z "$target" ] ; then
        return 0
    fi
    local -A went_to=(
        [name]="$(basename "$new")"
        [path]="$(dirname "$new")"
        [full]="$new"
    )
    ez_i.emit_assoc "$target" went_to
}

# <<<<<< BACKUPS
