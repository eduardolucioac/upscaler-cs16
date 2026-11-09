#!/bin/bash
#
# ez_i/system.bash - running commands and asking the machine about itself
#
# Part of "ez_i". Sourced by "ez_i.bash", never on its own: it relies on what
# the parts before it defined.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# RUNNING COMMANDS >>>>>>

# [Ref(s).: https://stackoverflow.com/a/18086548/3223785 ]
function ez_i.run() {
    : 'Run a command and capture its output and exit code.

    ARGUMENTS
        $1 - string, required. The NAME of an ASSOCIATIVE array to receive
             the result. Declare it "-A" first; it is emptied here. The keys
             written are:
                 [stdout] .. what the command wrote to stdout
                 [stderr] .. what it wrote to stderr
                 [both] .... both, stdout first, joined by a newline
                 [status] .. its exit code
        $2 - string, required. The command line. It is EVALUATED, so every
             path in it must already be quoted.

    RETURNS
        The exit code of the command, so "|| handle_it" works directly.
        1 with nothing run when the target is empty.

    The [both] key is there because a great many programs write their
    progress to stderr and their errors to stdout, or mix the two, so
    deciding which stream a message was on is often the wrong question.

    IMPORTANT: A BARE "exit N" cannot be reported, because it ends the
    capturing subshell before the code can be read back. Wrap it in a shell -
    "bash -c ..." - if that is really what is wanted.

    EXAMPLE
        declare -A RESULT=()
        ez_i.run RESULT "tar -xzf \"$MY_PACKAGE\"" || {
            ez_i.fail_exit "Extraction failed: ${RESULT[stderr]}"
        }
    '

    if [ -z "$1" ] ; then
        echo "ERROR! A target associative array name is required." >&2
        return 1
    fi
    local command=$2

    # NOTE: "t_err", "t_std" and "t_ret" are created by the "typeset -p" the
    # subshells below emit, so they have to be declared HERE or they land in
    # the caller scope and collide with whatever it had.
    local t_std=""
    local t_err=""
    local t_ret=0
    eval "$( eval "$command" \
        2> >(t_err=$(cat); typeset -p t_err) \
        > >(t_std=$(cat); typeset -p t_std); t_ret=$?; typeset -p t_ret )"

    local both=""
    if [ -n "$t_std" ] ; then
        both="$t_std"
    fi
    if [ -n "$t_err" ] ; then
        if [ -n "$both" ] ; then
            both="$both"$'\n'"$t_err"
        else
            both="$t_err"
        fi
    fi

    local -A result=(
        [stdout]="$t_std"
        [stderr]="$t_err"
        [both]="$both"
        [status]="$t_ret"
    )
    ez_i._emit_assoc "$1" result || return 1
    return "$t_ret"
}

# <<<<<< RUNNING COMMANDS

# THE MACHINE >>>>>>

function ez_i.is_root() {
    : 'Check whether this is running as root.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 for root and
             0 for not, or "" to answer through the exit status.

    RETURNS
        See "ez_i._bool". With an empty target: 0 when root.

    EXAMPLE
        ez_i.is_root "" || ez_i.fail_exit "You need to be root!"
    '

    if [[ $EUID -eq 0 ]] ; then
        ez_i._bool "$1" 1
        return
    fi
    ez_i._bool "$1" 0
}

function ez_i.is_running() {
    : 'Check whether a process - a service, for instance - is running.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 when it is
             running and 0 when it is not, or "" to answer through the exit
             status.
        $2 - string, required. The process name, matched anywhere in the
             process listing.

    RETURNS
        See "ez_i._bool". With an empty target: 0 when it is running.

    NOTE: The question is the POSITIVE one. A double negative in a
    condition is a good way to get it backwards.
    '

    # NOTE: The "grep -v grep" keeps the search from matching its own "grep"
    # process in the listing.
    if ps aux | grep -v "grep" | grep -q -- "$2" ; then
        ez_i._bool "$1" 1
        return
    fi
    ez_i._bool "$1" 0
}

