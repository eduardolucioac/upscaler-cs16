#!/bin/bash
#
# ez_i.bash - Interactive BASH scripts without the boilerplate.
#
# Version 2.0.0b
#
# PURPOSE
#
# A script that talks to a person needs the same dozen things every time: ask
# a question and refuse an empty answer, page a licence that is longer than
# the terminal, show that something long is still running and say how long is
# left, run a command and look at its stderr, write a log, back a folder up
# before touching it, and exit with a message that explains itself.
#
# None of that is hard. All of it is tedious, and all of it is where the bugs
# that only show up on somebody else's machine come from. This library is that
# dozen things, written once.
#
#     source "/path/to/ez_i.bash"
#
#     ez_i.start "My Installer" "1.0.0" "$ABOUT" "$WARNINGS" "$COMPANY"
#     ez_i.terms "$LICENCE"
#
#     ez_i.exists "" "d" "$TARGET_DIRECTORY" || ez_i.error_exit "No target!"
#
#     declare -A RESULT=()
#     ez_i.run RESULT "tar -xzf package.tar.gz" || ez_i.error_exit "${RESULT[stderr]}"
#
#     ez_i.end "Done! Thanks!" "$USEFUL_INFORMATION"
#
# HOW VALUES COME BACK
#
# Nothing is returned through a global. Where a function has something to
# give back, the FIRST argument is the NAME of the variable that receives it,
# the way "json_like.set_obj MY_OBJ" works. There are three shapes.
#
#     A VALUE
#
#     The target is required, and what comes back follows how it was
#     declared, so one function covers the single value and the whole set.
#
#         declare TRIMMED
#         ez_i.trim TRIMMED "  padded  " 2
#
#         declare -a PARTS=()
#         ez_i.split PARTS "a,b,c" ","
#
#         ez_i.trim - "  padded  " 2        # "-" prints it instead
#
#     A YES OR NO
#
#     Pass "" as the target and the EXIT STATUS is the answer, 0 for true,
#     the way "test" and "grep -q" behave:
#
#         if ez_i.exists "" "f" "$MY_FILE" ; then ...
#         ez_i.is_root "" || ez_i.error_exit "You need to be root!"
#
#     Pass a NAME instead and the answer goes there as 1 for true, 0 for
#     false, and the exit status then only reports whether the check could be
#     made at all. That form is safe under "set -e":
#
#         declare IS_THERE
#         ez_i.exists IS_THERE "f" "$MY_FILE"
#         if [ "$IS_THERE" -eq 1 ] ; then ...
#
#     IMPORTANT: The two forms read OPPOSITE WAYS ROUND, and deliberately. "0"
#     from a command means success; "0" in a variable means false. Each half
#     follows the convention of where it lives.
#
#     NOTHING
#
#     Functions that only draw, log or exit take no target at all:
#
#         ez_i.divider
#         ez_i.log "" "Started." "o"
#
# PUBLIC API
#
#     RUNNING THINGS
#     ez_i.run <assoc_name> <command>
#     ez_i.trap_add <command> <signal>...
#
#     ASKING
#     ez_i.read <var_name>|- <prompt> [is_password] [timeout] [when_unanswered]
#     ez_i.ask <var_name>|- <question> [allow_empty] [is_password]
#     ez_i.ask_option <var_name> <desc_name> <question> <options_name> [allow_empty]
#     ez_i.ask_yes_no <var_name>|"" <question> [timeout] [when_unanswered]
#     ez_i.ask_continue [note]
#     ez_i.enter_to_continue [information] [timeout]
#
#     TELLING
#     ez_i.start [var_name]|"" <title> <version> <about> <warnings> <company>
#     ez_i.end <title> <useful_information>
#     ez_i.terms <terms>
#     ez_i.instructions [var_name]|"" <instructions>
#     ez_i.warning <message> [ask_continue]
#     ez_i.okay_exit [cause]
#     ez_i.error_exit [detail]
#     ez_i.print_long [var_name]|"" <text>
#     ez_i.indent <2|4|8>
#     ez_i.divider
#     ez_i.open_section [title] / ez_i.close_section
#     ez_i.open_main_section [title] / ez_i.close_main_section
#     ez_i.sub_section <title> <text>
#
#     SHOWING PROGRESS
#     ez_i.progress <a|o> [description]
#     ez_i.progress_draw <label> <item> <stats>
#     ez_i.progress_wait <pid> <label> <item> <stats>
#     ez_i.progress_clear
#     ez_i.task_stats_init <assoc_name> <length> [increment] [start_at]
#     ez_i.task_stats_begin <assoc_name>
#     ez_i.task_stats_end <var_name>|- <assoc_name>
#     ez_i.task_stats_skip <var_name>|- <assoc_name>
#
#     STRINGS
#     ez_i.trim <var_name>|- <string> [mode]
#     ez_i.reverse <var_name>|- <string>
#     ez_i.split <array_name> <string> [delimiter]
#     ez_i.sed_escape <var_name>|- <value> <0|1>
#     ez_i.sed_str <var_name>|- <source> <pattern> <replacement> [nth]
#     ez_i.sed_file <file> <pattern> <replacement> [nth]
#
#     NUMBERS
#     ez_i.format_time <var_name>|- <milliseconds>
#     ez_i.percent_of <var_name>|- <value> <percent> [rounding]
#     ez_i.convert_bytes <var_name>|- <value> <from_unit> <to_unit>
#     ez_i.uuid <var_name>|- [no_dashes]
#
#     FILES AND FOLDERS
#     ez_i.exists <var_name>|"" <f|d> <path>
#     ez_i.file_contains <var_name>|"" <file> <string> [invert]
#     ez_i.delete_if_empty <var_name>|"" <folder> [ignore_hidden]
#     ez_i.array_to_file <file> <array_name>
#     ez_i.file_to_array <array_name> <file>
#     ez_i.backup <assoc_name>|"" <path> [copy] [name_only]
#
#     LOGGING
#     ez_i.log <var_name>|"" <message> [type] [mode] [folder] [on_screen]
#
#     THE MACHINE
#     ez_i.is_root <var_name>|""
#     ez_i.is_running <var_name>|"" <process_name>
#     ez_i.package_installed <var_name>|"" <package> <manager>
#     ez_i.iptables_rule <var_name>|"" <port> [target] [protocol] [state] [position]
#     ez_i.about_distro <assoc_name>
#     ez_i.check_distro_status <var_name>|- <distribution> <resources_name>
#     ez_i.total_memory <var_name>|-
#     ez_i.cpu_count <var_name>|- [multiplier]
#
# RUNNING WITHOUT A PERSON
#
# Set EZ_I_SKIP_ON to 1 and everything that would ask a question or draw on
# the terminal becomes a no op, so the same script runs unattended. The
# functions that compute something still do.
#
#     EZ_I_SKIP_ON=1
#     source "/path/to/ez_i.bash"
#
# NAMES
#
# Everything this library defines is either "ez_i.<something>", a public
# function, "ez_i._<something>", a private one, or "_EZ_I_<SOMETHING>", its
# own state. The one exception is EZ_I_SKIP_ON, which is public on purpose
# because a script sets it. Nothing else reaches the scope of the script that
# sources this file.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
# Brazil-DF
# https://www.linkedin.com/in/eduardo-software-livre/
#

