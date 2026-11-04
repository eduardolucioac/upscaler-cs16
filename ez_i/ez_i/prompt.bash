#!/bin/bash
#
# ez_i/prompt.bash - asking the user things
#
# Part of "ez_i". Sourced by "ez_i.bash", never on its own: it relies on what
# the parts before it defined.
#
# Everything in here returns straight away, asking nothing, when
# EZ_I_SKIP_ON is 1. A target variable is left exactly as the caller had it,
# so give it the default you want before asking.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# READING >>>>>>

function ez_i.read() {
    : 'Read a line from the user.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - string, required. The prompt.
        $3 - integer, optional. 1 - a password, so it is not echoed;
             0 - an ordinary line. Default 0.
        $4 - integer, optional. Give up after this many seconds. Default
             wait forever.
        $5 - string, conditionally required. What to assume when the wait
             runs out. Required whenever $4 is given: a timeout has to leave
             SOMETHING in the target, and an empty answer is not one.

    RETURNS
        0 on success, 1 when the target is empty.

    Tab completion works, and enter submits.

    NOTE: The prompt is printed with "echo" rather than handed to "read -p"
    because a long enough prompt makes "read" fall over with "Segmentation
    fault (core dumped)", among other misbehaviour.
    '

    local target=$1
    local prompt=$2
    local is_password=$3
    local timeout=$4
    local on_timeout=$5
    local answer=""

    # NOTE: A timeout running out has to leave something in the target, and
    # the library has nothing of its own to put there. An empty answer is not
    # an answer: it cannot be told apart from a person who just pressed
    # enter, and it gets announced in the prompt as ("" in 30 seconds), which
    # tells the reader nothing. So the caller says what it is, or this is a
    # mistake in the calling script and is reported as one. By Questor
    if [ -n "$timeout" ] && [ -z "$on_timeout" ] ; then
        echo "ERROR! \"ez_i.read\" was given a timeout but no answer to use \
when it runs out." >&2
        return 1
    fi

    if ((EZ_I_SKIP_ON == 1)) ; then
        return 0
    fi
    if [ -z "$is_password" ] ; then
        is_password=0
    fi

    local -a read_options=(-e -r)
    if [ "$is_password" -eq 1 ] ; then
        read_options+=(-s)
    fi
    if [ -n "$timeout" ] ; then
        read_options+=("-t$timeout")
        prompt="$prompt (\"$on_timeout\" in $timeout seconds) "
    fi

    echo -n "$prompt"
    read "${read_options[@]}" answer

    # NOTE: "read" leaves the cursor where it was when it echoed nothing, so
    # a newline is owed: after a password, after a timeout, and after a bare
    # enter.
    if { [ "$is_password" -eq 1 ] && [ -n "$answer" ]; } \
        || [ -z "$answer" ] ; then
        echo ""
    fi

    if [ -n "$timeout" ] && [ -z "$answer" ] ; then
        answer=$on_timeout
    fi
    ez_i._emit "$target" "$answer"
}

function ez_i.ask() {
    : 'Ask the user a question and read the answer.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - string, required. The question. It is paged when it is longer
             than the terminal.
        $3 - integer, optional. 1 - accept an empty answer; 0 - refuse it
             and ask again. Default 0.
        $4 - integer, optional. 1 - a password, so it is not echoed;
             0 - an ordinary line. Default 0.

    RETURNS
        0 on success, 1 when the target is empty.
    '

    local target=$1
    local question=$2
    local allow_empty=$3
    local is_password=$4
    local answer=""

    if ((EZ_I_SKIP_ON == 1)) ; then
        return 0
    fi
    if [ -z "$allow_empty" ] ; then
        allow_empty=0
    fi
    if [ -z "$is_password" ] ; then
        is_password=0
    fi

    while : ; do
        ez_i.print_long "" "$question"
        ez_i.read answer " (use enter to confirm): " "$is_password"
        if [ -n "$answer" ] || [ "$allow_empty" -eq 1 ] ; then
            break
        fi

    done
    ez_i._emit "$target" "$answer"
}

