#!/bin/bash
#
# test/numbers.bash - time, percentages, byte units and UUIDs
#
# Part of the "ez_i" test suite. Sourced by "test/test.bash", never on its
# own: it relies on the harness.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

t_group "ez_i.format_time"

declare T_TIME
ez_i.format_time T_TIME 520      ; t_equals "milliseconds only" "520ms" "$T_TIME"
ez_i.format_time T_TIME 1000     ; t_equals "one second"        "1s" "$T_TIME"
ez_i.format_time T_TIME 61000    ; t_equals "a minute and one"  "1m 1s" "$T_TIME"
ez_i.format_time T_TIME 3661000  ; t_equals "an hour and some"  "1h 1m 1s" "$T_TIME"
ez_i.format_time T_TIME 90061000 ; t_equals "more than a day"   "1d 1h 1m 1s" "$T_TIME"
ez_i.format_time T_TIME 0        ; t_equals "zero"              "0ms" "$T_TIME"
ez_i.format_time T_TIME 3600000  ; t_equals "a whole hour drops the rest" "1h" "$T_TIME"
ez_i.format_time T_TIME 86400000 ; t_equals "a whole day too"  "1d" "$T_TIME"
ez_i.format_time T_TIME 60000    ; t_equals "a whole minute too" "1m" "$T_TIME"
ez_i.format_time T_TIME 3660000  ; t_equals "hours and minutes, no seconds" "1h 1m" "$T_TIME"

t_run ez_i.format_time - 1000
t_equals "\"-\" prints it instead" "1s" "$T_RUN_STDOUT"

t_group "ez_i.percent_of"

declare T_PERCENT
ez_i.percent_of T_PERCENT 200 50   ; t_equals "half of 200"   "100" "$T_PERCENT"
ez_i.percent_of T_PERCENT 200 0    ; t_equals "none of 200"   "0" "$T_PERCENT"
ez_i.percent_of T_PERCENT 100 100  ; t_equals "all of 100"    "100" "$T_PERCENT"
ez_i.percent_of T_PERCENT 10 107 2 ; t_equals "rounds to the nearest" "11" "$T_PERCENT"
ez_i.percent_of T_PERCENT 10 105 1 ; t_equals "truncates"     "10" "$T_PERCENT"

t_group "ez_i.convert_bytes"

declare T_BYTES
ez_i.convert_bytes T_BYTES 1024 "B" "KB"  ; t_equals "B to KB"   "1" "$T_BYTES"
ez_i.convert_bytes T_BYTES 1024 "KB" "MB" ; t_equals "KB to MB"  "1" "$T_BYTES"
ez_i.convert_bytes T_BYTES 1 "MB" "KB"    ; t_equals "MB to KB"  "1024" "$T_BYTES"
ez_i.convert_bytes T_BYTES 1 "GB" "MB"    ; t_equals "GB to MB"  "1024" "$T_BYTES"
ez_i.convert_bytes T_BYTES 1 "PB" "TB"    ; t_equals "PB to TB"  "1024" "$T_BYTES"
ez_i.convert_bytes T_BYTES 5 "KB" "KB"    ; t_equals "same unit" "5" "$T_BYTES"
ez_i.convert_bytes T_BYTES 0 "KB" "GB"    ; t_equals "zero"      "0" "$T_BYTES"

t_fails "an unknown source unit fails" ez_i.convert_bytes T_BYTES 1 "XB" "KB"
t_fails "an unknown target unit fails" ez_i.convert_bytes T_BYTES 1 "KB" "XB"

t_group "ez_i.uuid"

declare T_UUID
ez_i.uuid T_UUID    ; t_equals "a UUID is 36 characters" "36" "${#T_UUID}"
ez_i.uuid T_UUID 1  ; t_equals "without dashes it is 32" "32" "${#T_UUID}"
case "$T_UUID" in
    *-*) t_report 1 "the dashes are really gone" "got [$T_UUID]" ;;
    *)   t_report 0 "the dashes are really gone" ;;
esac

declare T_UUID_AGAIN
ez_i.uuid T_UUID_AGAIN
if [[ "$T_UUID" == "$T_UUID_AGAIN" ]] ; then
    t_report 1 "two UUIDs differ"
else
    t_report 0 "two UUIDs differ"
fi
