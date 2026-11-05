#!/bin/bash
#
# test/terminal.bash - drawing, paging, progress and task statistics
#
# Part of the "ez_i" test suite. Sourced by "test/test.bash", never on its
# own: it relies on the harness.
#
# These run with EZ_I_SKIP_ON at 0, because the whole point is to check what
# they draw. The suite has no terminal, which is itself worth testing: that
# is the setting in which paging has nothing to measure against.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

t_group "ez_i.indent"

t_equals "indents by two"   "  x"        "$(echo "x" | ez_i.indent 2)"
t_equals "indents by four"  "    x"      "$(echo "x" | ez_i.indent 4)"
t_equals "indents by eight" "        x"  "$(echo "x" | ez_i.indent 8)"
t_fails "an unknown level fails" ez_i.indent 3

t_group "ez_i.divider and the sections"

t_equals "the divider" "----------------------------------" "$(ez_i.divider)"
case "$(ez_i.open_section)" in
    "> ---"*) t_report 0 "a section opens" ;;
    *) t_report 1 "a section opens" "got [$(ez_i.open_section)]" ;;
esac
case "$(ez_i.open_main_section)" in
    "> ==="*) t_report 0 "a main section opens" ;;
    *) t_report 1 "a main section opens" ;;
esac
case "$(ez_i.open_section "MY TITLE")" in
    *"MY TITLE"*) t_report 0 "a title is shown" ;;
    *) t_report 1 "a title is shown" ;;
esac
case "$(ez_i.sub_section "T" "B")" in
    *"> T"*"B"*) t_report 0 "a subsection shows title and body" ;;
    *) t_report 1 "a subsection shows title and body" ;;
esac

t_group "ez_i.print_long"

# NOTE: This used to raise an arithmetic error and then HANG inside "less"
# whenever there was no terminal, which is every pipe, cron job and CI run.
t_run ez_i.print_long "" "a short string"
t_equals "survives having no terminal, nothing on stderr" "" "$T_RUN_STDERR"
t_equals "and prints the text"  "a short string" "$T_RUN_STDOUT"

declare T_PAGED=9
ez_i.print_long T_PAGED "short" > /dev/null
t_equals "reports that it did not page" "0" "$T_PAGED"

t_group "EZ_I_SKIP_ON"

EZ_I_SKIP_ON=1
t_equals "the skip flag silences the divider" "" "$(ez_i.divider)"
t_equals "the skip flag silences a section"   "" "$(ez_i.open_section "T")"
t_equals "the skip flag silences a subsection" "" "$(ez_i.sub_section "T" "B")"
EZ_I_SKIP_ON=0
t_equals "and turning it off brings them back" \
    "----------------------------------" "$(ez_i.divider)"

t_group "ez_i.progress"

ez_i.progress "a" > /dev/null 2>&1
if ((_EZ_I_ANIMATION_PID > 0)) ; then
    t_report 0 "starting gives a pid"
else
    t_report 1 "starting gives a pid"
fi
ez_i.progress "o" > /dev/null 2>&1
t_equals "stopping clears the pid" "0" "$_EZ_I_ANIMATION_PID"
ez_i.progress "o" > /dev/null 2>&1
t_equals "stopping twice is harmless" "0" "$_EZ_I_ANIMATION_PID"
t_fails "an unknown action fails" ez_i.progress "x"

t_group "ez_i.progress_draw and friends"

# Without a terminal they are all no ops, which is the state this suite runs
# in, so that half is checked here directly.
t_equals "drawing without a terminal prints nothing" "" \
    "$(ez_i.progress_draw "Label" "item" "stats")"
t_equals "and reports success anyway" "0" \
    "$(ez_i.progress_draw "Label" "item" "stats" > /dev/null ; echo $?)"
t_equals "clearing when nothing was drawn is harmless" "0" \
    "$(ez_i.progress_clear > /dev/null ; echo $?)"
t_fails "waiting with no process id fails" ez_i.progress_wait "" "L" "I" "S"

