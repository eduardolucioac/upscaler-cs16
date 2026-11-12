#!/bin/bash
#
# test/shadowing.bash - that a target is written whatever it is called
#
# Part of the "ez_i" test suite. Sourced by "test/test.bash", never on its
# own: it relies on the harness.
#
# A nameref resolves against the scope chain at the moment it is written, so
# a local of the library would shadow a caller variable of the same name and
# swallow the result. "ez_i._unshadow" takes that local off the chain, using
# the list "ez_i._scan_locals" built at source time.
#
# These tests are GENERATED from that very list, so every local name of every
# function is tried as a target. Adding a local to the library adds a test
# here by itself.
#
# ez_i - Interactive BASH scripts without the boilerplate "inverted (c)" BSD-3-Clause
# Eduardo Lucio Amorim Costa
#

# NOTE: The probes below are named "ez_i._t_*" and the scan is re-run, so
# that they are covered by the very mechanism they are testing. The scan at
# source time could not have seen them: they did not exist yet.
t_group "the scan itself"

t_equals "the scan ran" "1" \
    "$([ "${#_EZ_I_LOCALS[@]}" -gt 0 ] && echo 1 || echo 0)"

# NOTE: What the scan believes must match what BASH actually declares. A
# parser that quietly misses a form would leave those functions unprotected,
# and a parser that invents a name would make the library unset a variable
# of the caller that it has no business touching.
function ez_i._t_runtime_locals() {
    : 'Print the locals BASH really has in this function, one per line.'

    local alpha=1 beta=2
    local -a gamma=()
    local -A delta=()
    local -n epsilon="alpha"
    local -p
}
ez_i._scan_locals
# NOTE: A nameref is left out on purpose. "unset" on one destroys the
# variable it POINTS AT rather than the binding, so unsetting an internal
# nameref would take the library own state with it; a target named after
# one simply comes back unwritten instead.
T_RUNTIME="$(ez_i._t_runtime_locals | sed -n 's/^declare -\([^ ]*\) \([A-Za-z_][A-Za-z0-9_]*\).*/\1 \2/p' \
    | grep -v '^[a-zA-Z]*n[a-zA-Z]* ' | awk '{print $2}' | sort | tr '\n' ' ')"
T_SCANNED="$(echo "${_EZ_I_LOCALS[ez_i._t_runtime_locals]}" | tr ' ' '\n' | grep -v '^$' | sort | tr '\n' ' ')"
t_equals "the scan agrees with what BASH declares" "$T_RUNTIME" "$T_SCANNED"

case " ${_EZ_I_LOCALS[ez_i._t_runtime_locals]} " in
    *" epsilon "*) t_report 1 "a nameref is left out of the scan" ;;
    *) t_report 0 "a nameref is left out of the scan" ;;
esac

# And nothing the library itself binds is in there either, which is what
# keeps "ez_i._unshadow" from ever destroying library state.
t_equals "no library nameref is recorded" "" \
    "$(echo "${_EZ_I_LOCALS[@]}" | tr ' ' '\n' | grep -E '_ref$|_ref_[0-9a-f]+$' | sort -u | tr '\n' ' ')"

t_group "every local name works as a target"

# Scalar out.
for T_NAME in ${_EZ_I_LOCALS[ez_i.trim]} ; do
    unset "$T_NAME" ; declare "$T_NAME=UNTOUCHED"
    ez_i.trim "$T_NAME" "  ok  " 2
    t_equals "ez_i.trim into \"$T_NAME\"" "ok" "${!T_NAME}"
done

# Bool out, both forms.
for T_NAME in ${_EZ_I_LOCALS[ez_i.exists]} ; do
    unset "$T_NAME" ; declare "$T_NAME=UNTOUCHED"
    ez_i.exists "$T_NAME" "f" "$TESTS_TMP/a_file"
    t_equals "ez_i.exists into \"$T_NAME\"" "1" "${!T_NAME}"
done