function ez_i.package_installed() {
    : 'Check whether a package is installed.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 when it is
             installed and 0 when it is not, or "" to answer through the
             exit status.
        $2 - string, required. The package name.
        $3 - string, required. Which package manager to ask: "dnf", "yum",
             "apt-get", "zypper", "pacman" or "apk". This is what
             "ez_i.about_distro" reports as [package_manager].

    RETURNS
        See "ez_i._bool". With an empty target: 0 when it is installed.
        2 on an unsupported package manager, which is neither answer.
    '

    local package=$2
    local manager=$3
    local installed=0

    case "$manager" in
        "dnf"|"yum")

            # NOTE: "rpm -q" is asked rather than the package manager
            # itself: it is the database both of them write to, it answers
            # without touching the network, and it is the same question on
            # every RPM distribution.
            rpm -q "$package" > /dev/null 2>&1 \
                && installed=1
        ;;
        "apt-get")
            dpkg -s "$package" > /dev/null 2>&1 \
                && installed=1

            # NOTE: Gives "dpkg" a moment to let go of its lock. Without it,
            # a loop of these fails on Ubuntu Server against whatever
            # "unattended-upgrades" is doing.
            sleep 0.5
        ;;
        "zypper")
            zypper se -i --match-word "$package" > /dev/null 2>&1 \
                && installed=1
        ;;
        "pacman")
            pacman -Qi "$package" > /dev/null 2>&1 \
                && installed=1
        ;;
        "apk")
            apk info -e "$package" > /dev/null 2>&1 \
                && installed=1
        ;;
        *)
            echo "ERROR! \"$manager\" is not a supported package manager. Use \"dnf\", \"yum\", \"apt-get\", \"zypper\", \"pacman\" or \"apk\"." >&2
            return 2
        ;;
    esac
    ez_i._bool "$1" "$installed"
}

function ez_i.iptables_rule() {
    : 'Check whether an "iptables" rule is there, normally an open port.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving 1 when the
             rule is there and 0 when it is not, or "" to answer through the
             exit status.
        $2 - integer, required. The port.
        $3 - string, optional. Rule target. Default "ACCEPT".
        $4 - string, optional. Protocol. Default "tcp".
        $5 - string, optional. Connection state. Default none.
        $6 - integer, optional. Position in the chain. Default any.

    RETURNS
        See "ez_i._bool". With an empty target: 0 when the rule is there.

    IMPORTANT: 1, or an exit status of 0, means the rule IS there.

    EXAMPLE
        ez_i.iptables_rule "" 80 || echo "port 80 is not open"
    '

    local port=$2
    local rule_target=$3
    local protocol=$4
    local state=$5
    local position=$6

    if [ -z "$rule_target" ] ; then
        rule_target="ACCEPT"
    fi
    if [ -z "$protocol" ] ; then
        protocol="tcp"
    fi
    if [ -n "$state" ] ; then
        state="state $state "
    fi
    if [ -n "$position" ] ; then
        position=$(printf "%-9s" "$position")
    fi

    if iptables -vnL --line-numbers 2> /dev/null \
        | grep -- "$position" \
        | grep -- "$rule_target" \
        | grep -- "$state" \
        | grep -- "$protocol" \
        | grep -q -- "dpt:$port " ; then
        ez_i._bool "$1" 1
        return
    fi
    ez_i._bool "$1" 0
}

function ez_i.total_memory() {
    : 'Report how much RAM this machine has.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.

    RETURNS
        0 on success, 1 when "/proc/meminfo" cannot be read.

    The value is in KB, as "/proc/meminfo" reports it.
    '

    local target=$1
    if [ ! -r /proc/meminfo ] ; then
        echo "ERROR! Unable to read \"/proc/meminfo\"." >&2
        return 1
    fi
    local total=""
    total=$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)
    ez_i._emit "$target" "$total"
}

function ez_i.cpu_count() {
    : 'Report how many processors this machine has.

    ARGUMENTS
        $1 - string, required. Target variable NAME, or "-" for stdout.
        $2 - integer, optional. A factor to multiply the count by, which is
             how a sensible number of workers is usually arrived at.
             Default 1.

    RETURNS
        0 on success, 1 when "nproc" fails.
    '

    local target=$1
    local factor=$2
    if [ -z "$factor" ] ; then
        factor=1
    fi

    local count=""
    if ! count=$(nproc 2> /dev/null) ; then
        echo "ERROR! Unable to determine the number of processors (\"nproc\")." >&2
        return 1
    fi
    ez_i._emit "$target" "$((count * factor))"
}

# <<<<<< THE MACHINE

# THE DISTRIBUTION >>>>>>