# NOTE: It still has to WAIT, terminal or not. A job that is skipped because
# nobody is watching would be a job that never ran.
T_START=$(($(date +%s%N) / 1000000))
sleep 0.4 &
ez_i.progress_wait $! "Label" "item" "stats"
T_WAITED=$(($(($(date +%s%N) / 1000000)) - T_START))
t_equals "it waits for the job even with nothing to draw on" "1" \
    "$([ "$T_WAITED" -ge 350 ] && echo 1 || echo 0)"

sleep 0.1 &
ez_i.progress_wait $! "L" "I" "S"
t_equals "and hands back the job status" "0" "$?"
bash -c "exit 3" &
ez_i.progress_wait $! "L" "I" "S"
t_equals "including a failure" "3" "$?"

# The two mechanisms write to the same place on screen, so whichever starts
# second has to be refused rather than left to fight over it.
_EZ_I_ANIMATION_PID=424242
t_fails "drawing is refused while the animation runs" \
    ez_i.progress_draw "Label" "item" "stats"
_EZ_I_ANIMATION_PID=0
_EZ_I_DRAWING=1
t_fails "and the animation is refused while drawing" ez_i.progress "a"
_EZ_I_DRAWING=0

# NOTE: What it actually DRAWS needs a terminal, so a pty is borrowed for
# it. Skipped, loudly, where "script" is not installed - a test that quietly
# does not run is worse than no test.
if command -v script > /dev/null 2>&1 ; then
    T_DRAWN="$(script -qec "bash -c '
        source \"$TESTS_ROOT/ez_i.bash\"
        ez_i.progress_draw \"Converting\" \"a/b.png\" \"ITEMS LEFT 4/5\"
        ez_i.progress_draw \"Converting\" \"a/b.png\" \"ITEMS LEFT 3/5\"
        ez_i.progress_draw \"Converting\" \"a/b.png\" \"ITEMS LEFT 2/5\"
        ez_i.progress_draw \"Converting\" \"a/b.png\" \"ITEMS LEFT 1/3\"
        ez_i.progress_clear
    '" /dev/null 2>&1 | tr '\r' '\n')"
    case "$T_DRAWN" in
        *"Converting: a/b.png"*) t_report 0 "with a terminal it draws the item" ;;
        *) t_report 1 "with a terminal it draws the item" "got [$T_DRAWN]" ;;
    esac
    case "$T_DRAWN" in
        *"ITEMS LEFT 1/3"*) t_report 0 "and the counters" ;;
        *) t_report 1 "and the counters" "got [$T_DRAWN]" ;;
    esac

    # NOTE: Four calls, not two. The first two frames are deliberately the
    # same - the bar sits empty for a moment before the word fills in - so
    # two calls would prove nothing.
    T_FRAMES="$(printf '%s' "$T_DRAWN" | grep -oE '\|[A-Z. ]{10}\|' | sort -u | wc -l)"
    t_equals "each call moves the animation on" "1" \
        "$([ "$T_FRAMES" -ge 2 ] && echo 1 || echo 0)"
    case "$T_DRAWN" in
        *$'\033'"[?25h"*) t_report 0 "clearing gives the cursor back" ;;
        *) t_report 1 "clearing gives the cursor back" ;;
    esac
else
    t_report 1 "a pty is needed to test the drawing (install \"script\")"
fi

t_group "ez_i.task_stats_*"

declare -A T_TASK=()
ez_i.task_stats_init T_TASK 4
declare T_STATS
ez_i.task_stats_begin T_TASK
ez_i.task_stats_end T_STATS T_TASK
case "$T_STATS" in
    "ITEMS LEFT 3/4 (25% SO FAR)"*) t_report 0 "counts the first of four" ;;
    *) t_report 1 "counts the first of four" "got [$T_STATS]" ;;
esac

ez_i.task_stats_begin T_TASK
ez_i.task_stats_skip T_STATS T_TASK
case "$T_STATS" in
    "ITEMS LEFT 2/4 (50% SO FAR)"*"<SKIPPED ITEM>") t_report 0 "marks a skipped item" ;;
    *) t_report 1 "marks a skipped item" "got [$T_STATS]" ;;
esac

# NOTE: A zero length used to divide by zero and print a BASH error into the
# middle of the output of whatever was using it.
declare -A T_ZERO=()
ez_i.task_stats_init T_ZERO 0
ez_i.task_stats_begin T_ZERO
t_run ez_i.task_stats_end T_STATS T_ZERO
t_equals "a zero length raises no error" "" "$T_RUN_STDERR"