function ez_i.ask_option() {
    : 'Ask the user to pick one of a list of options.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving the option
             chosen.
        $2 - string, required. Target variable NAME receiving the
             DESCRIPTION of that option, or "" to discard it.
        $3 - string, required. The question. The options are listed for the
             user automatically.
        $4 - string, required. The NAME of an INDEXED array holding the
             options: EVEN positions are the options themselves and ODD
             positions the description of the option before them.
        $5 - integer, optional. 1 - accept an empty answer; 0 - refuse it
             and ask again. Default 0.

    RETURNS
        0 on success, 1 when a required name is empty or the array is not
        made of pairs.

    An answer that is not one of the options asks again.

    EXAMPLE
        declare -a CHOICES=("y" "Go ahead" "n" "Stop here")
        declare PICKED DESCRIPTION
        ez_i.ask_option PICKED DESCRIPTION "What now?" CHOICES
    '

    if [ -z "$4" ] ; then
        echo "ERROR! An options array name is required." >&2
        return 1
    fi

    # NOTE: Bound and copied FIRST, while no local of this function exists
    # yet to shadow the name the caller gave. See "ez_i/bootstrap.bash",
    # RECEIVING AN ARRAY. The two values this function RETURNS go out
    # through "ez_i._emit" at the end, which is the other half of the same
    # story.
    local -n _ez_i_src_ref="$4"
    local -a options=("${_ez_i_src_ref[@]}")
    unset -n _ez_i_src_ref

    local target=$1
    local desc_target=$2
    local question=$3
    local allow_empty=$5

    if ((EZ_I_SKIP_ON == 1)) ; then
        return 0
    fi
    if [ -z "$allow_empty" ] ; then
        allow_empty=0
    fi
    if (( ${#options[@]} % 2 != 0 )) ; then
        echo "ERROR! The options array must hold pairs of option and description." >&2
        return 1
    fi

    local listing="(select your option and press enter: "
    local separator=""
    local i=0
    for ((i = 0; i < ${#options[@]}; i += 2)) ; do
        listing+="$separator${options[$i]} - ${options[$((i + 1))]}"
        separator=" | "
    done
    listing+=")"

    local answer=""
    local description=""
    local matched=0
    while : ; do
        ez_i.read answer "$question
$listing: "

        if [ -z "$answer" ] && [ "$allow_empty" -eq 1 ] ; then
            break
        fi

        matched=0
        for ((i = 0; i < ${#options[@]}; i += 2)) ; do
            if [ "$answer" == "${options[$i]}" ] ; then
                description="${options[$((i + 1))]}"
                matched=1
                break
            fi
        done
        ((matched == 1)) && break
    done

    if [ -n "$desc_target" ] ; then
        ez_i._emit "$desc_target" "$description"
    fi
    ez_i._emit "$target" "$answer"
}

function ez_i.ask_yes_no() {
    : 'Ask the user a yes or no question.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 for yes and
             0 for no, or "" to answer through the exit status.
        $2 - string, required. The question. " (y/n)" is appended.
        $3 - integer, optional. Give up after this many seconds. Default
             wait forever.
        $4 - integer, conditionally required. The answer to use WHEN NOBODY
             ANSWERS, 1 for yes and 0 for no. Required whenever that can
             happen: when $3 is given, and when EZ_I_SKIP_ON is set.

    RETURNS
        See "ez_i._bool". With an empty target: 0 for yes.

        1, having written nothing and printed the reason on stderr, when
        nobody can answer and $4 did not say what to do. See below.

    NOBODY TO ANSWER

    A timeout running out and EZ_I_SKIP_ON being set are the same situation
    - the question was put and no person answered it - so they take the same
    answer, $4, and there is only one of it.

    It has NO DEFAULT, and that is the point. Whether an unanswered question
    should carry on or stop belongs to the QUESTION: "update your distro?"
    wants yes, "disable SELinux?" wants no. Any constant the library picked
    would be wrong for one of them, and wrong SILENTLY - which is how a
    destructive step gets confirmed by an empty terminal, or a harmless one
    refused for no reason.

    So a question that can go unanswered and does not say what to do then is
    a mistake in the CALLING script, and it is reported as one rather than
    guessed at. The timeout half is checked even with a person present, so
    the mistake surfaces on the first run instead of the first unattended
    one.

    Both "y" and "s" are taken as yes, which the Portuguese "sim" earns.
    Anything else asks again.

    EXAMPLE
        ez_i.ask_yes_no "" "Carry on?" || ez_i.okay_exit "Canceled by user."
    '

    local target=$1
    local question=$2
    local timeout=$3
    local unanswered=$4

    if [ -n "$unanswered" ] \
        && [ "$unanswered" != "0" ] && [ "$unanswered" != "1" ] ; then
        echo "ERROR! The answer \"ez_i.ask_yes_no\" is to use when nobody \
answers must be 1 or 0." >&2
        return 1
    fi

    # Checked whether or not the timeout is about to be used, so that a
    # question which COULD go unanswered is caught on the first run.
    if [ -n "$timeout" ] && [ -z "$unanswered" ] ; then
        echo "ERROR! \"ez_i.ask_yes_no\" was given a timeout but no answer \
to use when it runs out." >&2
        return 1
    fi

    if ((EZ_I_SKIP_ON == 1)) ; then
        if [ -z "$unanswered" ] ; then
            echo "ERROR! \"ez_i.ask_yes_no\" has nobody to answer it \
(EZ_I_SKIP_ON) and was given no answer to use." >&2
            return 1
        fi
        ez_i._bool "$target" "$unanswered"
        return
    fi

    local default=""
    if [ -n "$timeout" ] ; then
        if [ "$unanswered" -eq 1 ] ; then
            default="y"
        else
            default="n"
        fi
    fi

    local answer=""
    while : ; do
        if [ -z "$timeout" ] ; then
            ez_i.read answer "$question (y/n) "
        else
            ez_i.read answer "$question (y/n)" 0 \
                "$timeout" "$default"
        fi

        if [[ $answer =~ ^([sS]|[yY])$ ]] ; then
            ez_i._bool "$target" 1
            return
        fi
        if [[ $answer =~ ^([nN])$ ]] ; then
            echo "NO!"
            ez_i._bool "$target" 0
            return
        fi

    done
}

function ez_i.enter_to_continue() {
    : 'Wait for the user to press enter.

    ARGUMENTS
        $1 - string, optional. Something to show first, between dividers.
        $2 - integer, optional. Carry on by itself after this many seconds.
             Default wait forever.

    RETURNS
        0 always.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0

    if [ -n "$1" ] ; then
        ez_i.divider
        echo "$1"
        ez_i.divider
    fi
    if [ -z "$2" ] ; then
        ez_i.read - "Press enter to continue..." > /dev/null
    else
        ez_i.read - "Press enter to continue..." 0 "$2" "Enter" > /dev/null
    fi
    return 0
}

function ez_i.ask_continue() {
    : 'Ask the user whether to carry on, and EXIT when the answer is no.

    ARGUMENTS
        $1 - string, optional. Anything else the user should know first.

    RETURNS
        0 when the answer is yes. Does not return otherwise: the process
        exits with 0, because stopping on purpose is not a failure.
    '

    ((EZ_I_SKIP_ON == 1)) && return 0

    local note=$1
    if [ -n "$note" ] ; then
        note=" (NOTE: \"$note\")"
    fi

    ez_i.divider
    local answer=0
    ez_i.ask_yes_no answer "CONTINUE? (USE \"n\" TO STOP)$note"
    ez_i.divider
    if [ "$answer" -eq 0 ] ; then
        exit 0
    fi
    return 0
}

# <<<<<< READING