# Namerefs are only available from BASH 4.3 onwards and this library is built
# around them.
if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 3))); then
    echo "ERROR! \"ez_i.bash\" requires BASH version 4.3 or higher." >&2
    return 1 2> /dev/null || exit 1
fi

# LIBRARY LOADING >>>>>>

# The library is split into parts under "ez_i/". This file is the entry point
# and the only one to source; the parts rely on each other and on the order
# they are loaded in, so none of them stands on its own.
#
# The order is fixed and spelled out below rather than looped over: there are
# ten of them, they are known, and a list in a variable would only hide which
# one failed.

declare _EZ_I_ROOT
_EZ_I_ROOT="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd )"

# shellcheck source=ez_i/bootstrap.bash
source "$_EZ_I_ROOT/ez_i/bootstrap.bash" || return 1 2> /dev/null || exit 1

# shellcheck source=ez_i/strings.bash
source "$_EZ_I_ROOT/ez_i/strings.bash" || return 1 2> /dev/null || exit 1

# shellcheck source=ez_i/numbers.bash
source "$_EZ_I_ROOT/ez_i/numbers.bash" || return 1 2> /dev/null || exit 1

# shellcheck source=ez_i/terminal.bash
source "$_EZ_I_ROOT/ez_i/terminal.bash" || return 1 2> /dev/null || exit 1

# shellcheck source=ez_i/progress.bash
source "$_EZ_I_ROOT/ez_i/progress.bash" || return 1 2> /dev/null || exit 1

# shellcheck source=ez_i/system.bash
source "$_EZ_I_ROOT/ez_i/system.bash" || return 1 2> /dev/null || exit 1

# shellcheck source=ez_i/files.bash
source "$_EZ_I_ROOT/ez_i/files.bash" || return 1 2> /dev/null || exit 1

# shellcheck source=ez_i/logging.bash
source "$_EZ_I_ROOT/ez_i/logging.bash" || return 1 2> /dev/null || exit 1

# shellcheck source=ez_i/prompt.bash
source "$_EZ_I_ROOT/ez_i/prompt.bash" || return 1 2> /dev/null || exit 1

# shellcheck source=ez_i/presentation.bash
source "$_EZ_I_ROOT/ez_i/presentation.bash" || return 1 2> /dev/null || exit 1

# <<<<<< LIBRARY LOADING

# Read the locals of every function now that they all exist. This is what
# lets a function return a value into a variable the caller named even when
# that name happens to match one of the library own locals. See
# "ez_i/bootstrap.bash", HANDING A VALUE BACK.
ez_i._scan_locals || return 1 2> /dev/null || exit 1

# Keeps the "ez_i.progress" animation from being left running by an
# unexpected error or any other way out.
ez_i.trap_add "ez_i.progress \"o\"" SIGINT SIGTERM ERR EXIT

# And the same for the in place rows, which hide the cursor while they draw.
# "ez_i.progress_clear" does nothing when nothing was drawn, so this costs
# nothing on a script that never uses it.
ez_i.trap_add "ez_i.progress_clear" SIGINT SIGTERM ERR EXIT
