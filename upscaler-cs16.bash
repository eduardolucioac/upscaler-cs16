#!/bin/bash

# > -----------------------------------------
# Run that script with bash even if the user use sh/dash or any sh like interpreter.
# This way it correctly works with either: "sh ./my_script.bash" or "bash ./my_script.bash"
# or "./my_script.bash".

if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# < -----------------------------------------

# NOTE: Avoids problems with relative paths.
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# NOTE: Load ez_i library (in reality a bash script). It provides a number of cool
# features for creating interactive bash scripts, including installers.
# [Ref(s).: https://github.com/eduardolucioac/ez_i ]
. "$SCRIPT_DIR/ez_i/ez_i.bash"

# NOTE: Load json-like. It gives BASH the nested objects and arrays it does not
# have, which is what the pipeline's model is built out of. Before it, the same
# data lived in flat arrays where position "i" was a path, "i+1" an upscale
# factor and "i+2" a resize - unreadable and easy to get wrong.
# [Ref(s).: https://github.com/eduardolucioac/json-like ]
. "$SCRIPT_DIR/json-like/json-like.bash"

# NOTE: Load configurations.
#
# "config.bash" is the user's own and is deliberately NOT part of this
# project: it holds paths that belong to one machine. What the project
# carries is "config_model.bash", to be copied once.
#
# Checked rather than assumed, because sourcing a file that is not there
# does not stop BASH: it carries on with every setting empty, and what the
# user sees is a stream of "is not a number of logs to keep" instead of the
# one sentence that would have fixed it. By Questor
if [ ! -f "$SCRIPT_DIR/config.bash" ]; then
    echo "ERROR! There is no \"config.bash\" in \"$SCRIPT_DIR\".

Copy the template and set your game folder in it:

    cp \"$SCRIPT_DIR/config_model.bash\" \"$SCRIPT_DIR/config.bash\"
" >&2
    exit 1
fi
. "$SCRIPT_DIR/config.bash"


# > -----------------------------------------
# Make the configured game paths match what is really on disk.