function ez_i._release_key() {
    : 'Read one "KEY=value" out of release file text.

    ARGUMENTS
        $1 - string, required. Target variable NAME.
        $2 - string, required. The release file text to search.
        $3 - string, required. The key to read, "NAME" for instance.
        $4 - integer, optional. 1 - strip the surrounding double quotes from
             the value; 0 - return it as written. Default 1.

    RETURNS
        0 on success, 1 when the target is empty. A key that is not there is
        not an error; the value comes back empty.
    '

    local target=$1
    local text=$2
    local key=$3
    local unquote=$4
    if [ -z "$unquote" ] ; then
        unquote=1
    fi

    local -a lines=()
    local -a parts=()
    local -a quoted=()
    local i=0

    # NOTE: A real newline. "\n" between double quotes is a backslash and an
    # "n", and passing that would split nothing at all.
    ez_i.split lines "$text" $'\n'

    for ((i = 0; i < ${#lines[@]}; i++)) ; do
        ez_i.split parts "${lines[$i]}" "="
        if [ ${#parts[@]} -lt 2 ] \
            || [ "${parts[0]}" != "$key" ] ; then
            continue
        fi
        if [ "$unquote" -eq 1 ] ; then
            ez_i.split quoted "${parts[1]}" "\""
            if [ ${#quoted[@]} -gt 1 ] ; then
                ez_i._emit "$target" "${quoted[1]}"
                return
            fi
        fi
        ez_i._emit "$target" "${parts[1]}"
        return
    done
    ez_i._emit "$target" ""
}

function ez_i._classify_release() {
    : 'Work out what distribution a release file describes.

    ARGUMENTS
        $1 - string, required. The NAME of an ASSOCIATIVE array to fill.
        $2 - string, required. The contents of the release file.

    RETURNS
        0 always. An unrecognised distribution still reports its own name,
        version and architecture; only the family comes back "Unknown".

    Kept apart from "ez_i.about_distro" so that it can be given a release
    file from anywhere, which is what makes it testable on one machine.
    '

    local release=$2
    local id=""
    local id_like=""
    local name=""
    local version=""
    local based="Unknown"
    local manager=""
    local -a lines=()
    local -a words=()

    ez_i._release_key id "$release" "ID" 1
    ez_i._release_key id_like "$release" "ID_LIKE" 1
    ez_i._release_key name "$release" "NAME" 1
    ez_i._release_key version "$release" "VERSION_ID" 1

    if [ -z "$version" ] ; then

        # NOTE: A rolling release carries no VERSION_ID at all. BUILD_ID is
        # what those use instead, and it usually reads "rolling".
        ez_i._release_key version "$release" "BUILD_ID" 1
    fi

    # The family is decided from ID first and ID_LIKE second, which is what
    # the os-release specification is for: a derivative names its parent
    # there, so one case covers every distribution built on it, including
    # the ones that do not exist yet.
    #
    # [Ref(s).: https://www.freedesktop.org/software/systemd/man/os-release.html ]
    local haystack=" $id $id_like "
    case "$haystack" in
        *" rhel "*|*" fedora "*|*" centos "*|*" rocky "*|*" almalinux "*|\
*" ol "*|*" amzn "*|*" scientific "*)
            based="RedHat"
            ;;
        *" debian "*|*" ubuntu "*|*" linuxmint "*|*" pop "*|*" raspbian "*|\
*" devuan "*|*" kali "*)
            based="Debian"
            ;;
        *" sles "*|*" sled "*|*" suse "*|*" opensuse "*)
            based="Suse"
            ;;
        *" arch "*|*" manjaro "*|*" cachyos "*|*" endeavouros "*|\
*" garuda "*|*" artix "*)
            based="Arch"
            ;;
        *" alpine "*)
            based="Alpine"
            ;;
        *" gentoo "*)
            based="Gentoo"
            ;;
        *" void "*)
            based="Void"
            ;;
        *" nixos "*)
            based="NixOS"
            ;;
    esac

    if [ "$based" == "Unknown" ] && [ -n "$id" ] ; then

        # NOTE: An ID this does not know is still worth reporting; only the
        # family is unknown. An openSUSE style "opensuse-leap" is caught
        # here too, since ID_LIKE carries "opensuse" and the case above
        # matched on the whole word.
        case "$id" in
            opensuse*) based="Suse" ;;
        esac
    fi

    if [ "$based" == "Unknown" ] ; then

        # The generations that predate os-release describe themselves in a
        # sentence on the second line, "CentOS release 6.10 (Final)".
        case "$release" in
            *"CentOS release"*)
                ez_i.split lines "$release" $'\n'
                ez_i.split words "${lines[1]}" " "
                name="${words[0]}"
                version="${words[2]}"
                based="RedHat"
                ;;
            *"Red Hat Enterprise Linux Server release "*)
                ez_i.split lines "$release" $'\n'
                ez_i.split words "${lines[1]}" " "
                name="Red Hat Enterprise Linux Server"
                version="${words[6]}"
                based="RedHat"
                ;;
        esac
    fi

    case "$based" in
        RedHat)
            # NOTE: "dnf" replaced "yum" across the family; the old name is
            # still there as a link on some of them, so the new one is
            # preferred and the old one is the fallback.
            if command -v dnf > /dev/null 2>&1 ; then
                manager="dnf"
            else
                manager="yum"
            fi
            ;;
        Debian) manager="apt-get" ;;
        Suse)   manager="zypper" ;;
        Arch)   manager="pacman" ;;
        Alpine) manager="apk" ;;
    esac

    # NOTE: A key the release file does not carry comes back empty, and an
    # empty field reads as a bug rather than as "not stated".
    [ -z "$name" ] && name="Unknown"
    [ -z "$version" ] && version="Unknown"
    [ -z "$id" ] && id="Unknown"

    # NOTE: "uname -m" rather than "arch": the latter is a separate binary
    # that several distributions no longer ship.
    local -A about=(
        [id]="$id"
        [name]="$name"
        [version]="$version"
        [based]="$based"
        [package_manager]="$manager"
        [arch]="$(uname -m)"
    )
    ez_i._emit_assoc "$1" about
}

