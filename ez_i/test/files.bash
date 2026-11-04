#!/bin/bash
#
# test/files.bash - files, folders, arrays on disk and backups
#
# Part of the "ez_i" test suite. Sourced by "test/test.bash", never on its
# own: it relies on the harness.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

t_group "ez_i.exists"

touch "$TESTS_TMP/a_file"
mkdir -p "$TESTS_TMP/a_folder"

t_succeeds "finds a file, status form"   ez_i.exists "" "f" "$TESTS_TMP/a_file"
t_succeeds "finds a folder, status form" ez_i.exists "" "d" "$TESTS_TMP/a_folder"
t_fails "a file is not a folder"         ez_i.exists "" "d" "$TESTS_TMP/a_file"
t_fails "a folder is not a file"         ez_i.exists "" "f" "$TESTS_TMP/a_folder"
t_fails "misses what is not there"       ez_i.exists "" "f" "$TESTS_TMP/nope"

declare T_IS_THERE
ez_i.exists T_IS_THERE "f" "$TESTS_TMP/a_file"
t_equals "variable form says 1 for true"  "1" "$T_IS_THERE"
ez_i.exists T_IS_THERE "f" "$TESTS_TMP/nope"
t_equals "variable form says 0 for false" "0" "$T_IS_THERE"

# NOTE: The whole point of the named form is that it does not report the
# answer through the exit status, so it is safe under "set -e".
t_succeeds "the variable form succeeds even when false" \
    ez_i.exists T_IS_THERE "f" "$TESTS_TMP/nope"

t_fails "an unknown type fails" ez_i.exists "" "x" "$TESTS_TMP/a_file"

# A caller variable named like one of the internals must still be written.
declare value="UNTOUCHED"
ez_i.exists value "f" "$TESTS_TMP/a_file"
t_equals "a caller variable named \"value\" is not shadowed" "1" "$value"
declare path="UNTOUCHED"
ez_i.exists path "f" "$TESTS_TMP/a_file"
t_equals "a caller variable named \"path\" is not shadowed" "1" "$path"

t_group "ez_i.file_contains"

printf 'hello world\nsome.thing\n' > "$TESTS_TMP/grep.txt"
t_succeeds "finds a plain string" ez_i.file_contains "" "$TESTS_TMP/grep.txt" "hello"
t_fails "misses what is absent"   ez_i.file_contains "" "$TESTS_TMP/grep.txt" "nothere"
t_succeeds "inverts the check"    ez_i.file_contains "" "$TESTS_TMP/grep.txt" "nothere" 1
t_succeeds "finds a string holding a dot" \
    ez_i.file_contains "" "$TESTS_TMP/grep.txt" "some.thing"
t_fails "the dot is not a wildcard" \
    ez_i.file_contains "" "$TESTS_TMP/grep.txt" "someXthing"
t_fails "a missing file contains nothing" \
    ez_i.file_contains "" "$TESTS_TMP/nope.txt" "hello"

declare T_HAS
ez_i.file_contains T_HAS "$TESTS_TMP/grep.txt" "hello"
t_equals "variable form says 1 for true" "1" "$T_HAS"

t_group "ez_i.delete_if_empty"

mkdir -p "$TESTS_TMP/empty"
t_succeeds "deletes an empty folder" ez_i.delete_if_empty "" "$TESTS_TMP/empty"
t_fails "and it is really gone"      ez_i.exists "" "d" "$TESTS_TMP/empty"

mkdir -p "$TESTS_TMP/full" ; touch "$TESTS_TMP/full/x"
t_fails "keeps a folder with content" ez_i.delete_if_empty "" "$TESTS_TMP/full"
t_succeeds "and it is still there"    ez_i.exists "" "d" "$TESTS_TMP/full"

mkdir -p "$TESTS_TMP/hidden" ; touch "$TESTS_TMP/hidden/.x"
t_fails "a hidden file counts as content by default" \
    ez_i.delete_if_empty "" "$TESTS_TMP/hidden"
