#!/bin/bash
#
# test/system.bash - running commands, the machine and the distribution
#
# Part of the "ez_i" test suite. Sourced by "test/test.bash", never on its
# own: it relies on the harness.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

t_group "ez_i.run"

declare -A T_RESULT=()
ez_i.run T_RESULT "echo out"
t_equals "captures stdout"    "out" "${T_RESULT[stdout]}"
t_equals "stderr stays empty" ""    "${T_RESULT[stderr]}"
t_equals "status is zero"     "0"   "${T_RESULT[status]}"

ez_i.run T_RESULT "echo err >&2"
t_equals "captures stderr"    "err" "${T_RESULT[stderr]}"
t_equals "stdout stays empty" ""    "${T_RESULT[stdout]}"

ez_i.run T_RESULT "echo o; echo e >&2"
t_equals "[both] joins the two streams" "o
e" "${T_RESULT[both]}"

ez_i.run T_RESULT "bash -c 'exit 3'"
t_equals "captures a non zero status" "3" "${T_RESULT[status]}"

ez_i.run T_RESULT "false"
t_equals "captures a failing builtin" "1" "${T_RESULT[status]}"

# The exit status of the function IS the exit status of the command, so the
# usual "|| handle it" works without looking at the array at all.
if ez_i.run T_RESULT "true" ; then
    t_report 0 "returns 0 when the command succeeds"
else
    t_report 1 "returns 0 when the command succeeds"
fi
if ez_i.run T_RESULT "false" ; then
    t_report 1 "returns non zero when the command fails"
else
    t_report 0 "returns non zero when the command fails"
fi

ez_i.run T_RESULT "echo first"
ez_i.run T_RESULT "true"
t_equals "a later run clears the earlier stdout" "" "${T_RESULT[stdout]}"

# NOTE: These are implementation details that used to leak out of the
# function and collide with the variables of whatever called it.
t_equals "does not leak \"t_std\"" "" "${t_std+leaked}"
t_equals "does not leak \"t_err\"" "" "${t_err+leaked}"
t_equals "does not leak \"t_ret\"" "" "${t_ret+leaked}"

t_fails "an empty target fails" ez_i.run "" "true"

t_group "ez_i.is_root"

declare T_ROOT
ez_i.is_root T_ROOT
if [[ $EUID -eq 0 ]] ; then
    t_equals "reports root correctly" "1" "$T_ROOT"
    t_succeeds "status form agrees"   ez_i.is_root ""
else
    t_equals "reports not root correctly" "0" "$T_ROOT"
    t_fails "status form agrees"          ez_i.is_root ""
fi

t_group "ez_i.is_running"

# NOTE: This very shell is running, so it is the one process that is certain
# to be there whatever the machine is doing.
t_succeeds "finds a process that is running" ez_i.is_running "" "bash"
t_fails "misses one that is not" \
    ez_i.is_running "" "no_such_process_fcb27a41"

declare T_RUNNING
ez_i.is_running T_RUNNING "no_such_process_fcb27a41"
t_equals "variable form says 0 when absent" "0" "$T_RUNNING"

t_group "ez_i.total_memory"

declare T_MEMORY
ez_i.total_memory T_MEMORY
t_equals "matches /proc/meminfo" \
    "$(awk '/^MemTotal:/ {print $2; exit}' /proc/meminfo)" "$T_MEMORY"

t_group "ez_i.cpu_count"

declare T_CPUS
ez_i.cpu_count T_CPUS
if [ "$T_CPUS" -ge 1 ] 2> /dev/null ; then
    t_report 0 "reports at least one processor"
else
    t_report 1 "reports at least one processor" "got [$T_CPUS]"
fi
declare T_CPUS_X2
ez_i.cpu_count T_CPUS_X2 2
t_equals "applies the multiplier" "$((T_CPUS * 2))" "$T_CPUS_X2"

t_group "ez_i._release_key"

declare T_DEBIAN='NAME="Debian GNU/Linux"
VERSION_ID="11"
ID=debian'
declare T_KEY
ez_i._release_key T_KEY "$T_DEBIAN" "NAME" 1
t_equals "reads a quoted NAME" "Debian GNU/Linux" "$T_KEY"
ez_i._release_key T_KEY "$T_DEBIAN" "VERSION_ID" 1
t_equals "reads a quoted VERSION_ID" "11" "$T_KEY"

declare T_UBUNTU='DISTRIB_ID=Ubuntu
DISTRIB_RELEASE=22.04'
ez_i._release_key T_KEY "$T_UBUNTU" "DISTRIB_ID" 0
t_equals "reads an unquoted key" "Ubuntu" "$T_KEY"
ez_i._release_key T_KEY "$T_UBUNTU" "DISTRIB_RELEASE" 1
t_equals "unquoting an unquoted value is harmless" "22.04" "$T_KEY"

declare T_SUSE='NAME=openSUSE Leap
VERSION_ID="15.4"'
ez_i._release_key T_KEY "$T_SUSE" "NAME" 0
t_equals "reads a bare NAME holding a space" "openSUSE Leap" "$T_KEY"

ez_i._release_key T_KEY "$T_DEBIAN" "NOT_THERE" 1
t_equals "a missing key gives an empty value" "" "$T_KEY"

t_group "ez_i.about_distro"