function ez_i.about_distro() {
    : 'Report what distribution this is.

    ARGUMENTS
        $1 - string, required. The NAME of an ASSOCIATIVE array to receive
             the result. Declare it "-A" first; it is emptied here. The keys
             written are:
                 [id] ............... the os-release ID, "ubuntu", "rocky"
                 [name] ............. the full name it calls itself
                 [version] .......... VERSION_ID, or BUILD_ID when rolling
                 [based] ............ the family: RedHat, Debian, Suse,
                                      Arch, Alpine, Gentoo, Void, NixOS or
                                      Unknown
                 [package_manager] .. what "ez_i.package_installed" wants,
                                      empty when the family has none known
                 [arch] ............. "uname -m"

    RETURNS
        0 on success, 1 when the target is empty.

    The family comes from the os-release ID and ID_LIKE, so a derivative is
    recognised through the parent it names - Linux Mint reports Debian,
    Rocky reports RedHat, CachyOS reports Arch - including derivatives that
    did not exist when this was written.

    EXAMPLE
        declare -A DISTRO=()
        ez_i.about_distro DISTRO
        ez_i.package_installed "" "git" "${DISTRO[package_manager]}" \
            || ez_i.fail_exit "Install git first!"
    '

    if [ -z "$1" ] ; then
        echo "ERROR! A target associative array name is required." >&2
        return 1
    fi

    local release=""
    local -A command_result=()

    # NOTE: The specification puts os-release in "/etc" and allows a vendor
    # copy in "/usr/lib". The "*-release" glob at the end is for the
    # generations that predate it entirely.
    if [ -r /etc/os-release ] ; then
        release=$(< /etc/os-release)
    elif [ -r /usr/lib/os-release ] ; then
        release=$(< /usr/lib/os-release)
    else
        ez_i.run command_result "cat /etc/*-release"
        release="${command_result[stdout]}"
    fi

    ez_i._classify_release "$1" "$release"
}

# <<<<<< THE DISTRIBUTION

# DISTRIBUTION SUBSCRIPTION >>>>>>