# Two loops at once, each with its own counters. The array is the only way
# to hold them, so nesting cannot be got wrong.
declare -A T_OUTER=()
declare -A T_INNER=()
ez_i.task_stats_init T_OUTER 2
ez_i.task_stats_init T_INNER 10
ez_i.task_stats_begin T_OUTER ; ez_i.task_stats_end T_STATS T_OUTER
declare T_INNER_STATS
ez_i.task_stats_begin T_INNER ; ez_i.task_stats_end T_INNER_STATS T_INNER
case "$T_STATS" in
    "ITEMS LEFT 1/2"*) t_report 0 "nested loops keep separate counts (outer)" ;;
    *) t_report 1 "nested loops keep separate counts (outer)" "got [$T_STATS]" ;;
esac
case "$T_INNER_STATS" in
    "ITEMS LEFT 9/10"*) t_report 0 "nested loops keep separate counts (inner)" ;;
    *) t_report 1 "nested loops keep separate counts (inner)" "got [$T_INNER_STATS]" ;;
esac

t_fails "an empty control array fails" ez_i.task_stats_init "" 4
t_fails "a non numeric length fails"   ez_i.task_stats_init T_TASK "lots"

t_group "ez_i.log"

declare T_LOG
ez_i.log T_LOG "first entry" 0 "" "$TESTS_TMP/logs"
t_equals "a default output log is named for its kind" "output.log" "$(basename "$T_LOG")"
t_succeeds "and it exists" ez_i.exists "" "f" "$T_LOG"
t_succeeds "the entry is in it" ez_i.file_contains "" "$T_LOG" "first entry"

ez_i.log "" "second entry" 0 "$T_LOG"
t_equals "a second entry appends" "2" "$(grep -c "entry" "$T_LOG")"

declare T_ERROR_LOG
ez_i.log T_ERROR_LOG "an error" 1 "" "$TESTS_TMP/logs"
t_equals "an error log is named for its kind" "error.log" "$(basename "$T_ERROR_LOG")"

declare T_NEW_LOG
ez_i.log T_NEW_LOG "timestamped" 0 "new" "$TESTS_TMP/logs"
case "$(basename "$T_NEW_LOG")" in
    output-D*.log) t_report 0 "\"new\" gives a timestamped name" ;;
    *) t_report 1 "\"new\" gives a timestamped name" "got [$T_NEW_LOG]" ;;
esac

declare T_PREFIX_LOG
ez_i.log T_PREFIX_LOG "custom" 0 "my_prefix" "$TESTS_TMP/logs"
case "$(basename "$T_PREFIX_LOG")" in
    my_prefix-D*.log) t_report 0 "a custom prefix is used" ;;
    *) t_report 1 "a custom prefix is used" "got [$T_PREFIX_LOG]" ;;
esac

t_succeeds "the log folder is created when missing" \
    ez_i.exists "" "d" "$TESTS_TMP/logs"

t_group "ez_i.clean_old_logs"

mkdir -p "$TESTS_TMP/many_logs"
for T_I in 1 2 3 4 5 ; do
    echo "x" > "$TESTS_TMP/many_logs/log$T_I.log"
    touch -d "2020-01-0$T_I" "$TESTS_TMP/many_logs/log$T_I.log"
done
ez_i.clean_old_logs "$TESTS_TMP/many_logs" 2
t_equals "keeps only the most recent" "2" \
    "$(find "$TESTS_TMP/many_logs" -maxdepth 1 -type f | wc -l)"
t_succeeds "and the newest survived" \
    ez_i.exists "" "f" "$TESTS_TMP/many_logs/log5.log"
t_fails "while the oldest is gone" \
    ez_i.exists "" "f" "$TESTS_TMP/many_logs/log1.log"

t_succeeds "a folder that is not there is not an error" \
    ez_i.clean_old_logs "$TESTS_TMP/no_such_logs" 2
t_fails "a non numeric count fails" \
    ez_i.clean_old_logs "$TESTS_TMP/many_logs" "lots"