# Indexed array out.
for T_NAME in ${_EZ_I_LOCALS[ez_i.split]} ; do
    unset "$T_NAME" ; declare -a "$T_NAME=()"
    ez_i.split "$T_NAME" "a,b,c" ","
    declare -n T_REF="$T_NAME"
    t_equals "ez_i.split into \"$T_NAME\"" "a|b|c" \
        "$(IFS='|' ; echo "${T_REF[*]}")"
    unset -n T_REF
done

for T_NAME in ${_EZ_I_LOCALS[ez_i.file_to_array]} ; do
    printf 'um\ndois\n' > "$TESTS_TMP/fta.txt"
    unset "$T_NAME" ; declare -a "$T_NAME=()"
    ez_i.file_to_array "$T_NAME" "$TESTS_TMP/fta.txt"
    declare -n T_REF="$T_NAME"
    t_equals "ez_i.file_to_array into \"$T_NAME\"" "um|dois" \
        "$(IFS='|' ; echo "${T_REF[*]}")"
    unset -n T_REF
done

# Associative array out.
for T_NAME in ${_EZ_I_LOCALS[ez_i.run]} ; do
    unset "$T_NAME" ; declare -A "$T_NAME=()"
    ez_i.run "$T_NAME" "echo saida"
    declare -n T_REF="$T_NAME"
    t_equals "ez_i.run into \"$T_NAME\"" "saida" "${T_REF[stdout]}"
    unset -n T_REF
done

for T_NAME in ${_EZ_I_LOCALS[ez_i.about_distro]} ; do
    unset "$T_NAME" ; declare -A "$T_NAME=()"
    ez_i.about_distro "$T_NAME"
    declare -n T_REF="$T_NAME"
    t_equals "ez_i.about_distro into \"$T_NAME\"" "$(uname -m)" "${T_REF[arch]}"
    unset -n T_REF
done

# The work of classifying a release file lives here, so this is where most
# of the names that could collide are.
for T_NAME in ${_EZ_I_LOCALS[ez_i._classify_release]} ; do
    unset "$T_NAME" ; declare -A "$T_NAME=()"
    ez_i._classify_release "$T_NAME" "NAME=\"Sonda\"
ID=debian
VERSION_ID=\"12\""
    declare -n T_REF="$T_NAME"
    t_equals "ez_i._classify_release into \"$T_NAME\"" "Debian" "${T_REF[based]}"
    unset -n T_REF
done

for T_NAME in ${_EZ_I_LOCALS[ez_i.backup]} ; do
    touch "$TESTS_TMP/bk_$T_NAME"
    unset "$T_NAME" ; declare -A "$T_NAME=()"
    ez_i.backup "$T_NAME" "$TESTS_TMP/bk_$T_NAME" 1
    declare -n T_REF="$T_NAME"
    t_equals "ez_i.backup into \"$T_NAME\"" "$TESTS_TMP" "${T_REF[path]}"
    unset -n T_REF
done

t_group "an array the library READS is never shadowed"

# The mirror image: these bind the caller array to read it, and must not be
# fooled by a local of their own with the same name. Nothing is unset here -
# that would destroy the input.
for T_NAME in ${_EZ_I_LOCALS[ez_i.array_to_file]} ; do
    unset "$T_NAME" ; declare -a "$T_NAME=(um dois tres)"
    ez_i.array_to_file "$TESTS_TMP/atf.txt" "$T_NAME"
    t_equals "ez_i.array_to_file from \"$T_NAME\"" "um
dois
tres" "$(cat "$TESTS_TMP/atf.txt")"
    declare -n T_REF="$T_NAME"
    t_equals "and \"$T_NAME\" is left intact" "3" "${#T_REF[@]}"
    unset -n T_REF
done

t_group "the task counters are mutated in place"