function ez_i.check_distro_status() {
    : 'Check that a distribution is subscribed, registered and active for the
    resources given.

    ARGUMENTS
        $1 - string, required. Target variable NAME receiving the raw output
             of the command used to check, or "-" for stdout.
        $2 - string, required. "RedHat" or "SLES". Anything else does
             nothing and succeeds.
        $3 - string, required. The NAME of an INDEXED array holding the
             resources to look for.

    RETURNS
        0 on success, 1 when a name is empty.

    SIDE EFFECTS
        Shows the user ONE warning listing everything that is missing, and
        asks whether to carry on, rather than failing on the first problem.

    IMPORTANT: Only RedHat and SLES are implemented, and neither can be
    exercised on any other distribution, so this is the one part of the
    library its test suite cannot reach.
    '

    if [ -z "$3" ] ; then
        echo "ERROR! A resources array name is required." >&2
        return 1
    fi

    # NOTE: Bound and copied FIRST, while no local of this function exists
    # yet to shadow the name the caller gave. See "ez_i/bootstrap.bash",
    # RECEIVING AN ARRAY.
    local -n _ez_i_src_ref="$3"
    local -a resources=("${_ez_i_src_ref[@]}")
    unset -n _ez_i_src_ref

    local target=$1
    local distro=$2

    local -A result=()
    local -a entries=()
    local -a lines=()
    local -a fields=()
    local -a found=()
    local -a missing=()
    local command=""
    local output=""
    local active=0
    local in_provides=0
    local i=0
    local j=0
    local k=0
    local warning=""
    local separator=""
    local seen=0

    if [ "$distro" == "RedHat" ] ; then
        command="subscription-manager list --consumed"
        ez_i.run result "$command"
        output="${result[stdout]}"

        if [[ $output == *"No consumed subscription pools to list"* ]] ; then
            ez_i.run result "yum repolist"
            output="${result[stdout]}"

            if [[ $output == *"RHN Classic or Red Hat Satellite"* ]] ; then
                ez_i._emit "$target" "$output"
                ez_i.warning "THE REDHAT IS APPARENTLY USING \"RHN Classic\" OR \"Red Hat Satellite\" TO ACCESS ITS RESOURCES!
THIS LIBRARY WILL NOT VALIDATE THESE RESOURCES!

FOR MORE INFORMATION TRY: \"yum repolist\"." 1
                return 0
            fi
        else
            ez_i.split entries "$output" "Subscription Name:"
        fi
    elif [ "$distro" == "SLES" ] ; then
        command="zypper sl"
        ez_i.run result "$command"
        output="${result[stdout]}"
        ez_i.split entries "$output" $'\n'
    else
        ez_i._emit "$target" ""
        return 0
    fi
    ez_i._emit "$target" "$output"

    for ((i = 0; i < ${#entries[@]}; i++)) ; do
        if [ "$distro" == "RedHat" ] ; then
            ez_i.split lines "${entries[$i]}" $'\n'
            in_provides=0
            for ((j = 0; j < ${#lines[@]}; j++)) ; do
                if [[ "${lines[$j]}" == "Provides:"* ]] ; then
                    in_provides=1
                fi
                ((in_provides == 0)) && continue
                for ((k = 0; k < ${#resources[@]}; k++)) ; do
                    if [[ "${lines[$j]}" == *"${resources[$k]}" ]] ; then
                        found+=("$k")
                        break
                    fi
                done
                if ((active == 0)) \
                    && [[ "${lines[$j]}" == "Active:"* ]] \
                    && [[ "${lines[$j]}" == *"True" ]] ; then
                    active=1
                fi
            done
        else
            active=1
            ez_i.split fields "${entries[$i]}" "|"
            for ((k = 0; k < ${#resources[@]}; k++)) ; do
                if [[ "${fields[1]}" == *"${resources[$k]}"* ]] \
                    && [[ "${fields[3]}" == *"Yes"* ]] \
                    && [[ "${fields[5]}" == *"Yes"* ]] ; then
                    found+=("$k")
                    break
                fi
            done
        fi
    done

    for ((k = 0; k < ${#resources[@]}; k++)) ; do
        seen=0
        for ((j = 0; j < ${#found[@]}; j++)) ; do
            if ((found[j] == k)) ; then
                seen=1
                break
            fi
        done
        ((seen == 0)) && missing+=(
            "$distro does not have access to this resource: \"${resources[$k]}\"."
        )
    done

    # NOTE: Specific to SLES. Not the prettiest way of asking, but it works.
    if [ "$distro" == "SLES" ] ; then
        command=""
        ez_i.run result "zypper --non-interactive se hfsdfsdufnmfdns"
        ez_i.split lines "${result[stderr]}" $'\n'
        if [[ "${lines[0]}" == *"Permission to access "* ]] \
            && [[ "${lines[0]}" == *" denied."* ]] ; then
            missing+=("${lines[0]}")
        fi
    fi

    if [ ${#missing[@]} -eq 0 ] && ((active == 1)) ; then
        return 0
    fi

    warning="SOME PROBLEM APPEAR TO HAVE BEEN DETECTED ON"
    if [ "$distro" == "RedHat" ] ; then
        warning+=" REDHAT SUBSCRIPTION! "
    else
        warning+=" SLES REGISTRATION! "
    fi
    warning+="PLEASE CHECK IT!"
    for ((k = 0; k < ${#missing[@]}; k++)) ; do
        if ((k == 0)) ; then
            warning+=$'\n\n'
            separator=""
        else
            separator=$'\n'
        fi
        warning+="$separator -> ${missing[$k]}"
    done
    if [ -n "$command" ] ; then
        warning+=$'\n\n'"FOR MORE INFORMATION TRY: \"$command\"."
    fi
    ez_i.warning "$warning" 1
}

# <<<<<< DISTRIBUTION SUBSCRIPTION