RESOLVED_PATH=""
function f_resolve_ci(){
    : 'Rewrite a path so each segment matches what is on disk, ignoring case.

    ARGUMENTS
        $1 - string, required. The path to resolve.

    RETURNS
        "RESOLVED_PATH" (string) - The same path, with every segment that
             EXISTS replaced by its real name on disk. A segment that does not
             exist is kept exactly as it was written.

    CS 1.6 is a Windows game and Windows paths are case INSENSITIVE, so an
    installation is perfectly entitled to hold "Cstrike/GFX/Env" while the
    configuration, and every document about the game, says "cstrike/gfx/env".
    On Linux those are different folders and the second one simply is not
    there.

    What that costs without this is not a clean failure but a MISLEADING one:
    "gfx/env" not existing makes every skybox side come back missing, and the
    script says no WAD provides them - when the files are there and only the
    name differs. Worse, "mkdir -p" would then CREATE a second "gfx" beside
    the real "GFX".

    Segments that do not exist are left alone on purpose: "_upscaled" is a
    folder this script is about to create, and it has to be created with the
    name the configuration asked for.

    When BOTH spellings are present - "gfx" and "GFX" side by side - the
    first one listed wins, and that is accepted. Windows cannot produce that
    situation at all, since it will not hold two names differing only in
    case at the same level; it can only come from copying the tree onto a
    case sensitive filesystem, where it was already ambiguous before this
    script ever ran.
    '

    local path=$1
    local current=""
    local segment=""
    local found=""
    local entry=""
    local -a parts=()

    case "$path" in
        /*) current="" ;;
        *)  current="." ;;
    esac
    ez_i.split parts "$path" "/"

    local i=0
    for ((i=0;i<${#parts[*]};i++)); do
        segment="${parts[$i]}"
        if [ -z "$segment" ]; then
            continue
        fi
        if [ -e "$current/$segment" ]; then
            current="$current/$segment"
            continue
        fi
        found=""
        while IFS= read -r entry; do
            if [ "${entry,,}" == "${segment,,}" ]; then
                found="$entry"
                break
            fi
        done < <(ls -1 "$current" 2> /dev/null)
        if [ -n "$found" ]; then
            current="$current/$found"
        else
            current="$current/$segment"
        fi
    done
    RESOLVED_PATH="${current#./}"
}

# NOTE: Done here, before anything derives a path from these, so that the
# whole script works with the names the disk actually has.
f_resolve_ci "$WORK_FOLDER_CSTRIKE" ; WORK_FOLDER_CSTRIKE="$RESOLVED_PATH"
f_resolve_ci "$WORK_FOLDER_MAPS"    ; WORK_FOLDER_MAPS="$RESOLVED_PATH"
f_resolve_ci "$WORK_FOLDER_DETAIL"  ; WORK_FOLDER_DETAIL="$RESOLVED_PATH"
f_resolve_ci "$WORK_FOLDER_ENV"     ; WORK_FOLDER_ENV="$RESOLVED_PATH"

# NOTE: The relative forms are what goes INTO the "*_extra.txt" files, so
# they are kept in step with the folders that were actually used.
f_resolve_ci "$WORK_FOLDER_CSTRIKE/$UPSCALED_DETAIL_REL"
UPSCALED_DETAIL_REL="${RESOLVED_PATH#"$WORK_FOLDER_CSTRIKE/"}"
f_resolve_ci "$WORK_FOLDER_CSTRIKE/$UPSCALED_ENV_REL"
UPSCALED_ENV_REL="${RESOLVED_PATH#"$WORK_FOLDER_CSTRIKE/"}"

# < -----------------------------------------

# NOTE: The native BSP/WAD3 reader. It replaced "ripent.exe", "HLExtract.exe",
# Automatic Detail Texture Generator 2007 and, with them, Wine.
ASSETS_TOOL="$SCRIPT_DIR/tools/cs16_assets.py"

# NOTE: Where the work in progress lives. Everything in here is disposable:
# losing it costs time, never results.
FAILSAFE_DIR="$SCRIPT_DIR/__FAILSAFE__"
SCAN_FILE="$FAILSAFE_DIR/scan.json"
WORK_DIR="$FAILSAFE_DIR/_WORK"
SOURCE_DIR="$WORK_DIR/_SOURCE"
UPSCALED_DIR="$WORK_DIR/_UPSCL"

# NOTE: Final destinations, absolute.
FINAL_DETAIL_DIR="$WORK_FOLDER_CSTRIKE/$UPSCALED_DETAIL_REL"
FINAL_ENV_DIR="$WORK_FOLDER_CSTRIKE/$UPSCALED_ENV_REL"

# NOTE: Set by "f_check_requirements"; ImageMagick 7 renamed "convert" to
# "magick" and the old name now prints a deprecation warning to stderr, which
# this script would otherwise read as a failure.
MAGICK_BIN=""

# > --------------------------------------------------------------------------
# Log management.
# --------------------------------------

# > -----------------------------------------
# Delete all log files but the most recent "LOGS_KEEP" files.

# [Ref(s).: https://stackoverflow.com/a/34862475/3223785 ,
# https://stackoverflow.com/a/73465873/3223785 ,
# https://stackoverflow.com/a/3572628/3223785 ,
# https://stackoverflow.com/a/6364244/3223785 ]
function f_clean_old_logs(){
    : 'Delete all log files but the most recent "LOGS_KEEP" files.'

    local log_kind=""
    for log_kind in "output" "error"; do
        ez_i.clean_old_logs "$SCRIPT_DIR/logs/$log_kind" "$LOGS_KEEP"
    done
}

# NOTE: Clears old logs regardless of the reason the script was terminated.
ez_i.trap_add "f_clean_old_logs" SIGINT SIGTERM ERR EXIT

# < -----------------------------------------

# > -----------------------------------------
# Allows you to manage script logs easily.

OUTPUT_LOG_FILE=""
ERROR_LOG_FILE=""
function f_manage_logs(){
    : 'Allows you to manage script logs easily.

    ARGUMENTS
        $1 - string, required. Value to be inserted in the log.
        $2 - string, required. "o" - Output log; "e" - Error log.
        $3 - integer, optional. 0 - Do NOT print the message on screen;
             1 - PRINT the message on screen. Default 0.
    '

    local message=$1
    local log_type=$2
    local on_screen=$3
    if [ -z "$on_screen" ]; then
        on_screen=0
    fi
    case "$log_type" in
        "o") # Output
            if [ -z "$OUTPUT_LOG_FILE" ]; then
                ez_i.log OUTPUT_LOG_FILE "$message" 0 "new" \
                    "$SCRIPT_DIR/logs/output" "$on_screen"
            else
                ez_i.log "" "$message" 0 "$OUTPUT_LOG_FILE" "" "$on_screen"
            fi
        ;;
        "e") # Error
            if [ -z "$ERROR_LOG_FILE" ]; then
                ez_i.log ERROR_LOG_FILE "$message" 1 "new" \
                    "$SCRIPT_DIR/logs/error" "$on_screen"
            else
                ez_i.log "" "$message" 1 "$ERROR_LOG_FILE" "" "$on_screen"
            fi
        ;;
        *)
            local error_now="Invalid option! (f_manage_logs)"
            f_manage_logs "$error_now" "e"
            ez_i.error_exit "$error_now"
        ;;
    esac
}

# < -----------------------------------------

# > -----------------------------------------
# Log an error and stop.

function f_fail(){
    : 'Log an error and stop the script.

    ARGUMENTS
        $1 - string, required. What went wrong, and anything that helps fix it.
    '

    local message=$1
    ez_i.progress "o"
    f_manage_logs "$message" "e"
    ez_i.error_exit "$message"
}

# < -----------------------------------------

# > -----------------------------------------
# Run a command, stopping the script if it fails.

# NOTE: This replaces the eight line "check stderr, check exit code, build a
# message, log it, exit" block that used to be copied after every single
# external command in this script.
RUN_OUTPUT=""
function f_run(){
    : 'Run a command and stop the script if it fails.

    ARGUMENTS
        $1 - string, required. Command line to run. It is evaluated, so every
             path in it must already be quoted.
        $2 - string, required. What was being attempted, for the error message.
        $3 - integer, optional. 1 - Anything on stderr is a failure; 0 - Only a
             non zero exit code is. Default 1.

    RETURNS
        "RUN_OUTPUT" (string) - What the command wrote to stdout.
        "RUN_RESULT" (associative array) - The whole result, as "ez_i.run"
             fills it in.
    '

    local command=$1
    local context=$2
    local error_on_stderr=$3
    if [ -z "$error_on_stderr" ]; then
        error_on_stderr=1
    fi
    declare -gA RUN_RESULT=()
    ez_i.run RUN_RESULT "$command"
    RUN_OUTPUT="${RUN_RESULT[stdout]}"
    if [ "${RUN_RESULT[status]}" -gt 0 ] \
        || { [ ${error_on_stderr} -eq 1 ] && [ -n "${RUN_RESULT[stderr]}" ]; }; then
        f_fail "$context
EXIT CODE: ${RUN_RESULT[status]}
ERROR: ${RUN_RESULT[both]}
COMMAND: $command"
    fi
}

# < -----------------------------------------

# > -----------------------------------------
# Displays an additional warning and adds a log entry if the user cancels execution
# with Ctrl+c.

# [Ref(s).: https://opensource.com/article/20/6/bash-trap ]
function f_canceled_by_user(){
    : 'Displays an additional warning and adds a log entry if the user cancels
    execution with Ctrl+c.
    '

    f_manage_logs " > The execution was terminated!
CAUSE: Canceled by user." "o"
    ez_i.okay_exit "Canceled by user.
Run this script again to resume where it left off."
}

ez_i.trap_add "f_canceled_by_user" SIGINT

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Start.
# --------------------------------------

f_manage_logs " > UPSCALER-CS16 - UpScaler CS 1.6 started." "o"

read -r -d '' TITLE << "HEREDOC"
UPSCALER-CS16 - UpScaler CS 1.6
HEREDOC

# NOTE: For versioning use "MAJOR.MINOR.REVISION".
# [Ref(s).: http://programmers.stackexchange.com/questions/24987/what-exactly-is-the-build-number-in-major-minor-buildnumber-revision ]
read -r -d '' VERSION << "HEREDOC"
0.2.0
HEREDOC

read -r -d '' ABOUT << "HEREDOC"
Welcome to UpScaler CS 1.6!
Upscale (increase resolution) your CS 1.6 maps!
This script, basically, is compatible with any Desktop Linux distribution.
HEREDOC

read -r -d '' WARNINGS << "HEREDOC"
- We INSTRUCT you...
    READ the README.md.
    INSTALL ALL NECESSARY DEPENDENCIES. The script checks for them before it
        starts and tells you exactly what is missing.
    Although this is not mandatory, BACKUP ALL YOUR DATA!
    Make sure you have ENOUGH FREE SPACE on your hard drive.
    TO CANCEL the process at any time use Ctrl+c. The run RESUMES where it
        left off the next time you start it.

- We NOTICE you...
    IMAGE UPSCALING IS A LONG PROCESS that uses a lot of computational
        resources. IT CAN TAKE HOURS; depending on your machine and on the
        number of maps (*.bsp) to be processed.
    Each distinct image is upscaled ONCE, no matter how many maps use it, so
        a second map that shares textures with the first costs almost nothing.
    Results DEPEND ON THE QUALITY OF YOUR MAPS. Maps with very small or bad
        textures will not have good results. Don't expect a miracle. But in
        general we will have BETTER DEFINITION AND CLARITY of textures.
    Nothing else in "cstrike" is touched beyond the three things below, and
        every one of them is BACKED UP as a ".tar.gz" before anything happens.
        - MOVED OUT of "cstrike", into that backup: whatever "gfx/detail" already
            held. Those are the old per map detail folders, and they are replaced
            by the upscaled images.
        - REMOVED from "cstrike", after its replacement is written and once it
            is in that backup: each "maps/<map>_detail.txt". It points at the per
            map folders that just moved away, so leaving it would have the engine
            chase files that are not there.
        - COPIED, and left where it is: "gfx/env".
    IMPORTANT: with REDO_ALL set to 1 in "config.bash", the upscaled images
        of an earlier run are DELETED so that everything can be made again.
        Nothing else is, and the backups are never touched.

- We WARNING you...
    THIS SCRIPT AND RESULTING PRODUCTS COMES WITH ABSOLUTELY NO WARRANTY! USE AT
    YOUR OWN RISK! WE ARE NOT RESPONSIBLE FOR ANY DAMAGE TO YOURSELF, HARDWARE, OR
    OTHERS!
HEREDOC

read -r -d '' COMPANY << "HEREDOC"
UpScaler CS 1.6 🄯 BSD-3-Clause
Eduardo Lúcio Amorim Costa
Brazil-ES
https://www.linkedin.com/in/eduardo-software-livre/
Transforming people's lives through open-source software (OSS)!
HEREDOC

TUX=$(cat "$SCRIPT_DIR/tux.txt")
ez_i.start "" "$TITLE" "$VERSION" "$ABOUT$TUX" "$WARNINGS" "$COMPANY"

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Terms and license.
# --------------------------------------

# NOTE: Read explicitly rather than with a bare "cat", so a missing file
# stops the script here instead of presenting an EMPTY licence for the user
# to accept.
if [ ! -f "$SCRIPT_DIR/complete_license.txt" ]; then
    echo "ERROR! \"complete_license.txt\" is missing from \"$SCRIPT_DIR\"." >&2
    exit 1
fi
LICENSE_TERMS=$(cat "$SCRIPT_DIR/complete_license.txt")
ez_i.terms "$LICENSE_TERMS"

f_manage_logs " > Terms and license accepted." "o" 1

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Check that everything the run needs is present.
# --------------------------------------

# > -----------------------------------------
# Check that everything the run needs is present.

function f_check_requirements(){
    : 'Check every external program and folder the run needs.

    Everything missing is collected and reported at once, rather than failing
    on the first one and making the user discover them one at a time.
    '

    ez_i.progress "a" " > Checking requirements..."
    local problems=""

    # NOTE: ImageMagick 7 renamed "convert" to "magick" and made the old name
    # print a deprecation warning TO STDERR. Since this script treats stderr
    # as failure, using "convert" on a current distribution would abort the
    # run on the very first image.
    if command -v magick > /dev/null 2>&1; then
        MAGICK_BIN="magick"
    elif command -v convert > /dev/null 2>&1; then
        MAGICK_BIN="convert"
    else
        problems="$problems
    ImageMagick (\"magick\", or \"convert\" on version 6)"
    fi

    if ! command -v python3 > /dev/null 2>&1; then
        problems="$problems
    Python 3 (\"python3\")"
    else
        if ! python3 -c "import PIL, numpy" > /dev/null 2>&1; then
            problems="$problems
    The Python modules Pillow and NumPy (\"python-pillow\", \"python-numpy\")"
        fi
    fi

    if ! command -v "$REALESRGAN_BIN" > /dev/null 2>&1; then
        problems="$problems
    The upscaler \"$REALESRGAN_BIN\" (see REALESRGAN_BIN in \"config.bash\")"
    fi

    if [ ${PNG_COMPRESS_LEVEL} -ne -1 ] && ! command -v oxipng > /dev/null 2>&1; then
        problems="$problems
    \"oxipng\" (or set PNG_COMPRESS_LEVEL=-1 in \"config.bash\")"
    fi

    local folder=""
    for folder in "$WORK_FOLDER" "$WORK_FOLDER_CSTRIKE" "$WORK_FOLDER_MAPS"; do
        if ! ez_i.exists "" "d" "$folder"; then
            problems="$problems
    The folder \"$folder\" (check the paths in \"config.bash\")"
        fi
    done

    if ! ez_i.exists "" "f" "$ASSETS_TOOL"; then
        problems="$problems
    The asset reader \"$ASSETS_TOOL\""
    fi

    ez_i.progress "o"
    if [ -n "$problems" ]; then
        f_fail "Some things this run needs are missing:
$problems"
    fi
    f_manage_logs " > Requirements checked (ImageMagick: \"$MAGICK_BIN\", upscaler: \"$REALESRGAN_BIN\")." "o" 1
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Work out what has to be done.
# --------------------------------------

# > -----------------------------------------
# Scan the maps and build the model of the whole run.

# NOTE: "SCAN" holds the id of the json-like object every other function
# reads the run out of: which maps there are, which textures each of them
# needs, where the pixels of each distinct image live and what it has to be
# upscaled by.
SCAN=""
function f_scan_assets(){
    : 'Read every BSP and build the model of the whole run.

    The BSP of a map carries the exact list of the textures that map uses, so
    nothing here has to guess which WADs matter: only the few texture names a
    map leaves external are ever looked up in them.

    The WADs of the mod are searched first and those of the base game
    ("WORK_FOLDER_VALVE") after them, which is the order the engine itself
    searches in.
    '

    ez_i.progress "a" " > Scanning maps..."
    mkdir -p "$FAILSAFE_DIR"

    local black_list_arg=""
    if ez_i.exists "" "f" "$SCRIPT_DIR/black_list.txt"; then
        black_list_arg=" --black-list \"$SCRIPT_DIR/black_list.txt\""
    fi
    local try_max_px_arg=""
    if [ ${TRY_MAX_PX} -eq 1 ]; then
        try_max_px_arg=" --try-max-px"
    fi
    local keep_engine_arg=""
    if [ ${SKIP_ENGINE_TEXTURES} -eq 0 ]; then
        keep_engine_arg=" --keep-engine-textures"
    fi
    local wad_last_arg=""
    if [ ${WAD_LAST_WINS} -eq 1 ]; then
        wad_last_arg=" --wad-last-wins"
    fi

    # NOTE: The base game is handed over as well, and only if it is really
    # there: the WADs a stock installation keeps in "valve" and not in
    # "cstrike" are read from it, after the ones the mod carries.
    local valve_arg=""
    if [ -n "$WORK_FOLDER_VALVE" ] && ez_i.exists "" "d" "$WORK_FOLDER_VALVE"; then
        valve_arg=" --valve \"$WORK_FOLDER_VALVE\""
    fi

    f_run "python3 \"$ASSETS_TOOL\" scan \
--maps \"$WORK_FOLDER_MAPS\" \
--cstrike \"$WORK_FOLDER_CSTRIKE\"$valve_arg \
--env \"$WORK_FOLDER_ENV\" \
--target-px $TARGET_MAX_PX \
--factors \"$UPSCALE_FACTORS\" \
--hash-length $HASH_LENGTH\
$try_max_px_arg$keep_engine_arg$wad_last_arg$black_list_arg \
> \"$SCAN_FILE\"" "An error occurred while scanning the maps!"

    ez_i.progress "o"
    f_manage_logs " > Maps scanned." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Load the scan into the json-like model.

function f_load_scan(){
    : 'Load the scan file into the json-like object every step reads from.

    RETURNS
        "SCAN" (string) - The id of the json-like object holding the scan.
    '

    ez_i.progress "a" " > Loading the scan..."
    if [ -n "$SCAN" ]; then
        json_like.unset_obj SCAN
    fi
    json_like.from_json SCAN < "$SCAN_FILE" || {
        f_fail "The scan file could not be read!
FILE: $SCAN_FILE
Delete it and run this script again to start a fresh scan."
    }
    ez_i.progress "o"
}

# < -----------------------------------------

# > -----------------------------------------
# Read one value out of the model.

# NOTE: A thin wrapper so that a missing path is a script failure with a
# useful message rather than a silent empty string.
MODEL_VALUE=""
function f_model(){
    : 'Read one value out of the scan model.

    ARGUMENTS
        $@ - string, required. The path to the value, one argument per level
             of the model.

    RETURNS
        "MODEL_VALUE" (string) - The value that path leads to.
    '

    MODEL_VALUE=""
    json_like.get MODEL_VALUE "$SCAN" "$@" 2> /dev/null || {
        f_fail "The scan model has no \"$*\"!
This should not happen; please report it with the log below.
SCAN: $SCAN_FILE"
    }
}

# NOTE: Same, for the length of an array in the model.
MODEL_LENGTH=0
function f_model_length(){
    : 'Read the length of an array in the scan model.

    ARGUMENTS
        $@ - string, required. The path to the array, one argument per level
             of the model.

    RETURNS
        "MODEL_LENGTH" (integer) - How many elements that array has.
    '

    MODEL_LENGTH=0
    json_like.get_length MODEL_LENGTH "$SCAN" "$@" 2> /dev/null || {
        MODEL_LENGTH=0
    }
}

# < -----------------------------------------

# > -----------------------------------------
# Report what the scan found and confirm the disk consumption.

# NOTE: How many bytes a finished pixel costs on disk, give or take. Only
# used for the estimate shown to the user.
#
# 1.48 is MEASURED: a full run over the five map sample produced 320964608
# pixels in 0.44 GB. The 1 that stood here before was a guess, and it
# understated the real consumption by nearly half.
#
# BASH has no floating point, so the arithmetic goes through "awk", the same
# way "ez_i.convert_bytes" and the comparison further down already do.
BYTES_PER_PIXEL=1.48

function f_review_scan(){
    : 'Report what the scan found, stop on anything missing and have the user
    confirm the disk consumption.
    '

    local maps=0 images=0 sky=0 refs=0 unresolved=0 sky_missing=0
    local blacklisted=0 pixels=0
    f_model "totals" "maps";           maps=$MODEL_VALUE
    f_model "totals" "images";         images=$MODEL_VALUE
    f_model "totals" "sky";            sky=$MODEL_VALUE
    f_model "totals" "texture_refs";   refs=$MODEL_VALUE
    f_model "totals" "unresolved";     unresolved=$MODEL_VALUE
    f_model "totals" "sky_missing";    sky_missing=$MODEL_VALUE
    f_model "totals" "blacklisted";    blacklisted=$MODEL_VALUE
    f_model "totals" "output_pixels";  pixels=$MODEL_VALUE

    if [ ${maps} -eq 0 ]; then
        f_fail "No maps (*.bsp) were found!
FOLDER: $WORK_FOLDER_MAPS
Are the paths in \"config.bash\" correct?"
    fi

    # NOTE: Report every name a map needs and nothing provides, and every
    # missing skybox side, before deciding whether to stop.
    f_report_missing

    # NOTE: Report the texture names more than one of a map's WADs carries,
    # so the user can check the ones that actually matter.
    f_report_ambiguous

    local disk_kb=""
    disk_kb=$(awk '{printf("%.0f\n", ($1 * $2) / 1024)}' \
        <<< "$pixels $BYTES_PER_PIXEL")
    local disk_gb=""
    ez_i.convert_bytes disk_gb "$disk_kb" "KB" "GB"
    local free_kb=$(df -Pk "$WORK_FOLDER" | tail -1 | awk '{print $4}')
    local free_gb=""
    ez_i.convert_bytes free_gb "$free_kb" "KB" "GB"
    local disk_warning=""
    if (( $(echo $disk_gb $free_gb | awk '{if ($1 > $2) print 1;}') )); then
        disk_warning=" (!!! DISK SPACE WARNING !!!)"
    fi

    f_manage_logs " > Scan: $maps map(s), $refs texture reference(s) resolving to \
$images distinct image(s) and $sky distinct \"skyname\" side(s). \
$blacklisted blacklisted, $unresolved unresolved, $sky_missing \"skyname\" side(s) missing." "o" 1

    ez_i.divider
    ez_i.ask_yes_no "" "Your $maps map(s) use $refs textures, which $images are DISTINCT
images (plus $sky distinct \"skyname\" sides). Each distinct image is upscaled
once, so that is all the work there is.

This will use APPROXIMATELY $disk_gb GB on your disk.
Your free disk space is $free_gb GB$disk_warning.
Is this OK for you?" || ez_i.okay_exit "Canceled by user."
    f_manage_logs " > Disk consumption accepted (APPROXIMATELY $disk_gb GB)." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Report anything a map needs and nothing provides.

function f_report_missing(){
    : 'Log every unresolved texture and every missing "skyname" side, and stop
    if "STOP_WAD_SKYNAME_MISSING" says to.
    '

    local map_count=0 map_name="" item="" problems=0
    local i=0 j=0
    f_model_length "map_order"
    map_count=$MODEL_LENGTH
    for ((i=0;i<=$((map_count-1));i++)); do
        f_model "map_order" "$i"
        map_name=$MODEL_VALUE

        f_model_length "maps" "$map_name" "unresolved"
        for ((j=0;j<=$((MODEL_LENGTH-1));j++)); do
            json_like.get item "$SCAN" "maps" "$map_name" "unresolved" "$j" 2> /dev/null || continue
            problems=1
            f_manage_logs "A texture a map needs is in no WAD!
TEXTURE: $item
MAP: $map_name" "e"
        done

        f_model_length "maps" "$map_name" "sky_missing"
        for ((j=0;j<=$((MODEL_LENGTH-1));j++)); do
            json_like.get item "$SCAN" "maps" "$map_name" "sky_missing" "$j" 2> /dev/null || continue
            problems=1
            f_model "maps" "$map_name" "skyname"
            f_manage_logs "A \"skyname\" file (TGA) is missing!
TGA: $WORK_FOLDER_ENV/${MODEL_VALUE}${item}.tga (use a case-insensitive path)
MAP: $map_name" "e"
        done
    done

    # NOTE: ASKED, not refused. A map works perfectly well without every WAD
    # its "wad" key lists - those are the author'"'"'s build time paths, and most
    # of what they name is either embedded in the BSP or simply unused. A
    # name nothing provides usually means one texture of one map keeps the
    # one it has now, which is worth being TOLD and is not worth refusing to
    # run over.
    #
    # Nobody to answer means NO: an incomplete map is not something to be
    # agreed to by an empty terminal. By Questor
    if [ ${problems} -eq 1 ] && [ ${STOP_WAD_SKYNAME_MISSING} -eq 1 ]; then
        ez_i.divider
        ez_i.ask_yes_no "" "There is/are texture(s) and/or \"skyname\" file(s) that no WAD and
no \"gfx/env\" provides. EVERY ONE OF THEM IS LISTED IN THE ERROR LOG.

The maps that need them come out incomplete: those textures keep the ones
they have now, and everything else is still upscaled. If all your maps load
and look right as they are, the names are very likely unused and this costs
you nothing.

ERROR_LOG: $ERROR_LOG_FILE

Carry on anyway?" "" 0 \
            || f_fail "Stopped because of the missing texture(s) and/or \"skyname\" file(s).

Set STOP_WAD_SKYNAME_MISSING=0 in \"config.bash\" to stop being asked.

ERROR_LOG: $ERROR_LOG_FILE"
        f_manage_logs " > Missing texture(s)/\"skyname\" file(s) accepted by \
the user; the maps that need them will be incomplete." "o" 1
    fi
}

# < -----------------------------------------

# > -----------------------------------------
# Report texture names carried by more than one of a map's WADs.

function f_report_ambiguous(){
    : 'Log every texture name that more than one WAD of a map carries.

    Which of them the engine actually uses is not something this script can
    know for certain, so each one is reported rather than silently decided.
    See WAD_LAST_WINS in "config.bash".
    '

    local count=0 map_name="" texture="" used=""
    local i=0
    f_model_length "ambiguous"
    count=$MODEL_LENGTH
    if [ ${count} -eq 0 ]; then
        return
    fi
    for ((i=0;i<=$((count-1));i++)); do
        json_like.get map_name "$SCAN" "ambiguous" "$i" "map" 2> /dev/null || continue
        json_like.get texture "$SCAN" "ambiguous" "$i" "texture" 2> /dev/null || continue
        json_like.get used "$SCAN" "ambiguous" "$i" "used" 2> /dev/null || continue
        f_manage_logs " > Texture name carried by more than one WAD: \"$texture\" \
(map \"$map_name\"), taken from \"$used\" (WAD_LAST_WINS=$WAD_LAST_WINS)." "o"
    done
    f_manage_logs " > $count texture name(s) are carried by more than one WAD; \
see the output log." "o" 1
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Back up what the run modifies.
# --------------------------------------

# > -----------------------------------------
# Back up what the run modifies.

# [Ref(s).: https://unix.stackexchange.com/a/154819/61742 ,
# https://stackoverflow.com/a/5241677/3223785 ,
# https://unix.stackexchange.com/a/714059/61742 ,
# https://stackoverflow.com/a/53228677/3223785 ]
declare -a BACKUPS=()
function f_backup_files_n_folders(){
    : 'Back up the "detail" and "env" folders and the "*_detail.txt" files.

    These are the only things the run touches. WAD files are only ever read,
    so unlike the old pipeline - which deleted the ones it thought unused -
    there is nothing to back up for them.
    '

    f_backup_folder "$WORK_FOLDER_DETAIL" "\"detail\" folder" 1 \
        "$(basename "$UPSCALED_DETAIL_REL")"
    f_backup_folder "$WORK_FOLDER_ENV" "\"env\" folder" 0 \
        "$(basename "$UPSCALED_ENV_REL")"

    # NOTE: The "*_detail.txt" files are not a folder, so they are gathered
    # into one first.
    #
    # Counted BEFORE anything is created: a run after the first finds none of
    # them - the first run wrote the "*_extra.txt" that replace them and took
    # them away - and a backup of nothing is an empty tarball and a log line
    # claiming work that did not happen.
    local detail_txt_count=0
    detail_txt_count=$(find "$WORK_FOLDER_MAPS" -maxdepth 1 -type f \
        -iname "*_detail.txt" | wc -l)
    if [ ${detail_txt_count} -eq 0 ]; then
        f_manage_logs " > Backup of (\"maps\" folder) \"*_detail.txt\" files \
skipped; there are none." "o" 1
        return
    fi
    ez_i.progress "a" " > Backing up (\"maps\" folder) \"*_detail.txt\" files..."
    declare -A backup_at=()
    ez_i.backup backup_at "${WORK_FOLDER_MAPS}_detail" 0 1
    mkdir -p "${backup_at[full]}"
    find "$WORK_FOLDER_MAPS" -maxdepth 1 -type f -iname "*_detail.txt" \
        -exec cp -t "${backup_at[full]}/" {} +
    f_compress_backup "${backup_at[path]}" "${backup_at[name]}"
    ez_i.progress "o"
    f_manage_logs " > Backup of (\"maps\" folder) \"*_detail.txt\" files done \
($detail_txt_count file(s))." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Back up one folder.

function f_backup_folder(){
    : 'Back up what the USER had in one folder, as a compressed tarball.

    ARGUMENTS
        $1 - string, required. Folder to back up.
        $2 - string, required. How to name it in the messages.
        $3 - integer, required. 1 - Take the original material out of the
             folder; 0 - Copy it and leave it where it is.
        $4 - string, required. Name of ONE entry, directly inside the folder
             of $1, that is never backed up and never moved.

    RETURNS
        "BACKUPS" (array) - The tarball just written is appended to it.

    IMPORTANT: What $4 leaves out is what this script itself produces -
    "_upscaled", which lives INSIDE the folders being backed up. Without it a
    second run takes the output of the first for material of your own: it sweeps
    hundreds of megabytes into a tarball, empties the folder, and then spends
    the whole upscale again rebuilding exactly what it just threw away.
    A backup is for what the user brought, never for what we made.
    '

    local folder=$1
    local label=$2
    local clear=$3
    local exclude=$4
    if ! ez_i.exists "" "d" "$folder"; then
        f_manage_logs " > Backup of $label skipped; it does not exist." "o" 1
        return
    fi
    ez_i.progress "a" " > Backing up $label..."
    declare -A backup_at=()

    # NOTE: "name only", so nothing is moved yet; what goes into the backup
    # is chosen entry by entry below.
    ez_i.backup backup_at "$folder" 0 1

    if [ ${clear} -eq 1 ]; then
        mkdir -p "${backup_at[full]}"
        local moved=0
        local entry=""
        local entry_count=0
        entry_count=$(find "$folder" -mindepth 1 -maxdepth 1 | wc -l)
        while IFS= read -r -d '' entry; do
            if [ -n "$exclude" ] && [ "$(basename "$entry")" == "$exclude" ]; then
                continue
            fi
            mv -f "$entry" "${backup_at[full]}/"
            moved=1
        done < <(find "$folder" -mindepth 1 -maxdepth 1 -print0)
        if [ ${moved} -eq 0 ]; then
            rmdir "${backup_at[full]}" 2> /dev/null
            ez_i.progress "o"

            # NOTE: An empty folder and a folder holding only our own output
            # both have nothing to back up, but they are not the same thing
            # and the log should not pretend they are.
            if [ ${entry_count} -eq 0 ]; then
                f_manage_logs " > Backup of $label skipped; it is empty." "o" 1
            else
                f_manage_logs " > Backup of $label skipped; everything in \
it was made by this script, so there is nothing of yours to save." "o" 1
            fi
            return
        fi
        f_compress_backup "${backup_at[path]}" "${backup_at[name]}"
    else
        local base_name=""
        base_name="$(basename "$folder")"
        local exclude_arg=""
        if [ -n "$exclude" ]; then
            exclude_arg=" --exclude \"./$base_name/$exclude\""
        fi
        cd "${backup_at[path]}" || f_fail "Cannot enter \"${backup_at[path]}\"!"
        f_run "tar -czf \"${backup_at[name]}.tar.gz\"$exclude_arg \
--transform \"s|^\./$base_name|${backup_at[name]}|\" \"./$base_name\"" \
            "An error occurred while compressing the backup of $label!"
        cd "$SCRIPT_DIR" || f_fail "Cannot return to \"$SCRIPT_DIR\"!"
        BACKUPS+=("${backup_at[path]}/${backup_at[name]}.tar.gz")
    fi
    ez_i.progress "o"
    f_manage_logs " > Backup of $label done." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Compress a backup folder and remove the uncompressed copy.

function f_compress_backup(){
    : 'Compress a backup folder into a tarball beside it and remove it.

    ARGUMENTS
        $1 - string, required. Folder the backup folder sits in.
        $2 - string, required. Name of the backup folder.
    '

    local backup_path=$1
    local backup_name=$2
    if [ -z "$backup_name" ]; then
        f_fail "An empty backup name was given! (f_compress_backup)"
    fi
    cd "$backup_path" || f_fail "Cannot enter \"$backup_path\"!"
    f_run "tar -czf \"$backup_name.tar.gz\" \"$backup_name\"" \
        "An error occurred while compressing the backup folder!
FOLDER: $backup_path/$backup_name"
    rm -rf "${backup_path:?}/${backup_name:?}"
    cd "$SCRIPT_DIR" || f_fail "Cannot return to \"$SCRIPT_DIR\"!"
    BACKUPS+=("$backup_path/$backup_name.tar.gz")
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Produce the images.
# --------------------------------------

# > -----------------------------------------
# Run a command while saying how far along it is.

function f_run_watched(){
    : 'Run a command, reporting progress from the files it produces.

    ARGUMENTS
        $1 - string, required. Command line to run, already quoted.
        $2 - string, required. What was being attempted, for the error message.
        $3 - integer, required. 1 - Anything on stderr is a failure; 0 - Only a
             non zero exit code is.
        $4 - string, required. Folder whose "*.png" files are counted,
             recursively.
        $5 - integer, required. How many there will be when the command is
             done.
        $6 - string, required. What to call the work in the progress line.
        $7 - string, required. Folder the shown path is written relative to.

    RETURNS
        "RUN_OUTPUT" (string) and "RUN_RESULT" (associative array) - as
             "f_run" leaves them.

    Some steps are ONE call that takes minutes - the upscaler is handed a
    whole folder, because loading its model costs far more than any single
    image. There is nothing to loop over, so there is nowhere to put the
    usual "ITEMS LEFT" line, and the screen sits still long enough to look
    stuck.

    What those steps do have is OUTPUT APPEARING AS THEY GO, so the count of
    finished files is the progress. The command runs in the background and
    the count is read off the disk while it works.
    '

    local command=$1
    local context=$2
    local error_on_stderr=$3
    local watch_dir=$4
    local expected=$5
    local label=$6
    local show_base=$7
    if [ -z "$error_on_stderr" ]; then
        error_on_stderr=1
    fi

    # NOTE: Nothing to count means nothing to watch, so the plain runner does
    # it and keeps its spinner.
    if [ -z "$expected" ] || [ ${expected} -le 0 ]; then
        f_run "$command" "$context" "$error_on_stderr"
        return
    fi

    local out_file="" err_file=""
    out_file="$(mktemp)"
    err_file="$(mktemp)"
    eval "$command" > "$out_file" 2> "$err_file" &
    local command_pid=$!

    local last_done=""

    declare -A watch_task=()
    ez_i.task_stats_init watch_task "$expected"

    # NOTE: "begin" is called again after every "end" so that each item is
    # timed from the last one. Calling them back to back would time nothing,
    # and calling "begin" once would charge every item the whole elapsed
    # time.
    ez_i.task_stats_begin watch_task
    local seen=0 current=0 stats=""
    while kill -0 "$command_pid" 2> /dev/null; do
        current=$(find "$watch_dir" -type f -name "*.png" 2> /dev/null | wc -l)
        if [ ${current} -gt ${expected} ]; then
            current=$expected
        fi
        while [ ${seen} -lt ${current} ]; do
            ez_i.task_stats_end stats watch_task
            ez_i.task_stats_begin watch_task
            seen=$((seen + 1))
        done
        if [ -t 1 ]; then

            # NOTE: The newest file in the folder is the one that has just
            # been finished. Which one is being worked on RIGHT NOW is not
            # knowable here - the upscaler is handed a whole folder and says
            # nothing about where it is - so what is shown is the last one
            # that came out, which is the honest version of the same thing.
            last_done=$(find "$watch_dir" -type f -name "*.png" -printf '%T@ %p\n' \
                2> /dev/null | sort -n | tail -1 | cut -d' ' -f2-)
            if [ -n "$last_done" ]; then
                last_done="${last_done#"$show_base/"}"
            else
                last_done="starting..."
            fi
            ez_i.progress_draw "$label" "$last_done" \
                "${stats:-ITEMS LEFT $expected/$expected (0% SO FAR)}"
        fi
        sleep 0.2
    done
    wait "$command_pid"
    local status=$?
    ez_i.progress_clear

    declare -gA RUN_RESULT=()
    RUN_RESULT[stdout]="$(cat "$out_file")"
    RUN_RESULT[stderr]="$(cat "$err_file")"
    RUN_RESULT[both]="${RUN_RESULT[stdout]}${RUN_RESULT[stderr]}"
    RUN_RESULT[status]=$status
    rm -f "$out_file" "$err_file"
    RUN_OUTPUT="${RUN_RESULT[stdout]}"
    if [ "${RUN_RESULT[status]}" -gt 0 ] \
        || { [ ${error_on_stderr} -eq 1 ] && [ -n "${RUN_RESULT[stderr]}" ]; }; then
        f_fail "$context
EXIT CODE: ${RUN_RESULT[status]}
ERROR: ${RUN_RESULT[both]}
COMMAND: $command"
    fi
}

# < -----------------------------------------

# > -----------------------------------------
# Write every distinct image the run needs, as a PNG.

function f_export_images(){
    : 'Write every distinct image the run needs out of the BSPs and WADs.

    The files go into one folder per upscale factor so that the upscaler can
    take a whole folder at a time; anything already finished is not written.
    '

    mkdir -p "$SOURCE_DIR"

    # NOTE: How many are still to be written, so the progress line counts
    # towards the right number: anything already in the final folders is
    # skipped by "--done" and never reaches "$SOURCE_DIR".
    local total_images=0 total_sky=0 already=0 pending=0
    f_model "totals" "images"; total_images=$MODEL_VALUE
    f_model "totals" "sky";    total_sky=$MODEL_VALUE
    already=$(find "$FINAL_DETAIL_DIR" "$FINAL_ENV_DIR" -type f -name "*.png" \
        2> /dev/null | wc -l)
    pending=$((total_images + total_sky - already))

    if [ ${pending} -le 0 ]; then
        ez_i.progress "a" " > Exporting images..."
    fi
    f_run_watched "python3 \"$ASSETS_TOOL\" export \
--plan \"$SCAN_FILE\" \
--out \"$SOURCE_DIR\" \
--done \"$FINAL_DETAIL_DIR\" \
--done \"$FINAL_ENV_DIR\"" "An error occurred while exporting the images!" 1 \
        "$SOURCE_DIR" "$pending" "Exporting" "$WORK_DIR"
    if [ ${pending} -le 0 ]; then
        ez_i.progress "o"
    fi
    f_manage_logs " > Images exported ($RUN_OUTPUT)." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Upscale every exported image.

function f_upscale_images(){
    : 'Upscale every exported image, one batch per upscale factor.

    The ncnn upscalers take a whole folder at a time and loading their model
    costs far more than any single image, so batching by factor means the
    model is loaded a handful of times rather than once per image.
    '

    local bucket="" factor="" out_bucket="" file="" name=""
    local in_count=0 out_count=0 total=0
    declare -a buckets=()
    while IFS= read -r -d '' bucket; do
        buckets+=("$bucket")
    done < <(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2> /dev/null)

    if [ ${#buckets[*]} -eq 0 ]; then
        f_manage_logs " > Upscaling skipped; every image is already done." "o" 1
        return
    fi

    local i=0
    for ((i=0;i<=$((${#buckets[*]}-1));i++)); do
        bucket="${buckets[$i]}"
        factor="$(basename "$bucket")"
        out_bucket="$UPSCALED_DIR/$factor"
        mkdir -p "$out_bucket"

        # NOTE: Drop anything this bucket already has an upscaled result for,
        # so an interrupted run does not redo it.
        while IFS= read -r -d '' file; do
            name="$(basename "$file")"
            if [ -f "$out_bucket/$name" ]; then
                rm -f "$file"
            fi
        done < <(find "$bucket" -maxdepth 1 -type f -name "*.png" -print0)

        in_count=$(find "$bucket" -maxdepth 1 -type f -name "*.png" | wc -l)
        if [ ${in_count} -eq 0 ]; then
            rmdir "$bucket" 2> /dev/null
            continue
        fi

        f_upscale_folder "$bucket" "$out_bucket" "$factor" "$in_count"

        out_count=$(find "$out_bucket" -maxdepth 1 -type f -name "*.png" | wc -l)
        if [ ${out_count} -lt ${in_count} ]; then
            f_fail "The upscaler did not produce every image!
FACTOR: ${factor}x
EXPECTED AT LEAST: $in_count
PRODUCED: $out_count
INPUT: $bucket
OUTPUT: $out_bucket"
        fi
        rm -rf "${bucket:?}"
        total=$((total+in_count))
        f_manage_logs " > Upscaled $in_count image(s) by ${factor}x." "o" 1
    done
    f_manage_logs " > Upscaling done ($total image(s))." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Upscale one whole folder.

# [Ref(s).: https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan#full-usages ]
function f_upscale_folder(){
    : 'Upscale every PNG in a folder into another folder.

    ARGUMENTS
        $1 - string, required. Folder of PNGs to upscale.
        $2 - string, required. Folder to write the results into.
        $3 - integer, required. Upscale factor.
        $4 - integer, required. How many images are going in, for the progress
             line.
    '

    local in_dir=$1
    local out_dir=$2
    local factor=$3
    local expected=$4
    local tta_mode=""
    if [ ${RSRGAN_ENABLE_TTA} -eq 1 ]; then
        tta_mode=" -x"
    fi

    # NOTE: The factors this can be called with come from UPSCALE_FACTORS,
    # which MUST match REALESRGAN_MODEL. Asking a fixed 4x model such as
    # "realesrgan-x4plus" for another factor is what fails with
    # "find_blob_index_by_name data failed"; there is no retry loop here
    # because the pair is a configuration question, not a runtime one.
    f_run_watched "\"$REALESRGAN_BIN\" -i \"$in_dir\" -o \"$out_dir\" \
-s $factor -n \"$REALESRGAN_MODEL\" -f png$tta_mode" \
        "An error occurred while upscaling with \"$REALESRGAN_BIN\"!
MODEL: $REALESRGAN_MODEL
FACTOR: ${factor}x
If the error mentions \"find_blob_index_by_name\", the model does not support
this factor. Check REALESRGAN_MODEL and UPSCALE_FACTORS in \"config.bash\"." 0 \
        "$out_dir" "$expected" "Upscaling by ${factor}x" "$WORK_DIR"

    # NOTE: These tools report progress on stderr and keep going past a single
    # bad file, so the exit code alone is not enough. The caller also compares
    # how many files came out against how many went in.
    if echo "${RUN_RESULT[both]}" | grep -iq "failed\|invalid\|unsupported"; then
        f_fail "The upscaler reported a problem!
OUTPUT: ${RUN_RESULT[both]}
INPUT: $in_dir"
    fi
}

# < -----------------------------------------

# > -----------------------------------------
# Resize, sharpen and compress every upscaled image into its final place.

function f_finish_images(){
    : 'Resize, sharpen and compress every upscaled image into its final place.

    The final name is the content hash of the image, which is what the
    "*_extra.txt" files point at.
    '

    local file="" hash="" factor="" resize="" target="" kind="" shown=""
    declare -a pending=()
    while IFS= read -r -d '' file; do
        pending+=("$file")
    done < <(find "$UPSCALED_DIR" -mindepth 2 -maxdepth 2 -type f -name "*.png" -print0 2> /dev/null)

    local total=${#pending[*]}
    if [ ${total} -eq 0 ]; then
        f_manage_logs " > Finishing skipped; every image is already done." "o" 1
        return
    fi

    mkdir -p "$FINAL_DETAIL_DIR" "$FINAL_ENV_DIR"
    declare -A finish_task=()
    ez_i.task_stats_init finish_task "$total"
    local task_stats=""
    local i=0
    for ((i=0;i<=$((total-1));i++)); do
        ez_i.task_stats_begin finish_task
        file="${pending[$i]}"
        hash="$(basename "$file" ".png")"

        # NOTE: A hash is either a texture or a "skyname" side, and the two go
        # to different folders.
        resize=""
        # NOTE: "SHOWN" is the same file as "TARGET", written from "cstrike"
        # down. The absolute path is over 200 characters here and the part
        # that changes is the last 20 of them, so printing it whole 534 times
        # wraps the line three deep and pushes the progress off screen. The
        # root is said once, when the run starts and when it ends.
        if json_like.get resize "$SCAN" "images" "$hash" "resize" 2> /dev/null; then
            target="$FINAL_DETAIL_DIR/$hash.png"
            shown="$UPSCALED_DETAIL_REL/$hash.png"
            kind="texture"
        elif json_like.get resize "$SCAN" "sky" "$hash" "resize" 2> /dev/null; then
            target="$FINAL_ENV_DIR/$hash.png"
            shown="$UPSCALED_ENV_REL/$hash.png"
            kind="skyname"
        else
            f_fail "An upscaled image is in no scan!
FILE: $file
This usually means \"$WORK_DIR\" is left over from a run with different
settings. Delete it and run this script again."
        fi

        # NOTE: Drawn in place, the same way the watched steps do it, so
        # that 534 items do not scroll the whole run off the screen. The log
        # FILE still gets one line each - that is what it is for.
        #
        # The work goes to the BACKGROUND so the animation keeps turning
        # while it happens. "f_finish_image" stops the script through
        # "f_fail" when it goes wrong, but from a background job that only
        # ends the job, so the status is checked here as well.
        f_finish_image "$file" "$target" "$resize" &
        ez_i.progress_wait $! "Finishing the PNG ($kind)" "$shown" "$task_stats" \
            || f_fail "An error occurred while finishing the PNG image!
FILE: $file
TARGET: $target"
        rm -f "$file"
        ez_i.task_stats_end task_stats finish_task
        ez_i.progress_draw "Finishing the PNG ($kind)" "$shown" "$task_stats"
        f_manage_logs " > PNG finished ($kind): $shown
$task_stats" "o" 0
    done
    ez_i.progress_clear
    rm -rf "${UPSCALED_DIR:?}"
    f_manage_logs " > Finishing done ($total image(s))." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Resize, sharpen and compress one image.

# [Ref(s).: https://legacy.imagemagick.org/Usage/resize/ ,
# https://www.halolinux.us/ubuntu-hacks/sharpen-images-at-the-command-line.html ,
# https://github.com/shssoichiro/oxipng ]
function f_finish_image(){
    : 'Resize, sharpen and compress one image into its final place.

    ARGUMENTS
        $1 - string, required. Upscaled image.
        $2 - string, required. Where the finished image goes.
        $3 - string, required. ImageMagick geometry, or "" for no resize.
    '

    local input_file=$1
    local output_file=$2
    local resize=$3
    local resize_param=""
    local sharpen_param=""

    if [ -n "$resize" ]; then

        # NOTE: The "!" tells ImageMagick to ignore the aspect ratio and give
        # exactly this size. It is quoted because several shells treat it
        # specially.
        resize_param=" -resize '$resize'"
    fi
    if [ ${SHARPEN_IMGS} -ne -1 ]; then
        sharpen_param=" -sharpen 0x$SHARPEN_IMGS"
    fi

    f_run "\"$MAGICK_BIN\" \"$input_file\"$resize_param$sharpen_param \"$output_file\"" \
        "An error occurred while resizing/sharpening the PNG image!
FILE: $input_file"

    if [ ${PNG_COMPRESS_LEVEL} -ne -1 ]; then
        # NOTE: "-i 0" writes a NON interlaced PNG. The old pipeline passed
        # "-i 1", which interlaces, and an interlaced PNG is typically larger
        # - the opposite of the point of running a compressor, and of no use
        # at all to a texture the engine loads whole.
        f_run "oxipng -o $PNG_COMPRESS_LEVEL -i 0 --strip safe --quiet \"$output_file\"" \
            "An error occurred while compressing the PNG image!
FILE: $output_file" 0
    fi
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Write the "*_extra.txt" files.
# --------------------------------------

# > -----------------------------------------
# Escape a string for JSON.

# NOTE: Texture names come out of a 16 byte binary field, so while a quote or
# a backslash in one would be unusual it is not impossible, and an unescaped
# one would produce an "*_extra.txt" the renderer cannot read.
JSON_ESCAPED=""
function f_json_escape(){
    : 'Escape a string so it can go inside a JSON string literal.

    ARGUMENTS
        $1 - string, required. String to escape.

    RETURNS
        "JSON_ESCAPED" (string) - The escaped string.
    '

    local value=$1
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//	/\\t}"
    JSON_ESCAPED="$value"
}

# < -----------------------------------------

# > -----------------------------------------
# Write the "*_extra.txt" files.

# NOTE: This is the file that makes everything else usable: it maps each
# texture NAME a map uses onto the hash named PNG that replaces it. Because
# the name lives here and not in the file name, two maps that share an image
# share the one file, and two different images that happen to share a name do
# not collide.
# [Ref(s).: https://stackoverflow.com/a/73628324/3223785 ]
declare -a SKY_SIDES=("rt" "bk" "lf" "ft" "up" "dn")
function f_write_extra_txt(){
    : 'Write one "*_extra.txt" (Renderer 1.5c) per map.'

    local map_count=0 map_name="" output_file=""
    local texture_count=0 sky_count=0
    local base="" hash="" side="" body="" sky_body="" separator=""
    local detail_txt="" task_stats_suffix=""
    local i=0 j=0

    f_model_length "map_order"
    map_count=$MODEL_LENGTH
    declare -A extra_task=()
    ez_i.task_stats_init extra_task "$map_count"
    local task_stats=""
    for ((i=0;i<=$((map_count-1));i++)); do
        ez_i.task_stats_begin extra_task
        f_model "map_order" "$i"
        map_name=$MODEL_VALUE
        output_file="$WORK_FOLDER_MAPS/${map_name}_extra.txt"

        # NOTE: Already there means already done, which is the rule every
        # other step follows. Building one is not free - two "json_like.get"
        # per texture - and on a big collection that is minutes of work to
        # arrive at the same bytes.
        #
        # It carries the same caveat as the images, for the same reason: the
        # file says nothing about the settings it was made under, so a
        # changed "black_list.txt" or HASH_LENGTH does not show up here by
        # itself. REDO_ALL is what applies it, and it deletes these too.
        if ez_i.exists "" "f" "$output_file"; then
            ez_i.task_stats_skip task_stats extra_task
            task_stats_suffix=" / $task_stats"
            f_manage_logs " > Extra (\"*_extra.txt\") skipped; \
maps/${map_name}_extra.txt is already there.
$task_stats" "o" 0
            continue
        fi
        body=""
        separator=""

        # > ----- the skybox, which has to come first -----
        f_model_length "maps" "$map_name" "sky"
        sky_count=$MODEL_LENGTH
        if [ ${sky_count} -gt 0 ]; then
            sky_body=""
            local sky_separator=""
            for ((j=0;j<=$((sky_count-1));j++)); do
                json_like.get side "$SCAN" "maps" "$map_name" "sky" "$j" "side" 2> /dev/null || continue
                json_like.get hash "$SCAN" "maps" "$map_name" "sky" "$j" "hash" 2> /dev/null || continue
                sky_body+="$sky_separator			\"$side\" : \"$UPSCALED_ENV_REL/$hash.png\""
                sky_separator=",
"
            done
            body+="	{\"base\" : \"sky\", \"replace\" :
		{
$sky_body
		}
	}"
            separator=",
"
        fi
        # < ----- the skybox, which has to come first -----

        # > ----- the textures -----
        f_model_length "maps" "$map_name" "texture_list"
        texture_count=$MODEL_LENGTH
        for ((j=0;j<=$((texture_count-1));j++)); do

            # NOTE: Redrawn every ten, not every one: the frames would blur
            # past on a big map, and redrawing is not free. It is the inner
            # loop that takes the time here - two "json_like.get" per texture
            # - so this is where the animation has to be driven from.
            if ((j % 10 == 0)); then
                ez_i.progress_draw "Writing the extra" "maps/${map_name}_extra.txt" \
                    "TEXTURE $((j + 1))/$texture_count$task_stats_suffix"
            fi
            json_like.get base "$SCAN" "maps" "$map_name" "texture_list" "$j" "base" 2> /dev/null || continue
            json_like.get hash "$SCAN" "maps" "$map_name" "texture_list" "$j" "hash" 2> /dev/null || continue
            f_json_escape "$base"
            body+="$separator	{\"base\" : \"$JSON_ESCAPED\", \"replace\" : \"$UPSCALED_DETAIL_REL/$hash.png\", \"replacescale\" : \"1.0 1.0\"}"
            separator=",
"
        done
        # < ----- the textures -----

        if [ -z "$body" ]; then
            ez_i.task_stats_skip task_stats extra_task
            task_stats_suffix=" / $task_stats"
            f_manage_logs " > Extra (\"*_extra.txt\") skipped; \"$map_name\" has nothing to replace.
$task_stats" "o" 0
            continue
        fi

        # NOTE: Written with MS-DOS (CRLF) line endings, which is what the
        # files this format came from use.
        printf '[\r\n%s\r\n]\r\n' "$body" | sed 's/$/\r/; s/\r\r$/\r/' > "$output_file"

        # NOTE: The "*_detail.txt" the map came with is what the engine reads
        # WITHOUT the renderer plugin, and it points at the per-map folders
        # under "gfx/detail" that the backup moved away. Leaving it would
        # have the engine chase files that are not there.
        #
        # It is REMOVED rather than renamed because it is already inside the
        # "*_detail.txt" tarball that "f_backup_files_n_folders" wrote before
        # any of this ran - the same treatment the "detail" and "env" folders
        # get. A renamed copy here would be a second one, dead, one per map.
        detail_txt="$WORK_FOLDER_MAPS/${map_name}_detail.txt"
        if [ -f "$detail_txt" ]; then
            rm -f "$detail_txt"
        fi

        ez_i.task_stats_end task_stats extra_task
        task_stats_suffix=" / $task_stats"
        ez_i.progress_draw "Writing the extra" "maps/${map_name}_extra.txt" "$task_stats"
        f_manage_logs " > Extra (\"*_extra.txt\") written: maps/${map_name}_extra.txt
TEXTURES: $texture_count / \"SKYNAME\" SIDES: $sky_count
REPLACES (AND REMOVES, IT IS IN THE BACKUP): ${map_name}_detail.txt
$task_stats" "o" 0
    done
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# MAIN SECTION:
# Control and manage script functions.
# --------------------------------------

f_check_requirements

# > -----------------------------------------
# Start everything over, when the configuration asks for it.

function f_redo_all(){
    : 'Throw away every finished image so the whole run is made again.

    REDO_ALL exists because each file is named after the content hash of
    its SOURCE texture and not after the settings used to process it. Change
    the model, the target size or the sharpening and every name stays the
    same, so each step finds its output already there and skips it: the new
    setting would have no effect at all, and nothing would say so.

    The backups are never touched.
    '

    local detail_count=0
    local env_count=0
    local extra_count=0
    detail_count=$(find "$FINAL_DETAIL_DIR" -maxdepth 1 -type f -name "*.png" \
        2> /dev/null | wc -l)
    env_count=$(find "$FINAL_ENV_DIR" -maxdepth 1 -type f -name "*.png" \
        2> /dev/null | wc -l)
    extra_count=$(find "$WORK_FOLDER_MAPS" -maxdepth 1 -type f \
        -iname "*_extra.txt" 2> /dev/null | wc -l)

    if [ $((detail_count + env_count + extra_count)) -eq 0 ]; then
        f_manage_logs " > REDO_ALL is on, but there was nothing to throw \
away." "o" 1
        return
    fi

    # NOTE: Asked even though the flag is already the answer. The flag lives
    # in a file and is easy to leave switched on, and what it costs is every
    # image of the last run plus the hours to make them again.
    ez_i.divider
    ez_i.ask_yes_no "" "REDO_ALL is 1 in \"config.bash\", so EVERYTHING IS TO BE MADE AGAIN
from the beginning.

THIS DELETES $detail_count upscaled texture(s), $env_count upscaled \"skyname\" side(s)
and $extra_count \"*_extra.txt\" file(s), and the whole run has to be done over.
YOUR BACKUPS ARE NOT TOUCHED.

Answer \"n\", set REDO_ALL back to 0, and run again to keep what is there.
Go ahead?" || ez_i.okay_exit "Canceled by user."

    ez_i.progress "a" " > Throwing away everything already produced..."
    # NOTE: The failsafe is NOT touched. By the time this runs it holds the
    # scan this very run just made, and the fresh start already removed any
    # older one. By Questor
    rm -rf "${FINAL_DETAIL_DIR:?}" "${FINAL_ENV_DIR:?}"

    # NOTE: The "*_extra.txt" go too. They are skipped when they already
    # exist, like everything else this script makes, so this is the only
    # thing that brings them back - and they are what a changed
    # "black_list.txt" or HASH_LENGTH actually shows up in.
    find "$WORK_FOLDER_MAPS" -maxdepth 1 -type f -iname "*_extra.txt" -delete \
        2> /dev/null
    ez_i.progress "o"
    f_manage_logs " > REDO_ALL is on; $detail_count texture(s), $env_count \
\"skyname\" side(s) and $extra_count \"*_extra.txt\" thrown away. Everything \
will be made again." "o" 1
}


# < -----------------------------------------

# > -----------------------------------------
# Resume an unfinished run, or start a new one.

# NOTE: The scan is the whole state of a run. Everything after it skips what
# is already on disk, so resuming is simply not scanning again.
RESUME_PROCESS=0

# NOTE: With REDO_ALL on there is nothing to resume - starting over is the
# whole point - so the question is not even put. By Questor
if [ ${REDO_ALL} -eq 0 ] && ez_i.exists "" "f" "$SCAN_FILE"; then
    ez_i.divider
    ez_i.ask_yes_no RESUME_PROCESS "There is an unfinished upscale process.
Do you want to resume it? (\"y\" highly recommended)

Resuming keeps everything already produced and carries on from there.
Starting over rescans the maps; images already finished are still not redone."
fi

if [ ${RESUME_PROCESS} -eq 1 ]; then
    f_manage_logs " > Unfinished upscale process resumed." "o" 1
    f_load_scan
else
    rm -rf "${FAILSAFE_DIR:?}"
    f_manage_logs " > Scan started." "o" 1
    f_scan_assets
    f_load_scan
    f_review_scan

    # NOTE: Here, and not before the scan. Throwing the last run away is the
    # most destructive thing this script does, and until the scan has run
    # there is no telling whether this one can go ahead at all: a missing
    # WAD or a refused disk estimate stops it. Doing it earlier would
    # destroy a finished run and then abort, leaving nothing. By Questor
    if [ ${REDO_ALL} -eq 1 ]; then
        f_redo_all
    fi
    f_manage_logs " > Backup started." "o" 1
    f_backup_files_n_folders
    ez_i.enter_to_continue "From now this script can be interrupted (use Ctrl+c) at any
time and be resumed where it left off by running it again." 10
fi

f_manage_logs " > Export images started." "o" 1
f_export_images
f_manage_logs " > Upscale images started." "o" 1
f_upscale_images
f_manage_logs " > Finish images started." "o" 1
f_finish_images
f_manage_logs " > Write extras (\"*_extra.txt\") started." "o" 1
f_write_extra_txt
ez_i.progress_clear

# NOTE: The run is complete, so the work in progress state goes away.
rm -rf "${FAILSAFE_DIR:?}"

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# End.
# --------------------------------------

# > -----------------------------------------
# List backup folders.

BACKUP_LIST=""
function f_list_backup_folders(){
    : 'Build the list of backups made by this run.

    RETURNS
        "BACKUP_LIST" (string) - One backup a line, or a note saying there
             were none because this run resumed an earlier one.
    '

    local new_line=""
    local i=0
    for ((i=0;i<=$((${#BACKUPS[*]}-1));i++)); do
        BACKUP_LIST="$BACKUP_LIST$new_line${BACKUPS[$i]}"
        new_line="
    "
    done
    if [ -z "$BACKUP_LIST" ]; then
        BACKUP_LIST="<NONE; this run resumed an earlier one>"
    fi
    f_manage_logs " > Backup folders listed." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# End message.

f_manage_logs " > UPSCALER-CS16 - UpScaler CS 1.6 finished." "o"

read -r -d '' TITLE << "HEREDOC"
UPSCALER-CS16 - UpScaler CS 1.6 finished! Thanks!
HEREDOC

f_list_backup_folders
read -r -d '' USEFUL_INFO << HEREDOC
- You need Metahook Plus 0.4 with Renderer 1.5c for the detail textures to be
 used at all.

- To enable (if necessary) the detail textures type the following commands in the
 CS 1.6 console...
    r_detailtextures 1
    r_detailtexturessupported 1
    gl_max_size 16384

- For the best result also set, in the same place...
    gl_texturemode GL_LINEAR_MIPMAP_LINEAR

- To definitely apply the above settings, they must be in the configurations file...
    $WORK_FOLDER_CSTRIKE/userconfig.cfg

- Your upscaled images...
    $FINAL_DETAIL_DIR
    $FINAL_ENV_DIR

- Your backups...
    $BACKUP_LIST
HEREDOC

ez_i.end "$TITLE" "$USEFUL_INFO"

# < -----------------------------------------

# < --------------------------------------------------------------------------

exit 0
