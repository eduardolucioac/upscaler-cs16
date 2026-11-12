# ez_i

![ez_i](./images/ez_i.png)

Interactive **BASH** scripts without the boilerplate. Ask a question and
refuse an empty answer, page a licence longer than the terminal, show that
something slow is still running and say how long is left, run a command and
look at its stderr, write a log, back a folder up before touching it, and
exit with a message that explains itself.

```bash
source "./ez_i/ez_i.bash"

ez_i.start "" "My Installer" "1.0.0" "$ABOUT" "$WARNINGS" "$COMPANY"
ez_i.terms "$LICENCE"

ez_i.exists "" "d" "$TARGET" || ez_i.fail_exit "No target folder!"

declare -A RESULT=()
ez_i.run RESULT "tar -xzf package.tar.gz" || ez_i.fail_exit "${RESULT[stderr]}"

ez_i.end "Done! Thanks!" "$USEFUL_INFORMATION"
```

**IMPORTANT:** My life, my work and my passion is free software. Corrections, tweaks and improvements are very welcome (**pull requests** 😉)! Please consider giving us a ⭐, fork, support this project or even visit our professional profile (see [About](#about)). **Thanks!** 🤗

**Support free software and my work!** ❤️🐧

## Table of Contents

- [Layout](#layout)
- [Requirements](#requirements)
- [Installing](#installing)
- [A whole installer](#a-whole-installer)
   * [Opening](#opening)
   * [Knowing where you are](#knowing-where-you-are)
   * [Doing the work](#doing-the-work)
   * [Closing](#closing)
- [How values come back](#how-values-come-back)
   * [A value](#a-value)
   * [A yes or no](#a-yes-or-no)
   * [Nothing](#nothing)
- [API](#api)
   * [Running things](#running-things)
   * [Asking](#asking)
   * [Telling](#telling)
   * [Showing progress](#showing-progress)
   * [Strings](#strings)
   * [Numbers](#numbers)
   * [Files and folders](#files-and-folders)
   * [Logging](#logging)
   * [The machine](#the-machine)
- [Running without a person](#running-without-a-person)
- [Names](#names)
- [How a value reaches your variable](#how-a-value-reaches-your-variable)
   * [The catch, and what is done about it](#the-catch-and-what-is-done-about-it)
   * [What this costs you](#what-this-costs-you)
- [Testing](#testing)
- [Limitations](#limitations)
- [About](#about)

## Layout

```
ez_i/
├── ez_i.bash              # the entry point — the only file to source
├── ez_i/
│   ├── bootstrap.bash         # library state and the return conventions
│   ├── strings.bash           # split, trim, reverse, sed
│   ├── numbers.bash           # time, percentages, byte units, UUIDs
│   ├── terminal.bash          # sections, dividers, paging
│   ├── progress.bash          # the spinner and the task statistics
│   ├── system.bash            # running commands, the machine, the distro
│   ├── files.bash             # files, folders, arrays on disk, backups
│   ├── logging.bash           # output and error logs
│   ├── prompt.bash            # asking the user things
│   └── presentation.bash      # opening, closing, warning, exiting
├── test/
│   └── test.bash          # 334 integrity tests
├── images/
├── LICENSE
└── README.md              # this file
```

---

## Requirements

| Requirement | Why |
|---|---|
| **BASH 4.3+** | the code relies on namerefs (`local -n`) |
| **`awk`** | the floating point arithmetic BASH does not have |
| **`sed`**, **`grep`**, **`find`** | the usual text and file work |
| **`less`** | only for paging text taller than the terminal |

All of them are either POSIX or in the base install everywhere, so a clone
runs where it lands. Nothing is compiled and nothing is downloaded.

## Installing

**Clone the folder into your own project**, next to the script that is going
to use it:

```
my-bash-project/
  my-script.bash
  ez_i/                   <- the whole folder, as it is here
```

```sh
git clone https://github.com/eduardolucioac/ez_i.git
```

Then source the entry point:

```bash
source "./ez_i/ez_i.bash"
```

`ez_i.bash` is the **only** file to source — it finds everything else
relative to itself. A script that may be run from another directory should
resolve the path rather than trust the working one:

```bash
MY_SCRIPT_DIRECTORY="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
source "$MY_SCRIPT_DIRECTORY/ez_i/ez_i.bash" || exit 1
```

## A whole installer

The arc every interactive script has: open with what this is, get the licence
agreed to, check the ground, do the work saying how far along it is, and close
with what the person needs to know. This is the shape of a real installer,
trimmed.

### Opening

```bash
MY_DIRECTORY="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
source "$MY_DIRECTORY/ez_i/ez_i.bash" || exit 1

read -r -d '' TITLE << "HEREDOC"
LBG - LBGenerator Installer
HEREDOC
read -r -d '' VERSION << "HEREDOC"
0.8.0.0
HEREDOC
read -r -d '' WARNINGS << "HEREDOC"
- This installer is compatible with RHEL, SUSE, Debian or distributions
based on these.

- We WARNING you...
    THIS INSTALLER COMES WITH ABSOLUTELY NO WARRANTY! USE AT YOUR OWN RISK!
HEREDOC

ez_i.start "" "$TITLE" "$VERSION" "$ABOUT" "$WARNINGS" "$COMPANY"
ez_i.terms "$(cat "$MY_DIRECTORY/LICENSE.txt")"
ez_i.instructions "" "- TO CANCEL installation at any time use Ctrl+c!"
ez_i.is_root "" || ez_i.fail_exit "You need to be root!"
```

Each of those pages its text when it is taller than the terminal, and
`ez_i.terms` exits by itself when the answer is no.

### Knowing where you are

```bash
declare -A DISTRO=()
ez_i.about_distro DISTRO

ez_i.open_section "DISTRO INFORMATION:"
echo "NAME: .... ${DISTRO[name]}"
echo "VERSION: . ${DISTRO[version]}"
echo "BASED: ... ${DISTRO[based]}"
echo "ARCH: .... ${DISTRO[arch]}"
ez_i.close_section

if [ -z "${DISTRO[package_manager]}" ] ; then
    ez_i.fail_exit "\"${DISTRO[name]}\" is not supported!"
fi
```

The family is read off the os-release `ID` and `ID_LIKE`, so a derivative is
recognised through the parent it names — Linux Mint reports `Debian`, Rocky
reports `RedHat`, CachyOS reports `Arch` — and `[package_manager]` comes back
ready to hand to `ez_i.package_installed`.

### Doing the work

Install what is missing, skip what is already there, say how long is left, and
stop with the real reason when something fails.

```bash
declare -a PACKAGES=("gcc" "make" "libtool")
declare -A TASK=()
ez_i.task_stats_init TASK "${#PACKAGES[@]}"

declare MY_LOG=""
ez_i.log MY_LOG "Installation started." 0 "new" "$MY_DIRECTORY/logs" 1

declare PACKAGE="" STATS=""
declare -A RESULT=()
for PACKAGE in "${PACKAGES[@]}" ; do
    ez_i.task_stats_begin TASK

    if ez_i.package_installed "" "$PACKAGE" "${DISTRO[package_manager]}" ; then
        ez_i.task_stats_skip STATS TASK
        ez_i.log "" " > Already there: $PACKAGE
$STATS" 0 "$MY_LOG" "" 1
        continue
    fi

    ez_i.progress "a" " > Installing \"$PACKAGE\"..."
    ez_i.run RESULT "${DISTRO[package_manager]} -y install \"$PACKAGE\"" || {
        ez_i.progress "o"
        ez_i.log "" "Could not install \"$PACKAGE\"!
${RESULT[stderr]}" 1 "" "$MY_DIRECTORY/logs"
        ez_i.fail_exit "Could not install \"$PACKAGE\"! ${RESULT[stderr]}"
    }
    ez_i.progress "o"

    ez_i.task_stats_end STATS TASK
    ez_i.log "" " > Installed: $PACKAGE
$STATS" 0 "$MY_LOG" "" 1
done
```

What that prints:

```
 > Installed: gcc
ITEMS LEFT 2/3 (33% SO FAR) / TIME LEFT 8ms
 > Installed: make
ITEMS LEFT 1/3 (66% SO FAR) / TIME LEFT 4ms
 > Already there: libtool
ITEMS LEFT 0/3 (100% SO FAR) / TIME LEFT <SKIPPED ITEM>
```

`ez_i.task_stats_skip` is what keeps the no time a skipped item took from
being averaged into the estimate for the ones that still have to run.

And when it fails, the reason is the one the package manager gave:

```
AN ERROR OCCURRED AND THE EXECUTION WAS TERMINATED!
----
Could not install "make"! could not resolve host
----
```

### Closing

```bash
read -r -d '' USEFUL_INFORMATION << HEREDOC
- Start the service with...
    systemctl start lbgenerator

- Your log...
    $MY_LOG
HEREDOC

ez_i.end "$TITLE installed! Thanks!" "$USEFUL_INFORMATION"
```

**TIP:** The whole thing runs unattended with `EZ_I_SKIP_ON=1` before the
`source`. Every page and every question becomes a no op, the package work
still happens and the log is still written. See
[Running without a person](#running-without-a-person).

## How values come back

Nothing is returned through a global. Where a function has something to give
back, the **first argument is the NAME of the variable** that receives it,
the way `json_like.set_obj MY_OBJ` works. There are three shapes.

### A value

The target is required, and what comes back follows how it was declared, so
one function covers the single value and the whole set:

```bash
declare TRIMMED
ez_i.trim TRIMMED "  padded  " 2

declare -a PARTS=()
ez_i.split PARTS "a,b,c" ","

declare -A RESULT=()
ez_i.run RESULT "ls -la"
```

`-` prints it to stdout instead, with no trailing newline:

```bash
ez_i.trim - "  padded  " 2
```

### A yes or no

Pass `""` as the target and the **exit status is the answer, 0 for true**,
the way `test` and `grep -q` behave:

```bash
if ez_i.exists "" "f" "$MY_FILE" ; then ... ; fi

ez_i.is_root "" || ez_i.fail_exit "You need to be root!"
ez_i.file_contains "" "$CONFIG" "needle" || exit 1
```

Pass a **name** instead and the answer goes there as **1 for true**, 0 for
false, and the exit status then only reports whether the check could be made
at all. That form is safe under `set -e`:

```bash
declare IS_THERE
ez_i.exists IS_THERE "f" "$MY_FILE"
if [ "$IS_THERE" -eq 1 ] ; then ... ; fi
```

**IMPORTANT:** The two forms read **opposite ways round**, and deliberately.
`0` from a command means success; `0` in a variable means false. Each half
follows the convention of where it lives.

### Nothing

Functions that only draw, log or exit take no target at all:

```bash
ez_i.divider
ez_i.log "" "Started." 0 "" "$PWD/logs" 1
ez_i.okay_exit "Canceled by user."
```

---

## API

Every function returns **0** on success and **1** on failure, writing the
reason to **stderr**. Nothing reaches stdout unless you ask with `-`.

### Running things

| Function | Does |
|---|---|
| `ez_i.run <assoc_name> <command>` | run a command, filling `[stdout]`, `[stderr]`, `[both]` and `[status]`; returns the command's own exit code |
| `ez_i.trap_add <command> <signal>...` | add to a trap **keeping** whatever was already on it |

### Asking

| Function | Does |
|---|---|
| `ez_i.read <var>\|- <prompt> [is_password] [timeout] [when_unanswered]` | read one line |
| `ez_i.ask <var>\|- <question> [allow_empty] [is_password]` | ask, and ask again on an empty answer |
| `ez_i.ask_option <var> <desc_var>\|"" <question> <options_name> [allow_empty]` | pick one of a list |
| `ez_i.ask_yes_no <var>\|"" <question> [timeout] [when_unanswered]` | yes or no |
| `ez_i.ask_continue [note]` | carry on, or **exit** |
| `ez_i.enter_to_continue [information] [timeout]` | wait for enter |

### Telling

| Function | Does |
|---|---|
| `ez_i.start <var>\|"" <title> <version> <about> <warnings> <company>` | the opening screen |
| `ez_i.end <title> <useful_information>` | the closing screen |
| `ez_i.terms <terms>` | the licence, and get it agreed to |
| `ez_i.instructions <var>\|"" <instructions>` | an instructions screen |
| `ez_i.notify <kind> <message> [1\|0\|-1] [sound]` | a message in a box: ask, wait, or neither |
| `ez_i.success` / `ez_i.warning` / `ez_i.error` | the same, kind already filled in |
| `ez_i.sound <success\|warning\|error>` | a sound, and nothing else |
| `ez_i.okay_exit [cause]` | say why and **exit 0** |
| `ez_i.fail_exit [detail]` | say what went wrong and **exit 1** |
| `ez_i.print_long <var>\|"" <text>` | print, paging when taller than the terminal |
| `ez_i.indent <2\|4\|8>` | indent what is piped through it |
| `ez_i.divider` | a divider |
| `ez_i.open_section [title]` / `ez_i.close_section` | a section |
| `ez_i.open_main_section [title]` / `ez_i.close_main_section` | a group of sections |
| `ez_i.sub_section <title> <text>` | a subsection |

### Showing progress

| Function | Does |
|---|---|
| `ez_i.progress <a\|o> [description]` | start or stop the spinner |
| `ez_i.task_stats_init <assoc_name> <length> [increment] [start_at]` | set a loop's counters up |
| `ez_i.task_stats_begin <assoc_name>` | mark the start of one iteration |
| `ez_i.task_stats_end <var>\|- <assoc_name>` | end it, and describe where the loop got to |
| `ez_i.task_stats_skip <var>\|- <assoc_name>` | same, for an item that needed no work |

The state of a loop lives in an associative array **you** declare, which is
what lets two nested loops each keep their own count:

```bash
declare -A TASK=()
ez_i.task_stats_init TASK 500
# ITEMS LEFT 499/500 (0% SO FAR) / TIME LEFT 8m 20s
```

### Strings

| Function | Does |
|---|---|
| `ez_i.trim <var>\|- <string> [mode]` | strip whitespace: 0 leading, 1 trailing, 2 both |
| `ez_i.reverse <var>\|- <string>` | reverse, lines and characters alike |
| `ez_i.split <array_name> <string> [delimiter]` | split into an array |
| `ez_i.sed_escape <var>\|- <value> <0\|1>` | escape for the pattern (0) or replacement (1) side |
| `ez_i.sed_str <var>\|- <source> <pattern> <replacement> [nth]` | replace in a string |
| `ez_i.sed_file <file> <pattern> <replacement> [nth]` | replace in a file, in place |

Both `sed` functions match **literally** and escape both sides for you, so a
dot, a slash or an ampersand is just that character. `nth` is `1~n` for the
nth match, `0` for every one, `-1` for the last and below that for the nth
from the end.

**IMPORTANT:** `"\n"` between double quotes is a backslash followed by an
`n`, **not** a line break. Pass `$'\n'` to split into lines.

### Numbers

| Function | Does |
|---|---|
| `ez_i.format_time <var>\|- <milliseconds>` | "1d 23h 27m 16s", or "520ms" |
| `ez_i.percent_of <var>\|- <value> <percent> [rounding]` | a percentage of a value |
| `ez_i.convert_bytes <var>\|- <value> <from> <to>` | between B, KB, MB, GB, TB and PB |
| `ez_i.uuid <var>\|- [no_dashes]` | a UUID |

### Files and folders

| Function | Does |
|---|---|
| `ez_i.exists <var>\|"" <f\|d> <path>` | is it there, and of that kind |
| `ez_i.file_contains <var>\|"" <file> <string> [invert]` | does a file hold a string, matched literally |
| `ez_i.delete_if_empty <var>\|"" <folder> [ignore_hidden]` | delete a folder, only if empty |
| `ez_i.array_to_file <file> <array_name>` | write an array, one element per line |
| `ez_i.file_to_array <array_name> <file>` | read it back |
| `ez_i.backup <assoc_name>\|"" <path> [copy] [name_only]` | move or copy aside, timestamped |

### Logging

| Function | Does |
|---|---|
| `ez_i.log <var>\|"" <message> [kind] [mode] [folder] [on_screen]` | write one entry |
| `ez_i.clean_old_logs <folder> <keep>` | delete all but the most recent |

Keep what the first call gives back and pass it as `mode` from then on, which
is how every later entry reaches the same file:

```bash
declare MY_LOG
ez_i.log MY_LOG "Started." 0 "new" "$PWD/logs" 1
ez_i.log "" "Step one done." 0 "$MY_LOG" "" 1
```

### The machine

| Function | Does |
|---|---|
| `ez_i.is_root <var>\|""` | running as root |
| `ez_i.is_running <var>\|"" <process>` | is a process running |
| `ez_i.package_installed <var>\|"" <package> <manager>` | `dnf`, `yum`, `apt-get`, `zypper`, `pacman` or `apk` |
| `ez_i.iptables_rule <var>\|"" <port> [target] [protocol] [state] [position]` | is a rule there |
| `ez_i.about_distro <assoc_name>` | `[id]`, `[name]`, `[version]`, `[based]`, `[package_manager]`, `[arch]` |
| `ez_i.check_distro_status <var>\|- <distribution> <resources_name>` | RedHat/SLES subscription |
| `ez_i.total_memory <var>\|-` | total RAM in KB |
| `ez_i.cpu_count <var>\|- [multiplier]` | processors, times a factor |

---

## Running without a person

Set `EZ_I_SKIP_ON` to **1 before sourcing** and everything that would ask a
question or draw on the terminal becomes a no op, so the same script runs
unattended. The functions that compute something still do.

```bash
EZ_I_SKIP_ON=1
source "./ez_i/ez_i.bash"
```

A target variable is left exactly as it was, so give it the default you want
before asking:

```bash
declare WHERE="/opt/default"
ez_i.ask WHERE "Where should it go?"      # unattended: stays "/opt/default"
```

`ez_i.ask_yes_no` cannot do that — it also answers through the exit status,
so there is no variable to pre-seed. It takes the answer as its **fourth**
argument:

```bash
ez_i.ask_yes_no "" "Update the distro?" "" 1   # nobody answers: yes
ez_i.ask_yes_no "" "Disable SELinux?"   "" 0   # nobody answers: no
```

That same argument is what a **timeout** falls back on, because a timeout
running out and `EZ_I_SKIP_ON` being set are the same situation — the
question was put and no person answered it:

```bash
ez_i.ask_yes_no AGREED "Carry on?" 30 1        # 30s, then yes; unattended: yes
```

**IMPORTANT:** it has **no default**, and leaving it out is an **error**,
not a silent no:

```
ERROR! "ez_i.ask_yes_no" has nobody to answer it (EZ_I_SKIP_ON) and was
given no answer to use.
```

What an unanswered question should do belongs to the **question**. "Update
your distro?" wants yes; "disable SELinux?" wants no. Any constant the
library picked would be wrong for one of them, and wrong *silently* — which
is how a destructive step gets confirmed by an empty terminal, or a harmless
one refused for no reason. A question that can go unanswered and does not
say what to do then is a mistake in the calling script, and is reported as
one.

The timeout half is checked **even with a person present**, so the mistake
surfaces on the first ordinary run rather than the first unattended one.

`ez_i.read` follows the same rule: give it a timeout and you must say what
the answer is when it runs out. An empty one is not an answer — it cannot be
told apart from a bare enter, and it shows up in the prompt as
`("" in 30 seconds)`, which tells the reader nothing.

A **message** is still printed - `ez_i.notify` and its three faces - because
the point of one is to be seen, and a sound is still made where one was asked
for: the run nobody is watching is the one most likely to be noticed by ear.
What they do not do is wait.

---

## Names

Everything this library defines is one of three things:

| Shape | Is |
|---|---|
| `ez_i.<something>` | a public function |
| `ez_i._<something>` | a private one |
| `_EZ_I_<SOMETHING>` | the library's own state |

The one exception is **`EZ_I_SKIP_ON`**, which is public on purpose because a
script sets it. Nothing else reaches the scope of the script that sources
this file, and the test suite checks exactly that.

## How a value reaches your variable

BASH scoping is **dynamic**, not lexical. A variable declared `local` in your
function is visible all the way down the call stack, to everything that
function calls. So this works, and is the normal way to use the library:

```bash
my_func() {
    local my_var
    ez_i.trim my_var "  padded  " 2
    echo "$my_var"                  # padded
}
```

`my_var` never becomes global — it is still local to `my_func`, and gone when
`my_func` returns. It is simply **reachable** from deeper in the stack while
`my_func` is running, which is what lets the nameref write back to it.

### The catch, and what is done about it

That same rule cuts the other way. A nameref resolves against the scope chain
**at the moment it is written**, and a local of the function doing the
writing sits *nearer* on that chain than yours. A library function with a
plain `local value` would therefore swallow the result of
`ez_i.trim value ...` in silence.

Rather than disfigure every local name to dodge it, the library removes the
offending local from the chain before writing. A function CAN unset a local
of the function that called *it*, so the write is delegated one frame down,
to `ez_i.emit_scalar` and its relatives, and they unset the shadowing local before
binding the nameref.

They unset **only** when the target really is a local of their caller.
Unsetting anything else would destroy your variable outright, attributes and
all — an associative array would come back a plain indexed one. The list of
each function's locals is read **once, at source time**, out of what
`declare -f` prints:

```
ez_i.trim -> [ target value mode ]
```

Nothing is computed per call, nothing has to be written inside the functions,
and a local declared inside an `if` is seen just the same, because what is
read is the body and not the running scope.

### What this costs you

Nothing. There is no naming rule to honour, and any variable name works as a
target. The suite proves it by generating a test for **every local name of
every function** out of that same list: add a local to the library and a test
appears by itself.

The only names the library keeps to itself are `_EZ_I_*` and the handful of
namerefs called `_ez_i_*_ref`, which no caller would reach for.

## Testing

```sh
./test/test.bash          # 336 integrity tests, run twice
```

Exits 0 only if everything passed.

Alongside the functional tests the suite checks the things that are easy to
get wrong while editing and that no functional test would notice: that every
source file parses, that **sourcing the library prints absolutely nothing**
(a stray apostrophe in a `: '...'` docstring closes the string early and the
rest of the paragraph gets *run*), that no name escapes the namespace, that
every function carries a docstring, and that a caller variable named after
one of the usual suspects is never shadowed.

What the suite cannot reach is listed at the top of `test/test.bash`, with
the reason: the functions that wait on a person, the ones that need root, and
the ones that need a specific distribution.

### The POSIX awk pass

`awk` is a NAME shared by several different programs: **gawk** on Arch and
Fedora, **mawk** on Debian and Ubuntu, **busybox awk** on Alpine, **BWK awk**
on the BSDs. gawk accepts the POSIX language *plus* a large set of GNU
extensions, so a suite that only ever runs under gawk cannot tell a portable
program from one that quietly leans on GNU — and the difference only shows up
on somebody else's machine.

So the whole suite runs a **second time** with an `awk` on `PATH` that is
`gawk --posix`, which refuses every extension. It needs nothing installed
beyond the gawk already there, and it is skipped silently when gawk is absent
— under mawk or busybox awk the first pass *is* the strict one.

```
============================================================
 POSIX AWK PASS ("gawk --posix" - every GNU extension refused)
 TOTAL 336 | PASSED 336 | FAILED 0
============================================================
```

Set `SKIP_POSIX_AWK_PASS=1` to leave it out.

## Limitations

- **Linux.** `/proc/meminfo`, `/proc/sys/kernel/random/uuid` and `ps aux` are
  assumed. Most of the library is portable; those parts are not.
- **One animation at a time.** `ez_i.progress` does not nest.
- **No floating point in the task statistics.** The smallest unit is the
  millisecond, so a loop whose iterations are faster than that reports
  nothing useful.
- **`ez_i.run` cannot report a bare `exit N`**, which ends the capturing
  subshell before the code can be read back.
- **`ez_i.array_to_file` is one element per line**, so an element containing
  a newline comes back as several.
- **A backup name has a resolution of one second**, so two backups of the
  same path within the same second resolve to the same name.
- **`ez_i.check_distro_status` only knows RedHat and SLES**, and is the one
  part of the library its own suite cannot exercise.

## About

ez_i 🄯 BSD-3-Clause  
Eduardo Lúcio Amorim Costa  
Brazil-ES  
https://www.linkedin.com/in/eduardo-software-livre/

![Brazil](./images/brazil.png)
