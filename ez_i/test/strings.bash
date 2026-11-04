#!/bin/bash
#
# test/strings.bash - splitting, trimming, reversing and "sed"
#
# Part of the "ez_i" test suite. Sourced by "test/test.bash", never on its
# own: it relies on the harness.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

t_group "ez_i.trim"

declare T_VALUE
ez_i.trim T_VALUE "   left"    ; t_equals "trims leading"  "left" "$T_VALUE"
ez_i.trim T_VALUE "right   " 1 ; t_equals "trims trailing" "right" "$T_VALUE"
ez_i.trim T_VALUE "  both  " 2 ; t_equals "trims both"     "both" "$T_VALUE"
ez_i.trim T_VALUE "in  side" 2 ; t_equals "leaves the inside alone" "in  side" "$T_VALUE"
ez_i.trim T_VALUE "" 2         ; t_equals "an empty string stays empty" "" "$T_VALUE"

t_run ez_i.trim - "  out  " 2
t_equals "\"-\" prints it instead" "out" "$T_RUN_STDOUT"

t_fails "an unknown mode fails" ez_i.trim T_VALUE "x" 9
t_fails "an empty target fails" ez_i.trim "" "x" 2

t_group "ez_i.reverse"

declare T_REVERSED
ez_i.reverse T_REVERSED "abc" ; t_equals "reverses one line" "cba" "$T_REVERSED"
ez_i.reverse T_REVERSED "ab
cd"
t_equals "reverses several lines" "dc
ba" "$T_REVERSED"
ez_i.reverse T_REVERSED "a b" ; t_equals "keeps inner spaces" "b a" "$T_REVERSED"
ez_i.reverse T_REVERSED " ab" ; t_equals "keeps a leading space" "ba " "$T_REVERSED"
ez_i.reverse T_REVERSED "ab " ; t_equals "keeps a trailing space" " ba" "$T_REVERSED"

ez_i.reverse T_REVERSED "hello"
ez_i.reverse T_REVERSED "$T_REVERSED"
t_equals "reversing twice gives the original" "hello" "$T_REVERSED"

t_group "ez_i.split"

declare -a T_PARTS=()
ez_i.split T_PARTS "a,b,c" ","
t_equals "splits on a comma (count)" "3" "${#T_PARTS[@]}"
t_equals "splits on a comma (first)" "a" "${T_PARTS[0]}"
t_equals "splits on a comma (last)"  "c" "${T_PARTS[2]}"

ez_i.split T_PARTS "a b c"
t_equals "splits on spaces by default" "3" "${#T_PARTS[@]}"

ez_i.split T_PARTS "a;;b" ";;"
t_equals "splits on a multi character delimiter" "2" "${#T_PARTS[@]}"
t_equals "multi character delimiter, second item" "b" "${T_PARTS[1]}"

ez_i.split T_PARTS "a,,b" ","
t_equals "keeps an empty field" "" "${T_PARTS[1]}"
t_equals "empty field, count"   "3" "${#T_PARTS[@]}"

ez_i.split T_PARTS "a," ","
t_equals "a trailing delimiter gives a trailing empty field" "2" "${#T_PARTS[@]}"

ez_i.split T_PARTS "no-delimiter-here" ","
t_equals "no delimiter gives one item" "1" "${#T_PARTS[@]}"
t_equals "no delimiter, the item" "no-delimiter-here" "${T_PARTS[0]}"

ez_i.split T_PARTS "a
b" $'\n'
t_equals "splits on a real newline" "2" "${#T_PARTS[@]}"

# NOTE: "\n" between double quotes is a backslash and an "n", NOT a line
# break. Passing it meaning a line break splits nothing at all, in silence,
# which is why both forms are pinned down here.
ez_i.split T_PARTS "a
b" "\n"
t_equals "a literal backslash-n splits nothing" "1" "${#T_PARTS[@]}"
ez_i.split T_PARTS 'a\nb' "\n"
t_equals "and it does split a literal backslash-n" "2" "${#T_PARTS[@]}"

ez_i.split T_PARTS '"wad" "a;b;"' '"'
t_equals "splits on a double quote" "a;b;" "${T_PARTS[3]}"

ez_i.split T_PARTS "" ","
t_equals "an empty string gives one empty item" "1" "${#T_PARTS[@]}"

t_fails "an empty target fails" ez_i.split "" "a,b" ","

# The array is emptied before it is filled, so a second call cannot leave
# items of the first behind.
ez_i.split T_PARTS "1,2,3,4,5" ","
ez_i.split T_PARTS "x" ","
t_equals "the target is emptied first" "1" "${#T_PARTS[@]}"

t_group "ez_i.sed_escape"

declare T_ESCAPED
ez_i.sed_escape T_ESCAPED "a.b" 0
t_equals "escapes a dot for the pattern" 'a\.b' "$T_ESCAPED"
ez_i.sed_escape T_ESCAPED "a/b" 0
t_equals "escapes a slash for the pattern" 'a\/b' "$T_ESCAPED"
ez_i.sed_escape T_ESCAPED "a&b" 1
t_equals "escapes an ampersand for the replacement" 'a\&b' "$T_ESCAPED"
ez_i.sed_escape T_ESCAPED "plain" 0
t_equals "leaves a plain value alone" "plain" "$T_ESCAPED"
ez_i.sed_escape T_ESCAPED " pad " 0
t_equals "keeps padding spaces" " pad " "$T_ESCAPED"

t_group "ez_i.sed_str"

declare T_SED
ez_i.sed_str T_SED "abcb" "b" "X"
t_equals "replaces the first match by default" "aXcb" "$T_SED"
ez_i.sed_str T_SED "abcb" "b" "X" 0
t_equals "replaces every match with 0" "aXcX" "$T_SED"
ez_i.sed_str T_SED "abcb" "b" "X" 2
t_equals "replaces the nth match" "abcX" "$T_SED"
ez_i.sed_str T_SED "abcb" "b" "X" -1
t_equals "replaces the last match with -1" "abcX" "$T_SED"
ez_i.sed_str T_SED "a.b.c" "." "X" 0
t_equals "treats the pattern literally" "aXbXc" "$T_SED"
ez_i.sed_str T_SED "abc" "a" "&"
t_equals "treats the replacement literally" "&bc" "$T_SED"
ez_i.sed_str T_SED "no match here" "x" "y"
t_equals "no match leaves the string alone" "no match here" "$T_SED"
ez_i.sed_str T_SED "l1
l2" "l1" "X"
t_equals "works across lines" "X
l2" "$T_SED"

t_group "ez_i.sed_file"

printf 'alpha\nbeta\nalpha\n' > "$TESTS_TMP/sed.txt"
ez_i.sed_file "$TESTS_TMP/sed.txt" "alpha" "OMEGA"
t_equals "replaces the first match in a file" "OMEGA
beta
alpha" "$(cat "$TESTS_TMP/sed.txt")"

printf 'alpha\nbeta\nalpha\n' > "$TESTS_TMP/sed.txt"
ez_i.sed_file "$TESTS_TMP/sed.txt" "alpha" "OMEGA" 0
t_equals "replaces every match in a file" "OMEGA
beta
OMEGA" "$(cat "$TESTS_TMP/sed.txt")"

printf 'a/b\n' > "$TESTS_TMP/sed.txt"
ez_i.sed_file "$TESTS_TMP/sed.txt" "a/b" "c/d"
t_equals "handles slashes in a file" "c/d" "$(cat "$TESTS_TMP/sed.txt")"

t_fails "a missing file fails" ez_i.sed_file "$TESTS_TMP/nope.txt" "a" "b"