declare -A T_DISTRO=()
ez_i.about_distro T_DISTRO
t_equals "the architecture is reported" "$(uname -m)" "${T_DISTRO[arch]}"
if [ -n "${T_DISTRO[name]}" ] && [ -n "${T_DISTRO[version]}" ] \
    && [ -n "${T_DISTRO[based]}" ] ; then
    t_report 0 "no field comes back empty"
else
    t_report 1 "no field comes back empty" \
        "got [${T_DISTRO[name]}|${T_DISTRO[version]}|${T_DISTRO[based]}]"
fi

# NOTE: The quotes of a quoted NAME must not survive into the result.
case "${T_DISTRO[name]}" in
    *'"'*) t_report 1 "the name carries no quotes" "got [${T_DISTRO[name]}]" ;;
    *)     t_report 0 "the name carries no quotes" ;;
esac

t_fails "an empty target fails" ez_i.about_distro ""

t_group "ez_i._classify_release"

# The family comes from the os-release ID and ID_LIKE, so a derivative is
# recognised through the parent it names. These are the real contents of
# each file, trimmed to the keys that matter.
function t_distro() {
    local test_name="$1"
    local release="$2"
    local expected_based="$3"
    local expected_manager="$4"
    local expected_version="$5"
    local -A got=()
    ez_i._classify_release got "$release"
    t_equals "$test_name is $expected_based" "$expected_based" "${got[based]}"
    if [ -n "$expected_manager" ] ; then
        t_equals "$test_name uses $expected_manager" \
            "$expected_manager" "${got[package_manager]}"
    fi
    if [ -n "$expected_version" ] ; then
        t_equals "$test_name reports version $expected_version" \
            "$expected_version" "${got[version]}"
    fi
}

# NOTE: "dnf" replaced "yum", and which one is reported depends on what is
# installed HERE, so the RedHat family is checked without naming one.
declare T_RPM_MANAGER="yum"
command -v dnf > /dev/null 2>&1 && T_RPM_MANAGER="dnf"

t_distro "Fedora"       'NAME="Fedora Linux"
ID=fedora
VERSION_ID=39'                                  "RedHat" "$T_RPM_MANAGER" "39"
t_distro "RHEL"         'ID="rhel"
ID_LIKE="fedora"
VERSION_ID="9.3"'                               "RedHat" "" "9.3"
t_distro "Rocky"        'ID="rocky"
ID_LIKE="rhel centos fedora"'                   "RedHat" "" ""
t_distro "AlmaLinux"    'ID="almalinux"
ID_LIKE="rhel centos fedora"'                   "RedHat" "" ""
t_distro "Amazon Linux" 'ID="amzn"
ID_LIKE="fedora"'                               "RedHat" "" ""
t_distro "Oracle Linux" 'ID="ol"
ID_LIKE="fedora"'                               "RedHat" "" ""
t_distro "Debian"       'ID=debian
VERSION_ID="12"'                                "Debian" "apt-get" "12"
t_distro "Ubuntu"       'ID=ubuntu
ID_LIKE=debian
VERSION_ID="22.04"'                             "Debian" "apt-get" "22.04"
t_distro "Linux Mint"   'ID=linuxmint
ID_LIKE="ubuntu debian"'                        "Debian" "apt-get" ""
t_distro "Raspbian"     'ID=raspbian
ID_LIKE=debian'                                 "Debian" "apt-get" ""
t_distro "SLES"         'ID="sles"
VERSION_ID="15.5"'                              "Suse" "zypper" "15.5"
t_distro "openSUSE Leap" 'ID="opensuse-leap"
ID_LIKE="suse opensuse"'                        "Suse" "zypper" ""
t_distro "Arch"         'ID=arch
BUILD_ID=rolling'                               "Arch" "pacman" "rolling"
t_distro "Manjaro"      'ID=manjaro
ID_LIKE=arch'                                   "Arch" "pacman" ""
t_distro "Alpine"       'ID=alpine
VERSION_ID=3.19.0'                              "Alpine" "apk" "3.19.0"
t_distro "Gentoo"       'ID=gentoo'             "Gentoo" "" ""
t_distro "NixOS"        'ID=nixos'              "NixOS" "" ""

# NOTE: A rolling release carries no VERSION_ID, so BUILD_ID stands in.
t_distro "a rolling release" 'ID=arch
BUILD_ID=rolling'                               "Arch" "" "rolling"

# The generations that predate os-release describe themselves in a sentence.
t_distro "CentOS 6" '
CentOS release 6.10 (Final)
'                                               "RedHat" "" "6.10"
t_distro "RHEL 6" '
Red Hat Enterprise Linux Server release 6.10 (Santiago)
'                                               "RedHat" "" "6.10"

# Something nobody has heard of still reports what it says about itself.
declare -A T_ODD=()
ez_i._classify_release T_ODD 'NAME="Qualquer Coisa"
ID=xpto
VERSION_ID="1.0"'
t_equals "an unknown distribution has no family" "Unknown" "${T_ODD[based]}"
t_equals "but still reports its name"    "Qualquer Coisa" "${T_ODD[name]}"
t_equals "and its version"               "1.0" "${T_ODD[version]}"
t_equals "and its id"                    "xpto" "${T_ODD[id]}"
t_equals "and has no package manager"    "" "${T_ODD[package_manager]}"

declare -A T_NO_RELEASE=()
ez_i._classify_release T_NO_RELEASE ""
t_equals "an empty release file is Unknown" "Unknown" "${T_NO_RELEASE[based]}"
t_equals "and still reports the architecture" "$(uname -m)" "${T_NO_RELEASE[arch]}"