t_succeeds "unless told to ignore hidden files" \
    ez_i.delete_if_empty "" "$TESTS_TMP/hidden" 1

t_fails "a folder that is not there was not deleted" \
    ez_i.delete_if_empty "" "$TESTS_TMP/never_existed"

t_group "ez_i.array_to_file / ez_i.file_to_array"

declare -a T_OUT=("one" "two" "three")
ez_i.array_to_file "$TESTS_TMP/arr.txt" T_OUT
t_equals "writes an array to a file" "one
two
three" "$(cat "$TESTS_TMP/arr.txt")"

declare -a T_IN=()
ez_i.file_to_array T_IN "$TESTS_TMP/arr.txt"
t_equals "reads a file back (count)" "3" "${#T_IN[@]}"
t_equals "reads a file back (item)"  "two" "${T_IN[1]}"

declare -a T_SPACED=("with space" "  padded  ")
ez_i.array_to_file "$TESTS_TMP/arr2.txt" T_SPACED
ez_i.file_to_array T_IN "$TESTS_TMP/arr2.txt"
t_equals "round trips a value with a space" "with space" "${T_IN[0]}"
t_equals "round trips the padding"          "  padded  " "${T_IN[1]}"

declare -a T_EMPTY=()
ez_i.array_to_file "$TESTS_TMP/arr3.txt" T_EMPTY
ez_i.file_to_array T_IN "$TESTS_TMP/arr3.txt"
t_equals "an empty array round trips to one empty item" "1" "${#T_IN[@]}"

t_fails "reading a missing file fails" ez_i.file_to_array T_IN "$TESTS_TMP/nope.txt"
t_fails "an empty target fails"        ez_i.file_to_array "" "$TESTS_TMP/arr.txt"
t_fails "an empty source array fails"  ez_i.array_to_file "$TESTS_TMP/x.txt" ""

# The array is emptied before it is filled.
ez_i.file_to_array T_IN "$TESTS_TMP/arr.txt"
ez_i.file_to_array T_IN "$TESTS_TMP/arr3.txt"
t_equals "the target is emptied first" "1" "${#T_IN[@]}"

t_group "ez_i.backup"

touch "$TESTS_TMP/original.txt"
declare -A T_BACKUP=()
ez_i.backup T_BACKUP "$TESTS_TMP/original.txt" 1
t_equals "a copy keeps the folder" "$TESTS_TMP" "${T_BACKUP[path]}"
case "${T_BACKUP[name]}" in
    original.txt-D*_BAK) t_report 0 "the name carries the suffix" ;;
    *) t_report 1 "the name carries the suffix" "got [${T_BACKUP[name]}]" ;;
esac
t_equals "[full] is the two joined" \
    "${T_BACKUP[path]}/${T_BACKUP[name]}" "${T_BACKUP[full]}"
t_succeeds "a copy leaves the original in place" \
    ez_i.exists "" "f" "$TESTS_TMP/original.txt"
t_succeeds "and the copy is there" ez_i.exists "" "f" "${T_BACKUP[full]}"

touch "$TESTS_TMP/name_only.txt"
ez_i.backup T_BACKUP "$TESTS_TMP/name_only.txt" 0 1
t_fails "asking only for a name writes nothing" \
    ez_i.exists "" "f" "${T_BACKUP[full]}"
t_succeeds "and leaves the original alone" \
    ez_i.exists "" "f" "$TESTS_TMP/name_only.txt"

touch "$TESTS_TMP/moved.txt"
ez_i.backup T_BACKUP "$TESTS_TMP/moved.txt"
t_fails "a rename leaves nothing behind" ez_i.exists "" "f" "$TESTS_TMP/moved.txt"
t_succeeds "and the renamed file is there" ez_i.exists "" "f" "${T_BACKUP[full]}"

t_fails "backing up what is not there fails" \
    ez_i.backup T_BACKUP "$TESTS_TMP/never_existed"

t_succeeds "an empty target is allowed, the backup still happens" \
    ez_i.backup "" "$TESTS_TMP/original.txt" 1