for T_NAME in ${_EZ_I_LOCALS[ez_i.task_stats_init]} ; do
    unset "$T_NAME" ; declare -A "$T_NAME=()"
    ez_i.task_stats_init "$T_NAME" 4
    ez_i.task_stats_begin "$T_NAME"
    declare T_STATS=""
    ez_i.task_stats_end T_STATS "$T_NAME"
    case "$T_STATS" in
        "ITEMS LEFT 3/4"*) t_report 0 "task stats through \"$T_NAME\"" ;;
        *) t_report 1 "task stats through \"$T_NAME\"" "got [$T_STATS]" ;;
    esac
done

t_group "the copy is faithful"

# "ez_i.emit_array" and "ez_i.emit_assoc" copy before they unset. The copy
# has to survive everything a value can hold.
function ez_i._t_awkward_array() {
    local -a parts=("com espaco" "" "com
quebra" "com'aspas" 'com"aspas' "com\\barra")
    ez_i.emit_array "$1" parts
}
ez_i._scan_locals
declare -a T_GOT=()
ez_i._t_awkward_array T_GOT
t_equals "an awkward array keeps its length"  "6" "${#T_GOT[@]}"
t_equals "a value with a space"               "com espaco" "${T_GOT[0]}"
t_equals "an empty value"                     "" "${T_GOT[1]}"
t_equals "a value with a newline"             "com
quebra" "${T_GOT[2]}"
t_equals "a value with a single quote"        "com'aspas" "${T_GOT[3]}"
t_equals "a value with a double quote"        'com"aspas' "${T_GOT[4]}"
t_equals "a value with a backslash"           'com\barra' "${T_GOT[5]}"

# And the same when the target is named after the source, which is the case
# the copy exists for.
declare -a parts=()
ez_i._t_awkward_array parts
t_equals "a target named after the source still arrives" "6" "${#parts[@]}"

function ez_i._t_awkward_assoc() {
    local -A result=()
    result["chave com espaco"]="valor com espaco"
    result["vazio"]=""
    result["quebra"]="com
quebra"
    ez_i.emit_assoc "$1" result
}
ez_i._scan_locals
declare -A T_GOT_A=()
ez_i._t_awkward_assoc T_GOT_A
t_equals "an awkward assoc keeps its keys" "3" "${#T_GOT_A[@]}"
t_equals "a key with a space"   "valor com espaco" "${T_GOT_A[chave com espaco]}"
t_equals "an empty value"       "" "${T_GOT_A[vazio]}"
t_equals "a value with a newline" "com
quebra" "${T_GOT_A[quebra]}"

declare -A result=()
ez_i._t_awkward_assoc result
t_equals "a target named after the source still arrives" "3" "${#result[@]}"

t_group "a caller local is written, and stays local"

# The case the whole mechanism exists for: a target declared "local" in the
# function that calls the library.
function t_caller_local_scalar() {
    local value="UNTOUCHED"
    ez_i.trim value "  ok  " 2
    t_equals "a local named after a library local is written" "ok" "$value"
}
function t_caller_local_array() {
    local -a parts=()
    ez_i.split parts "a,b,c" ","
    t_equals "a local array named after a library local is filled" "3" "${#parts[@]}"
}
function t_caller_local_assoc() {
    local -A result=()
    ez_i.run result "echo saida"
    t_equals "a local assoc named after a library local is filled" \
        "saida" "${result[stdout]}"
}
function t_caller_local_leaks() {
    local escaping="x"
    ez_i.trim escaping "  ok  " 2
}
t_caller_local_scalar ; t_caller_local_array ; t_caller_local_assoc
t_caller_local_leaks
t_equals "and it does not leak to the global scope" "" "${escaping+leaked}"

# An attribute the caller gave the target must survive, which is why
# "ez_i._unshadow" refuses to unset anything that is not a library local.
function t_attribute_survives() {
    declare -A KEPT=()
    ez_i.run KEPT "echo saida"
    case "$(declare -p KEPT)" in
        "declare -A"*) t_report 0 "an associative target keeps its attribute" ;;
        *) t_report 1 "an associative target keeps its attribute" "$(declare -p KEPT)" ;;
    esac
}
t_attribute_survives
