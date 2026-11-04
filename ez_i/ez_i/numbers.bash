#!/bin/bash
#
# ez_i/numbers.bash - time, percentages, byte units and UUIDs
#
# Part of "ez_i". Sourced by "ez_i.bash", never on its own: it relies on what
# the parts before it defined.
#
# BASH has no floating point arithmetic, so the parts of this file that need
# it hand the sum to "awk" rather than to "bc", which is not installed as
# often as people assume.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# NUMBERS >>>>>>

# [Ref(s).: https://unix.stackexchange.com/a/27014/61742 ]
function ez_i.format_time() {
    : 'Spell out a duration in days, hours, minutes and seconds.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - integer, required. The duration in MILLISECONDS.

    RETURNS
        0 on success, 1 when the target is empty.

    The units that are zero are left out, so the result reads as "1d 23h 27m
    16s" or just "16s". A duration under a second has nothing else to say
    and comes back as "520ms".
    '

    local target=$1
    local ms=$2
    local days=$((ms / 1000 / 60 / 60 / 24))
    local hours=$((ms / 1000 / 60 / 60 % 24))
    local minutes=$((ms / 1000 / 60 % 60))
    local seconds=$((ms / 1000 % 60))
    local result=""

    result=$(
        ((days > 0)) && printf '%dd ' "$days"
        ((hours > 0)) && printf '%dh ' "$hours"
        ((minutes > 0)) && printf '%dm ' "$minutes"
        ((seconds > 0)) && printf '%ds' "$seconds"
    )
    if [ -z "$result" ] ; then
        result=$(printf '%dms' "$ms")
    fi

    # NOTE: Each unit but the last prints a trailing space, so a duration
    # whose smallest unit is zero - a whole hour, a whole day - would
    # otherwise come out as "1h " and "1d ".
    result="${result% }"

    ez_i._emit "$target" "$result"
}

function ez_i.percent_of() {
    : 'Work out a percentage of a value.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - number, required. The value to take a percentage of.
        $3 - number, required. The percentage to take.
        $4 - integer, optional. What to do with the decimals, and only when
             the result is 1 or more: 0 - keep them; 1 - truncate;
             2 - round to the nearest whole number. Default 1.

    RETURNS
        0 on success, 1 when the target is empty.
    '

    local target=$1
    local value=$2
    local percent=$3
    local rounding=$4
    if [ -z "$rounding" ] ; then
        rounding=1
    fi

    local result=""
    result=$(awk '{printf("%.5f\n",($1*($2/100)))}' \
        <<< " $value $percent ")

    if [ "$rounding" -ge 1 ] ; then

        # NOTE: Comparing floating point values, again through "awk".
        if [ "$(awk '{printf($1 >= $2) ? 1 : 0}' <<< " $value 1 ")" -eq 1 ] ; then
            if [ "$rounding" -eq 1 ] ; then
                result=${result%\.*}
            elif [ "$rounding" -eq 2 ] ; then

                # NOTE: 10.7 -> 11, 10.5 -> 10, 10.4 -> 10...
                result=$(awk '{printf("%.0f\n", $1);}' <<< " $result ")
            fi
        fi
    fi
    ez_i._emit "$target" "$result"
}

function ez_i.convert_bytes() {
    : 'Convert a size between byte units.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - number, required. The value to convert.
        $3 - string, required. The unit it is in: B, KB, MB, GB, TB or PB.
        $4 - string, required. The unit to convert it to, same set.

    RETURNS
        0 on success, 1 on an unknown unit.

    Pointless trailing zeros and a pointless decimal point are removed, so
    5.00000 comes back as 5 and 0.05000 as 0.05.

    NOTE: These are the binary units, each step a factor of 1024.
    '

    local target=$1
    local value=$2
    local from=$3
    local to=$4

    local from_power=0
    local to_power=0
    ez_i._unit_power from_power "$from" || return 1
    ez_i._unit_power to_power "$to" || return 1

    local steps=$((from_power - to_power))
    value=$(awk '{printf("%.5f\n",($1*(1024^$2)))}' \
        <<< " $value $steps ")

    # NOTE: 0.05000 -> 0.05
    value=$(echo "$value" | sed 's/0\{1,\}$//')

    # NOTE: 5. -> 5
    if [ "$(echo "$value" | awk '$0-int($0){print 0;next}{print 1}')" -eq 1 ] ; then
        value=${value%\.*}
    fi
    ez_i._emit "$target" "$value"
}

function ez_i._unit_power() {
    : 'Turn a byte unit name into its power of 1024.

    ARGUMENTS
        $1 - string, required. Target variable NAME.
        $2 - string, required. The unit: B, KB, MB, GB, TB or PB.

    RETURNS
        0 on success, 1 on an unknown unit, with a message on stderr.
    '

    local target=$1
    local power=0
    case "$2" in
        "B")  power=0 ;;
        "KB") power=1 ;;
        "MB") power=2 ;;
        "GB") power=3 ;;
        "TB") power=4 ;;
        "PB") power=5 ;;
        *)
            echo "ERROR! \"$2\" is not a byte unit. Use B, KB, MB, GB, TB or PB." >&2
            return 1
        ;;
    esac
    ez_i._emit "$target" "$power"
}

function ez_i.uuid() {
    : 'Generate a UUID.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - integer, optional. 1 - remove the dashes; 0 - keep them.
             Default 0.

    RETURNS
        0 on success, 1 when no UUID source is available.

    The kernel is asked first, which costs no sub process at all, and
    "uuidgen" is the fallback.
    '

    local target=$1
    local no_dashes=$2
    local uuid=""

    if [[ -r /proc/sys/kernel/random/uuid ]] ; then
        read -r uuid < /proc/sys/kernel/random/uuid
    elif command -v uuidgen > /dev/null 2>&1 ; then
        uuid=$(uuidgen)
    else
        echo "ERROR! No UUID source available (\"/proc/sys/kernel/random/uuid\" or \"uuidgen\")." >&2
        return 1
    fi

    if [ -n "$no_dashes" ] && [ "$no_dashes" -eq 1 ] ; then
        uuid="${uuid//-/}"
    fi
    ez_i._emit "$target" "$uuid"
}

# <<<<<< NUMBERS
