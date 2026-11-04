#!/bin/bash

# > -----------------------------------------
# Run that script with bash even if the user use sh/dash or any sh like interpreter.
# This way it correctly works with either: "sh ./my_script.bash" or "bash ./my_script.bash"
# or "./my_script.bash".

if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi

# < -----------------------------------------

# NOTE: Avoids problems with relative paths. By Questor
SCRIPT_DIR_S="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# NOTE: Load ez_i library (in reality a bash script). It provides a number of cool
# features for creating interactive bash scripts, including installers. By Questor
# [Ref(s).: https://github.com/eduardolucioac/ez_i ]
. "$SCRIPT_DIR_S/ez_i/ez_i.bash"

# NOTE: Load json-like. It gives BASH the nested objects and arrays it does not
# have, which is what the pipeline's model is built out of. Before it, the same
# data lived in flat arrays where position "i" was a path, "i+1" an upscale
# factor and "i+2" a resize - unreadable and easy to get wrong. By Questor
# [Ref(s).: https://github.com/eduardolucioac/json-like ]
. "$SCRIPT_DIR_S/json-like/json-like.bash"

# NOTE: Load configurations. By Questor
. "$SCRIPT_DIR_S/config.bash"

# NOTE: The native BSP/WAD3 reader. It replaced "ripent.exe", "HLExtract.exe",
# Automatic Detail Texture Generator 2007 and, with them, Wine. By Questor
ASSETS_TOOL_S="$SCRIPT_DIR_S/tools/cs16_assets.py"

# NOTE: Where the work in progress lives. Everything in here is disposable:
# losing it costs time, never results. By Questor
FAILSAFE_DIR_S="$SCRIPT_DIR_S/__FAILSAFE__"
SCAN_FILE_S="$FAILSAFE_DIR_S/scan.json"
WORK_DIR_S="$FAILSAFE_DIR_S/_WORK"
SOURCE_DIR_S="$WORK_DIR_S/_SOURCE"
UPSCALED_DIR_S="$WORK_DIR_S/_UPSCL"

# NOTE: Final destinations, absolute. By Questor
FINAL_DETAIL_DIR_S="$WORK_FOLDER_CSTRIKE_S/$UPSCALED_DETAIL_REL_S"
FINAL_ENV_DIR_S="$WORK_FOLDER_CSTRIKE_S/$UPSCALED_ENV_REL_S"

# NOTE: Set by "f_check_requirements"; ImageMagick 7 renamed "convert" to
# "magick" and the old name now prints a deprecation warning to stderr, which
# this script would otherwise read as a failure. By Questor
MAGICK_BIN_S=""

# > --------------------------------------------------------------------------
# Log management.
# --------------------------------------

# > -----------------------------------------
# Delete all log files but the most recent "LOGS_KEEP_S" files.

# [Ref(s).: https://stackoverflow.com/a/34862475/3223785 ,
# https://stackoverflow.com/a/73465873/3223785 ,
# https://stackoverflow.com/a/3572628/3223785 ,
# https://stackoverflow.com/a/6364244/3223785 ]
function f_clean_old_logs(){
    : 'Delete all log files but the most recent "LOGS_KEEP_S" files.'

    local LOG_KIND=""
    for LOG_KIND in "output" "error"; do
        ez_i.clean_old_logs "$SCRIPT_DIR_S/logs/$LOG_KIND" "$LOGS_KEEP_S"
    done
}

# NOTE: Clears old logs regardless of the reason the script was terminated. By Questor
ez_i.trap_add "f_clean_old_logs" SIGINT SIGTERM ERR EXIT

# < -----------------------------------------

# > -----------------------------------------
# Allows you to manage script logs easily.

OUTPUT_LOG_PATH_N_NAME=""
ERROR_LOG_PATH_N_NAME=""
function f_manage_logs(){
    : 'Allows you to manage script logs easily.

    Args:
        VALUE_TO_INSERT (str): Value to be inserted in the log.
        LOG_TYPE (str): "o" - Output log; "e" - Error log.
        VAL_INS_ON_SCREEN (Optional[int]): 0 - Will NOT print "VALUE_TO_INSERT" on
    screen; 1 - Will PRINT "VALUE_TO_INSERT" on screen. Default 0.
    '

    local VALUE_TO_INSERT=$1
    local LOG_TYPE=$2
    local VAL_INS_ON_SCREEN=$3
    if [ -z "$VAL_INS_ON_SCREEN" ]; then
        VAL_INS_ON_SCREEN=0
    fi
    case "$LOG_TYPE" in
        "o") # Output
            if [ -z "$OUTPUT_LOG_PATH_N_NAME" ]; then
                ez_i.log OUTPUT_LOG_PATH_N_NAME "$VALUE_TO_INSERT" 0 "new" \
                    "$SCRIPT_DIR_S/logs/output" "$VAL_INS_ON_SCREEN"
            else
                ez_i.log "" "$VALUE_TO_INSERT" 0 "$OUTPUT_LOG_PATH_N_NAME" "" "$VAL_INS_ON_SCREEN"
            fi
        ;;
        "e") # Error
            if [ -z "$ERROR_LOG_PATH_N_NAME" ]; then
                ez_i.log ERROR_LOG_PATH_N_NAME "$VALUE_TO_INSERT" 1 "new" \
                    "$SCRIPT_DIR_S/logs/error" "$VAL_INS_ON_SCREEN"
            else
                ez_i.log "" "$VALUE_TO_INSERT" 1 "$ERROR_LOG_PATH_N_NAME" "" "$VAL_INS_ON_SCREEN"
            fi
        ;;
        *)
            local ERROR_NOW="Invalid option! (f_manage_logs)"
            f_manage_logs "$ERROR_NOW" "e"
            ez_i.error_exit "$ERROR_NOW"
        ;;
    esac
}

# < -----------------------------------------

# > -----------------------------------------
# Log an error and stop.

function f_fail(){
    : 'Log an error and stop the script.

    Args:
        MESSAGE (str): What went wrong, and anything that helps fix it.
    '

    local MESSAGE=$1
    ez_i.progress "o"
    f_manage_logs "$MESSAGE" "e"
    ez_i.error_exit "$MESSAGE"
}

# < -----------------------------------------

# > -----------------------------------------
# Run a command, stopping the script if it fails.

# NOTE: This replaces the eight line "check stderr, check exit code, build a
# message, log it, exit" block that used to be copied after every single
# external command in this script. By Questor
F_RUN_R=""
function f_run(){
    : 'Run a command and stop the script if it fails.

    Args:
        COMMAND (str): Command line to run. It is evaluated, so every path in
    it must already be quoted.
        CONTEXT (str): What was being attempted, for the error message.
        ERROR_ON_STDERR (Optional[int]): 1 - Anything on stderr is a failure;
    0 - Only a non zero exit code is. Default 1.

    Returns:
        F_RUN_R (str): What the command wrote to stdout.
        F_RUN_RESULT (assoc): The whole result, as "ez_i.run" fills it in.
    '

    local COMMAND=$1
    local CONTEXT=$2
    local ERROR_ON_STDERR=$3
    if [ -z "$ERROR_ON_STDERR" ]; then
        ERROR_ON_STDERR=1
    fi
    declare -gA F_RUN_RESULT=()
    ez_i.run F_RUN_RESULT "$COMMAND"
    F_RUN_R="${F_RUN_RESULT[stdout]}"
    if [ "${F_RUN_RESULT[status]}" -gt 0 ] \
        || { [ ${ERROR_ON_STDERR} -eq 1 ] && [ -n "${F_RUN_RESULT[stderr]}" ]; }; then
        f_fail "$CONTEXT
EXIT CODE: ${F_RUN_RESULT[status]}
ERROR: ${F_RUN_RESULT[both]}
COMMAND: $COMMAND"
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

read -r -d '' TITLE_F << "HEREDOC"
UPSCALER-CS16 - UpScaler CS 1.6
HEREDOC

# NOTE: For versioning use "MAJOR.MINOR.REVISION.BUILDNUMBER". By Questor
# [Ref(s).: http://programmers.stackexchange.com/questions/24987/what-exactly-is-the-build-number-in-major-minor-buildnumber-revision ]
read -r -d '' VERSION_F << "HEREDOC"
0.2.0.0
HEREDOC

read -r -d '' ABOUT_F << "HEREDOC"
Welcome to UpScaler CS 1.6!
Upscale (increase resolution) your CS 1.6 maps!
This script, basically, is compatible with any Desktop Linux distribution.
HEREDOC

read -r -d '' WARNINGS_F << "HEREDOC"
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
    NOTHING in your "cstrike" folder is deleted or overwritten by this script
        except the "*_detail.txt" files it converts, and those are backed up
        first. Your WAD files are only ever READ.

- We WARNING you...
    THIS SCRIPT AND RESULTING PRODUCTS COMES WITH ABSOLUTELY NO WARRANTY! USE AT
    YOUR OWN RISK! WE ARE NOT RESPONSIBLE FOR ANY DAMAGE TO YOURSELF, HARDWARE, OR
    OTHERS!
HEREDOC

read -r -d '' COMPANY_F << "HEREDOC"
UpScaler CS 1.6 🄯 BSD-3-Clause
Eduardo Lúcio Amorim Costa
Brazil-DF
https://www.linkedin.com/in/eduardo-software-livre/
Free software! Embrace that idea!
HEREDOC

TUX=$(cat "$SCRIPT_DIR_S/tux.txt")
ez_i.start "" "$TITLE_F" "$VERSION_F" "$ABOUT_F$TUX" "$WARNINGS_F" "$COMPANY_F"

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Terms and license.
# --------------------------------------

# NOTE: Read explicitly rather than with a bare "cat", so a missing file
# stops the script here instead of presenting an EMPTY licence for the user
# to accept. By Questor
if [ ! -f "$SCRIPT_DIR_S/complete_license.txt" ]; then
    echo "ERROR! \"complete_license.txt\" is missing from \"$SCRIPT_DIR_S\"." >&2
    exit 1
fi
TERMS_LICEN_F=$(cat "$SCRIPT_DIR_S/complete_license.txt")
ez_i.terms "$TERMS_LICEN_F"

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
    local PROBLEMS=""

    # NOTE: ImageMagick 7 renamed "convert" to "magick" and made the old name
    # print a deprecation warning TO STDERR. Since this script treats stderr
    # as failure, using "convert" on a current distribution would abort the
    # run on the very first image. By Questor
    if command -v magick > /dev/null 2>&1; then
        MAGICK_BIN_S="magick"
    elif command -v convert > /dev/null 2>&1; then
        MAGICK_BIN_S="convert"
    else
        PROBLEMS="$PROBLEMS
    ImageMagick (\"magick\", or \"convert\" on version 6)"
    fi

    if ! command -v python3 > /dev/null 2>&1; then
        PROBLEMS="$PROBLEMS
    Python 3 (\"python3\")"
    else
        if ! python3 -c "import PIL, numpy" > /dev/null 2>&1; then
            PROBLEMS="$PROBLEMS
    The Python modules Pillow and NumPy (\"python-pillow\", \"python-numpy\")"
        fi
    fi

    if ! command -v "$REALESRGAN_BIN_S" > /dev/null 2>&1; then
        PROBLEMS="$PROBLEMS
    The upscaler \"$REALESRGAN_BIN_S\" (see REALESRGAN_BIN_S in \"config.bash\")"
    fi

    if [ ${PNG_COMPRESS_LEVEL_S} -ne -1 ] && ! command -v oxipng > /dev/null 2>&1; then
        PROBLEMS="$PROBLEMS
    \"oxipng\" (or set PNG_COMPRESS_LEVEL_S=-1 in \"config.bash\")"
    fi

    local FOLDER=""
    for FOLDER in "$WORK_FOLDER_S" "$WORK_FOLDER_CSTRIKE_S" "$WORK_FOLDER_MAPS_S"; do
        if ! ez_i.exists "" "d" "$FOLDER"; then
            PROBLEMS="$PROBLEMS
    The folder \"$FOLDER\" (check the paths in \"config.bash\")"
        fi
    done

    if ! ez_i.exists "" "f" "$ASSETS_TOOL_S"; then
        PROBLEMS="$PROBLEMS
    The asset reader \"$ASSETS_TOOL_S\""
    fi

    ez_i.progress "o"
    if [ -n "$PROBLEMS" ]; then
        f_fail "Some things this run needs are missing:
$PROBLEMS"
    fi
    f_manage_logs " > Requirements checked (ImageMagick: \"$MAGICK_BIN_S\", upscaler: \"$REALESRGAN_BIN_S\")." "o" 1
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Work out what has to be done.
# --------------------------------------

# > -----------------------------------------
# Scan the maps and build the model of the whole run.

# NOTE: "SCAN_R" holds the id of the json-like object every other function
# reads the run out of: which maps there are, which textures each of them
# needs, where the pixels of each distinct image live and what it has to be
# upscaled by. By Questor
SCAN_R=""
function f_scan_assets(){
    : 'Read every BSP and build the model of the whole run.

    A map'\''s BSP carries the exact list of the textures that map uses, so
    nothing here has to guess which WADs matter: only the few texture names a
    map leaves external are ever looked up in them.
    '

    ez_i.progress "a" " > Scanning maps..."
    mkdir -p "$FAILSAFE_DIR_S"

    local BLACK_LIST_ARG=""
    if ez_i.exists "" "f" "$SCRIPT_DIR_S/black_list.txt"; then
        BLACK_LIST_ARG=" --black-list \"$SCRIPT_DIR_S/black_list.txt\""
    fi
    local TRY_MAX_PX_ARG=""
    if [ ${TRY_MAX_PX_S} -eq 1 ]; then
        TRY_MAX_PX_ARG=" --try-max-px"
    fi
    local KEEP_ENGINE_ARG=""
    if [ ${SKIP_ENGINE_TEXTURES_S} -eq 0 ]; then
        KEEP_ENGINE_ARG=" --keep-engine-textures"
    fi
    local WAD_LAST_ARG=""
    if [ ${WAD_LAST_WINS_S} -eq 1 ]; then
        WAD_LAST_ARG=" --wad-last-wins"
    fi

    f_run "python3 \"$ASSETS_TOOL_S\" scan \
--maps \"$WORK_FOLDER_MAPS_S\" \
--cstrike \"$WORK_FOLDER_CSTRIKE_S\" \
--env \"$WORK_FOLDER_ENV_S\" \
--target-px $TARGET_MAX_PX_S \
--factors \"$UPSCALE_FACTORS_S\" \
--hash-length $HASH_LENGTH_S\
$TRY_MAX_PX_ARG$KEEP_ENGINE_ARG$WAD_LAST_ARG$BLACK_LIST_ARG \
> \"$SCAN_FILE_S\"" "An error occurred while scanning the maps!"

    ez_i.progress "o"
    f_manage_logs " > Maps scanned." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Load the scan into the json-like model.

function f_load_scan(){
    : 'Load the scan file into the json-like object every step reads from.'

    ez_i.progress "a" " > Loading the scan..."
    if [ -n "$SCAN_R" ]; then
        json_like.unset_obj SCAN_R
    fi
    json_like.from_json SCAN_R < "$SCAN_FILE_S" || {
        f_fail "The scan file could not be read!
FILE: $SCAN_FILE_S
Delete it and run this script again to start a fresh scan."
    }
    ez_i.progress "o"
}

# < -----------------------------------------

# > -----------------------------------------
# Read one value out of the model.

# NOTE: A thin wrapper so that a missing path is a script failure with a
# useful message rather than a silent empty string. By Questor
F_MODEL_R=""
function f_model(){
    : 'Read one value out of the scan model.

    Args:
        PATH_ITEM... (str): Path to the value, one argument per level.

    Returns:
        F_MODEL_R (str): The value.
    '

    F_MODEL_R=""
    json_like.get F_MODEL_R "$SCAN_R" "$@" 2> /dev/null || {
        f_fail "The scan model has no \"$*\"!
This should not happen; please report it with the log below.
SCAN: $SCAN_FILE_S"
    }
}

# NOTE: Same, for the length of an array in the model. By Questor
F_MODEL_LENGTH_R=0
function f_model_length(){
    : 'Read the length of an array in the scan model.

    Args:
        PATH_ITEM... (str): Path to the array, one argument per level.

    Returns:
        F_MODEL_LENGTH_R (int): How many elements it has.
    '

    F_MODEL_LENGTH_R=0
    json_like.get_length F_MODEL_LENGTH_R "$SCAN_R" "$@" 2> /dev/null || {
        F_MODEL_LENGTH_R=0
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
# By Questor
BYTES_PER_PIXEL_S=1.48

function f_review_scan(){
    : 'Report what the scan found, stop on anything missing and have the user
    confirm the disk consumption.
    '

    local MAPS=0 IMAGES=0 SKY=0 REFS=0 UNRESOLVED=0 SKY_MISSING=0
    local BLACKLISTED=0 PIXELS=0
    f_model "totals" "maps";           MAPS=$F_MODEL_R
    f_model "totals" "images";         IMAGES=$F_MODEL_R
    f_model "totals" "sky";            SKY=$F_MODEL_R
    f_model "totals" "texture_refs";   REFS=$F_MODEL_R
    f_model "totals" "unresolved";     UNRESOLVED=$F_MODEL_R
    f_model "totals" "sky_missing";    SKY_MISSING=$F_MODEL_R
    f_model "totals" "blacklisted";    BLACKLISTED=$F_MODEL_R
    f_model "totals" "output_pixels";  PIXELS=$F_MODEL_R

    if [ ${MAPS} -eq 0 ]; then
        f_fail "No maps (*.bsp) were found!
FOLDER: $WORK_FOLDER_MAPS_S
Are the paths in \"config.bash\" correct?"
    fi

    # NOTE: Report every name a map needs and nothing provides, and every
    # missing skybox side, before deciding whether to stop. By Questor
    f_report_missing

    # NOTE: Report the texture names more than one of a map's WADs carries,
    # so the user can check the ones that actually matter. By Questor
    f_report_ambiguous

    local DISK_KB=""
    DISK_KB=$(awk '{printf("%.0f\n", ($1 * $2) / 1024)}' \
        <<< "$PIXELS $BYTES_PER_PIXEL_S")
    local DISK_GB=""
    ez_i.convert_bytes DISK_GB "$DISK_KB" "KB" "GB"
    local FREE_KB=$(df -Pk "$WORK_FOLDER_S" | tail -1 | awk '{print $4}')
    local FREE_GB=""
    ez_i.convert_bytes FREE_GB "$FREE_KB" "KB" "GB"
    local DISK_WARNING=""
    if (( $(echo $DISK_GB $FREE_GB | awk '{if ($1 > $2) print 1;}') )); then
        DISK_WARNING=" (!!! DISK SPACE WARNING !!!)"
    fi

    f_manage_logs " > Scan: $MAPS map(s), $REFS texture reference(s) resolving to \
$IMAGES distinct image(s) and $SKY distinct \"skyname\" side(s). \
$BLACKLISTED blacklisted, $UNRESOLVED unresolved, $SKY_MISSING \"skyname\" side(s) missing." "o" 1

    ez_i.divider
    ez_i.ask_yes_no "" "Your $MAPS map(s) use $REFS textures, which are only $IMAGES DISTINCT
images (plus $SKY distinct \"skyname\" sides). Each distinct image is upscaled
once, so that is all the work there is.

This will use APPROXIMATELY $DISK_GB GB on your disk.
Your free disk space is $FREE_GB GB$DISK_WARNING.
Is this OK for you?" || ez_i.okay_exit "Canceled by user."
    f_manage_logs " > Disk consumption accepted (APPROXIMATELY $DISK_GB GB)." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Report anything a map needs and nothing provides.

function f_report_missing(){
    : 'Log every unresolved texture and every missing "skyname" side, and stop
    if "STOP_WAD_SKYNAME_MISSING_S" says to.
    '

    local MAP_COUNT=0 MAP_NAME="" ITEM="" PROBLEMS=0
    local i=0 j=0
    f_model_length "map_order"
    MAP_COUNT=$F_MODEL_LENGTH_R
    for ((i=0;i<=$((MAP_COUNT-1));i++)); do
        f_model "map_order" "$i"
        MAP_NAME=$F_MODEL_R

        f_model_length "maps" "$MAP_NAME" "unresolved"
        for ((j=0;j<=$((F_MODEL_LENGTH_R-1));j++)); do
            json_like.get ITEM "$SCAN_R" "maps" "$MAP_NAME" "unresolved" "$j" 2> /dev/null || continue
            PROBLEMS=1
            f_manage_logs "A texture a map needs is in no WAD!
TEXTURE: $ITEM
MAP: $MAP_NAME" "e"
        done

        f_model_length "maps" "$MAP_NAME" "sky_missing"
        for ((j=0;j<=$((F_MODEL_LENGTH_R-1));j++)); do
            json_like.get ITEM "$SCAN_R" "maps" "$MAP_NAME" "sky_missing" "$j" 2> /dev/null || continue
            PROBLEMS=1
            f_model "maps" "$MAP_NAME" "skyname"
            f_manage_logs "A \"skyname\" file (TGA) is missing!
TGA: $WORK_FOLDER_ENV_S/${F_MODEL_R}${ITEM}.tga (use a case-insensitive path)
MAP: $MAP_NAME" "e"
        done
    done

    if [ ${PROBLEMS} -eq 1 ] && [ ${STOP_WAD_SKYNAME_MISSING_S} -eq 1 ]; then
        f_fail "There is/are texture(s) and/or \"skyname\" file(s) that no WAD and
no \"gfx/env\" provides. The maps that need them would come out incomplete.

Set STOP_WAD_SKYNAME_MISSING_S=0 in \"config.bash\" to process everything
else anyway and leave these out.

ERROR_LOG: $ERROR_LOG_PATH_N_NAME"
    fi
}

# < -----------------------------------------

# > -----------------------------------------
# Report texture names carried by more than one of a map's WADs.

function f_report_ambiguous(){
    : 'Log every texture name more than one of a map'\''s WADs carries.

    Which of them the engine actually uses is not something this script can
    know for certain, so each one is reported rather than silently decided.
    See WAD_LAST_WINS_S in "config.bash".
    '

    local COUNT=0 MAP_NAME="" TEXTURE="" USED=""
    local i=0
    f_model_length "ambiguous"
    COUNT=$F_MODEL_LENGTH_R
    if [ ${COUNT} -eq 0 ]; then
        return
    fi
    for ((i=0;i<=$((COUNT-1));i++)); do
        json_like.get MAP_NAME "$SCAN_R" "ambiguous" "$i" "map" 2> /dev/null || continue
        json_like.get TEXTURE "$SCAN_R" "ambiguous" "$i" "texture" 2> /dev/null || continue
        json_like.get USED "$SCAN_R" "ambiguous" "$i" "used" 2> /dev/null || continue
        f_manage_logs " > Texture name carried by more than one WAD: \"$TEXTURE\" \
(map \"$MAP_NAME\"), taken from \"$USED\" (WAD_LAST_WINS_S=$WAD_LAST_WINS_S)." "o"
    done
    f_manage_logs " > $COUNT texture name(s) are carried by more than one WAD; \
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
declare -a BACKUPS_R=()
function f_backup_files_n_folders(){
    : 'Back up the "detail" and "env" folders and the "*_detail.txt" files.

    These are the only things the run touches. WAD files are only ever read,
    so unlike the old pipeline - which deleted the ones it thought unused -
    there is nothing to back up for them.
    '

    f_backup_folder "$WORK_FOLDER_DETAIL_S" "\"detail\" folder" 1 \
        "$(basename "$UPSCALED_DETAIL_REL_S")"
    f_backup_folder "$WORK_FOLDER_ENV_S" "\"env\" folder" 0 \
        "$(basename "$UPSCALED_ENV_REL_S")"

    # NOTE: The "*_detail.txt" files are not a folder, so they are gathered
    # into one first.
    #
    # Counted BEFORE anything is created: a run after the first finds none of
    # them - the first run wrote the "*_extra.txt" that replace them and took
    # them away - and a backup of nothing is an empty tarball and a log line
    # claiming work that did not happen. By Questor
    local DETAIL_TXT_COUNT=0
    DETAIL_TXT_COUNT=$(find "$WORK_FOLDER_MAPS_S" -maxdepth 1 -type f \
        -iname "*_detail.txt" | wc -l)
    if [ ${DETAIL_TXT_COUNT} -eq 0 ]; then
        f_manage_logs " > Backup of (\"maps\" folder) \"*_detail.txt\" files \
skipped; there are none." "o" 1
        return
    fi
    ez_i.progress "a" " > Backing up (\"maps\" folder) \"*_detail.txt\" files..."
    declare -A BACKUP_AT=()
    ez_i.backup BACKUP_AT "${WORK_FOLDER_MAPS_S}_detail" 0 1
    mkdir -p "${BACKUP_AT[full]}"
    find "$WORK_FOLDER_MAPS_S" -maxdepth 1 -type f -iname "*_detail.txt" \
        -exec cp -t "${BACKUP_AT[full]}/" {} +
    f_compress_backup "${BACKUP_AT[path]}" "${BACKUP_AT[name]}"
    ez_i.progress "o"
    f_manage_logs " > Backup of (\"maps\" folder) \"*_detail.txt\" files done \
($DETAIL_TXT_COUNT file(s))." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Back up one folder.

function f_backup_folder(){
    : 'Back up what the USER had in one folder, as a compressed tarball.

    Args:
        FOLDER (str): Folder to back up.
        LABEL (str): How to name it in the messages.
        CLEAR (int): 1 - Take the original material out of the folder; 0 -
    Copy it and leave it where it is.
        EXCLUDE (str): Name of ONE entry, directly inside FOLDER, that is
    never backed up and never moved.

    IMPORTANT: EXCLUDE is what this script itself produces - "_upscaled",
    which lives INSIDE the folders being backed up. Without it a second run
    treats the first run'"'"'s output as the user'"'"'s own material: it sweeps
    hundreds of megabytes into a tarball, empties the folder, and then spends
    the whole upscale again rebuilding exactly what it just threw away.
    A backup is for what the user brought, never for what we made.
    '

    local FOLDER=$1
    local LABEL=$2
    local CLEAR=$3
    local EXCLUDE=$4
    if ! ez_i.exists "" "d" "$FOLDER"; then
        f_manage_logs " > Backup of $LABEL skipped; it does not exist." "o" 1
        return
    fi
    ez_i.progress "a" " > Backing up $LABEL..."
    declare -A BACKUP_AT=()

    # NOTE: "name only", so nothing is moved yet; what goes into the backup
    # is chosen entry by entry below. By Questor
    ez_i.backup BACKUP_AT "$FOLDER" 0 1

    if [ ${CLEAR} -eq 1 ]; then
        mkdir -p "${BACKUP_AT[full]}"
        local MOVED=0
        local ENTRY=""
        local ENTRY_COUNT=0
        ENTRY_COUNT=$(find "$FOLDER" -mindepth 1 -maxdepth 1 | wc -l)
        while IFS= read -r -d $'"'"'\0'"'"' ENTRY; do
            if [ -n "$EXCLUDE" ] && [ "$(basename "$ENTRY")" == "$EXCLUDE" ]; then
                continue
            fi
            mv -f "$ENTRY" "${BACKUP_AT[full]}/"
            MOVED=1
        done < <(find "$FOLDER" -mindepth 1 -maxdepth 1 -print0)
        if [ ${MOVED} -eq 0 ]; then
            rmdir "${BACKUP_AT[full]}" 2> /dev/null
            ez_i.progress "o"

            # NOTE: An empty folder and a folder holding only our own output
            # both have nothing to back up, but they are not the same thing
            # and the log should not pretend they are. By Questor
            if [ ${ENTRY_COUNT} -eq 0 ]; then
                f_manage_logs " > Backup of $LABEL skipped; it is empty." "o" 1
            else
                f_manage_logs " > Backup of $LABEL skipped; everything in \
it was made by this script, so there is nothing of yours to save." "o" 1
            fi
            return
        fi
        f_compress_backup "${BACKUP_AT[path]}" "${BACKUP_AT[name]}"
    else
        local BASE_NAME=""
        BASE_NAME="$(basename "$FOLDER")"
        local EXCLUDE_ARG=""
        if [ -n "$EXCLUDE" ]; then
            EXCLUDE_ARG=" --exclude \"./$BASE_NAME/$EXCLUDE\""
        fi
        cd "${BACKUP_AT[path]}" || f_fail "Cannot enter \"${BACKUP_AT[path]}\"!"
        f_run "tar -czf \"${BACKUP_AT[name]}.tar.gz\"$EXCLUDE_ARG \
--transform \"s|^\./$BASE_NAME|${BACKUP_AT[name]}|\" \"./$BASE_NAME\"" \
            "An error occurred while compressing the backup of $LABEL!"
        cd "$SCRIPT_DIR_S" || f_fail "Cannot return to \"$SCRIPT_DIR_S\"!"
        BACKUPS_R+=("${BACKUP_AT[path]}/${BACKUP_AT[name]}.tar.gz")
    fi
    ez_i.progress "o"
    f_manage_logs " > Backup of $LABEL done." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Compress a backup folder and remove the uncompressed copy.

function f_compress_backup(){
    : 'Compress a backup folder into a tarball beside it and remove it.

    Args:
        BACKUP_PATH (str): Folder the backup folder sits in.
        BACKUP_NAME (str): Name of the backup folder.
    '

    local BACKUP_PATH=$1
    local BACKUP_NAME=$2
    if [ -z "$BACKUP_NAME" ]; then
        f_fail "An empty backup name was given! (f_compress_backup)"
    fi
    cd "$BACKUP_PATH" || f_fail "Cannot enter \"$BACKUP_PATH\"!"
    f_run "tar -czf \"$BACKUP_NAME.tar.gz\" \"$BACKUP_NAME\"" \
        "An error occurred while compressing the backup folder!
FOLDER: $BACKUP_PATH/$BACKUP_NAME"
    rm -rf "${BACKUP_PATH:?}/${BACKUP_NAME:?}"
    cd "$SCRIPT_DIR_S" || f_fail "Cannot return to \"$SCRIPT_DIR_S\"!"
    BACKUPS_R+=("$BACKUP_PATH/$BACKUP_NAME.tar.gz")
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Produce the images.
# --------------------------------------

# > -----------------------------------------
# Write every distinct image the run needs, as a PNG.

function f_export_images(){
    : 'Write every distinct image the run needs out of the BSPs and WADs.

    The files go into one folder per upscale factor so that the upscaler can
    take a whole folder at a time; anything already finished is not written.
    '

    ez_i.progress "a" " > Exporting images..."
    mkdir -p "$SOURCE_DIR_S"
    f_run "python3 \"$ASSETS_TOOL_S\" export \
--plan \"$SCAN_FILE_S\" \
--out \"$SOURCE_DIR_S\" \
--done \"$FINAL_DETAIL_DIR_S\" \
--done \"$FINAL_ENV_DIR_S\"" "An error occurred while exporting the images!"
    ez_i.progress "o"
    f_manage_logs " > Images exported ($F_RUN_R)." "o" 1
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

    local BUCKET="" FACTOR="" OUT_BUCKET="" FILE="" NAME=""
    local IN_COUNT=0 OUT_COUNT=0 TOTAL=0
    declare -a BUCKETS=()
    while IFS= read -r -d '' BUCKET; do
        BUCKETS+=("$BUCKET")
    done < <(find "$SOURCE_DIR_S" -mindepth 1 -maxdepth 1 -type d -print0 2> /dev/null)

    if [ ${#BUCKETS[*]} -eq 0 ]; then
        f_manage_logs " > Upscaling skipped; every image is already done." "o" 1
        return
    fi

    local i=0
    for ((i=0;i<=$((${#BUCKETS[*]}-1));i++)); do
        BUCKET="${BUCKETS[$i]}"
        FACTOR="$(basename "$BUCKET")"
        OUT_BUCKET="$UPSCALED_DIR_S/$FACTOR"
        mkdir -p "$OUT_BUCKET"

        # NOTE: Drop anything this bucket already has an upscaled result for,
        # so an interrupted run does not redo it. By Questor
        while IFS= read -r -d '' FILE; do
            NAME="$(basename "$FILE")"
            if [ -f "$OUT_BUCKET/$NAME" ]; then
                rm -f "$FILE"
            fi
        done < <(find "$BUCKET" -maxdepth 1 -type f -name "*.png" -print0)

        IN_COUNT=$(find "$BUCKET" -maxdepth 1 -type f -name "*.png" | wc -l)
        if [ ${IN_COUNT} -eq 0 ]; then
            rmdir "$BUCKET" 2> /dev/null
            continue
        fi

        ez_i.progress "a" " > Upscaling $IN_COUNT image(s) by ${FACTOR}x (this takes a while)..."
        f_upscale_folder "$BUCKET" "$OUT_BUCKET" "$FACTOR"
        ez_i.progress "o"

        OUT_COUNT=$(find "$OUT_BUCKET" -maxdepth 1 -type f -name "*.png" | wc -l)
        if [ ${OUT_COUNT} -lt ${IN_COUNT} ]; then
            f_fail "The upscaler did not produce every image!
FACTOR: ${FACTOR}x
EXPECTED AT LEAST: $IN_COUNT
PRODUCED: $OUT_COUNT
INPUT: $BUCKET
OUTPUT: $OUT_BUCKET"
        fi
        rm -rf "${BUCKET:?}"
        TOTAL=$((TOTAL+IN_COUNT))
        f_manage_logs " > Upscaled $IN_COUNT image(s) by ${FACTOR}x." "o" 1
    done
    f_manage_logs " > Upscaling done ($TOTAL image(s))." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Upscale one whole folder.

# [Ref(s).: https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan#full-usages ]
function f_upscale_folder(){
    : 'Upscale every PNG in a folder into another folder.

    Args:
        IN_DIR (str): Folder of PNGs to upscale.
        OUT_DIR (str): Folder to write the results into.
        FACTOR (int): Upscale factor.
    '

    local IN_DIR=$1
    local OUT_DIR=$2
    local FACTOR=$3
    local TTA_MODE=""
    if [ ${RSRGAN_ENABLE_TTA_S} -eq 1 ]; then
        TTA_MODE=" -x"
    fi

    # NOTE: The factors this can be called with come from UPSCALE_FACTORS_S,
    # which MUST match REALESRGAN_MODEL_S. Asking a fixed 4x model such as
    # "realesrgan-x4plus" for another factor is what fails with
    # "find_blob_index_by_name data failed"; there is no retry loop here
    # because the pair is a configuration question, not a runtime one.
    # By Questor
    f_run "\"$REALESRGAN_BIN_S\" -i \"$IN_DIR\" -o \"$OUT_DIR\" \
-s $FACTOR -n \"$REALESRGAN_MODEL_S\" -f png$TTA_MODE" \
        "An error occurred while upscaling with \"$REALESRGAN_BIN_S\"!
MODEL: $REALESRGAN_MODEL_S
FACTOR: ${FACTOR}x
If the error mentions \"find_blob_index_by_name\", the model does not support
this factor. Check REALESRGAN_MODEL_S and UPSCALE_FACTORS_S in \"config.bash\"." 0

    # NOTE: These tools report progress on stderr and keep going past a single
    # bad file, so the exit code alone is not enough. The caller also compares
    # how many files came out against how many went in. By Questor
    if echo "${F_RUN_RESULT[both]}" | grep -iq "failed\|invalid\|unsupported"; then
        f_fail "The upscaler reported a problem!
OUTPUT: ${F_RUN_RESULT[both]}
INPUT: $IN_DIR"
    fi
}

# < -----------------------------------------

# > -----------------------------------------
# Resize, sharpen and compress every upscaled image into its final place.

function f_finish_images(){
    : 'Resize, sharpen and compress every upscaled image into its final place.

    The final name is the image'\''s content hash, which is what the
    "*_extra.txt" files point at.
    '

    local FILE="" HASH="" FACTOR="" RESIZE="" TARGET="" KIND=""
    declare -a PENDING=()
    while IFS= read -r -d '' FILE; do
        PENDING+=("$FILE")
    done < <(find "$UPSCALED_DIR_S" -mindepth 2 -maxdepth 2 -type f -name "*.png" -print0 2> /dev/null)

    local TOTAL=${#PENDING[*]}
    if [ ${TOTAL} -eq 0 ]; then
        f_manage_logs " > Finishing skipped; every image is already done." "o" 1
        return
    fi

    mkdir -p "$FINAL_DETAIL_DIR_S" "$FINAL_ENV_DIR_S"
    declare -A FINISH_TASK=()
    ez_i.task_stats_init FINISH_TASK "$TOTAL"
    local TASK_STATS=""
    local i=0
    for ((i=0;i<=$((TOTAL-1));i++)); do
        ez_i.task_stats_begin FINISH_TASK
        FILE="${PENDING[$i]}"
        HASH="$(basename "$FILE" ".png")"

        # NOTE: A hash is either a texture or a "skyname" side, and the two go
        # to different folders. By Questor
        RESIZE=""
        if json_like.get RESIZE "$SCAN_R" "images" "$HASH" "resize" 2> /dev/null; then
            TARGET="$FINAL_DETAIL_DIR_S/$HASH.png"
            KIND="texture"
        elif json_like.get RESIZE "$SCAN_R" "sky" "$HASH" "resize" 2> /dev/null; then
            TARGET="$FINAL_ENV_DIR_S/$HASH.png"
            KIND="skyname"
        else
            f_fail "An upscaled image is in no scan!
FILE: $FILE
This usually means \"$WORK_DIR_S\" is left over from a run with different
settings. Delete it and run this script again."
        fi

        ez_i.progress "a" " > Finishing the PNG image ($KIND)..."
        f_finish_image "$FILE" "$TARGET" "$RESIZE"
        ez_i.progress "o"
        rm -f "$FILE"
        ez_i.task_stats_end TASK_STATS FINISH_TASK
        f_manage_logs " > PNG finished ($KIND): $TARGET
$TASK_STATS" "o" 1
    done
    rm -rf "${UPSCALED_DIR_S:?}"
    f_manage_logs " > Finishing done ($TOTAL image(s))." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# Resize, sharpen and compress one image.

# [Ref(s).: https://legacy.imagemagick.org/Usage/resize/ ,
# https://www.halolinux.us/ubuntu-hacks/sharpen-images-at-the-command-line.html ,
# https://github.com/shssoichiro/oxipng ]
function f_finish_image(){
    : 'Resize, sharpen and compress one image into its final place.

    Args:
        INPUT_FILE (str): Upscaled image.
        OUTPUT_FILE (str): Where the finished image goes.
        RESIZE (str): ImageMagick geometry, or "" for no resize.
    '

    local INPUT_FILE=$1
    local OUTPUT_FILE=$2
    local RESIZE=$3
    local RESIZE_PARAM=""
    local SHARPEN_PARAM=""

    if [ -n "$RESIZE" ]; then

        # NOTE: The "!" tells ImageMagick to ignore the aspect ratio and give
        # exactly this size. It is quoted because several shells treat it
        # specially. By Questor
        RESIZE_PARAM=" -resize '$RESIZE'"
    fi
    if [ ${SHARPEN_IMGS_S} -ne -1 ]; then
        SHARPEN_PARAM=" -sharpen 0x$SHARPEN_IMGS_S"
    fi

    f_run "\"$MAGICK_BIN_S\" \"$INPUT_FILE\"$RESIZE_PARAM$SHARPEN_PARAM \"$OUTPUT_FILE\"" \
        "An error occurred while resizing/sharpening the PNG image!
FILE: $INPUT_FILE"

    if [ ${PNG_COMPRESS_LEVEL_S} -ne -1 ]; then
        # NOTE: "-i 0" writes a NON interlaced PNG. The old pipeline passed
        # "-i 1", which interlaces, and an interlaced PNG is typically larger
        # - the opposite of the point of running a compressor, and of no use
        # at all to a texture the engine loads whole. By Questor
        f_run "oxipng -o $PNG_COMPRESS_LEVEL_S -i 0 --strip safe --quiet \"$OUTPUT_FILE\"" \
            "An error occurred while compressing the PNG image!
FILE: $OUTPUT_FILE" 0
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
# one would produce an "*_extra.txt" the renderer cannot read. By Questor
F_JSON_ESCAPE_R=""
function f_json_escape(){
    : 'Escape a string so it can go inside a JSON string literal.

    Args:
        VALUE (str): String to escape.

    Returns:
        F_JSON_ESCAPE_R (str): The escaped string.
    '

    local VALUE=$1
    VALUE="${VALUE//\\/\\\\}"
    VALUE="${VALUE//\"/\\\"}"
    VALUE="${VALUE//	/\\t}"
    F_JSON_ESCAPE_R="$VALUE"
}

# < -----------------------------------------

# > -----------------------------------------
# Write the "*_extra.txt" files.

# NOTE: This is the file that makes everything else usable: it maps each
# texture NAME a map uses onto the hash named PNG that replaces it. Because
# the name lives here and not in the file name, two maps that share an image
# share the one file, and two different images that happen to share a name do
# not collide. By Questor
# [Ref(s).: https://stackoverflow.com/a/73628324/3223785 ]
declare -a SKY_SIDES=("rt" "bk" "lf" "ft" "up" "dn")
function f_write_extra_txt(){
    : 'Write one "*_extra.txt" (Renderer 1.5c) per map.'

    local MAP_COUNT=0 MAP_NAME="" OUTPUT_FILE=""
    local TEXTURE_COUNT=0 SKY_COUNT=0
    local BASE="" HASH="" SIDE="" BODY="" SKY_BODY="" SEPARATOR=""
    local DETAIL_TXT=""
    local i=0 j=0

    f_model_length "map_order"
    MAP_COUNT=$F_MODEL_LENGTH_R
    declare -A EXTRA_TASK=()
    ez_i.task_stats_init EXTRA_TASK "$MAP_COUNT"
    local TASK_STATS=""
    for ((i=0;i<=$((MAP_COUNT-1));i++)); do
        ez_i.task_stats_begin EXTRA_TASK
        f_model "map_order" "$i"
        MAP_NAME=$F_MODEL_R
        OUTPUT_FILE="$WORK_FOLDER_MAPS_S/${MAP_NAME}_extra.txt"
        BODY=""
        SEPARATOR=""

        # > ----- the skybox, which has to come first -----
        f_model_length "maps" "$MAP_NAME" "sky"
        SKY_COUNT=$F_MODEL_LENGTH_R
        if [ ${SKY_COUNT} -gt 0 ]; then
            SKY_BODY=""
            local SKY_SEPARATOR=""
            for ((j=0;j<=$((SKY_COUNT-1));j++)); do
                json_like.get SIDE "$SCAN_R" "maps" "$MAP_NAME" "sky" "$j" "side" 2> /dev/null || continue
                json_like.get HASH "$SCAN_R" "maps" "$MAP_NAME" "sky" "$j" "hash" 2> /dev/null || continue
                SKY_BODY+="$SKY_SEPARATOR			\"$SIDE\" : \"$UPSCALED_ENV_REL_S/$HASH.png\""
                SKY_SEPARATOR=",
"
            done
            BODY+="	{\"base\" : \"sky\", \"replace\" :
		{
$SKY_BODY
		}
	}"
            SEPARATOR=",
"
        fi
        # < ----- the skybox, which has to come first -----

        # > ----- the textures -----
        f_model_length "maps" "$MAP_NAME" "texture_list"
        TEXTURE_COUNT=$F_MODEL_LENGTH_R
        for ((j=0;j<=$((TEXTURE_COUNT-1));j++)); do
            json_like.get BASE "$SCAN_R" "maps" "$MAP_NAME" "texture_list" "$j" "base" 2> /dev/null || continue
            json_like.get HASH "$SCAN_R" "maps" "$MAP_NAME" "texture_list" "$j" "hash" 2> /dev/null || continue
            f_json_escape "$BASE"
            BODY+="$SEPARATOR	{\"base\" : \"$F_JSON_ESCAPE_R\", \"replace\" : \"$UPSCALED_DETAIL_REL_S/$HASH.png\", \"replacescale\" : \"1.0 1.0\"}"
            SEPARATOR=",
"
        done
        # < ----- the textures -----

        if [ -z "$BODY" ]; then
            ez_i.task_stats_skip TASK_STATS EXTRA_TASK
            f_manage_logs " > Extra (\"*_extra.txt\") skipped; \"$MAP_NAME\" has nothing to replace.
$TASK_STATS" "o" 1
            continue
        fi

        # NOTE: Written with MS-DOS (CRLF) line endings, which is what the
        # files this format came from use. By Questor
        printf '[\r\n%s\r\n]\r\n' "$BODY" | sed 's/$/\r/; s/\r\r$/\r/' > "$OUTPUT_FILE"

        # NOTE: The "*_detail.txt" the map came with is what the engine reads
        # WITHOUT the renderer plugin, and it points at the per-map folders
        # under "gfx/detail" that the backup moved away. Leaving it would
        # have the engine chase files that are not there.
        #
        # It is REMOVED rather than renamed because it is already inside the
        # "*_detail.txt" tarball that "f_backup_files_n_folders" wrote before
        # any of this ran - the same treatment the "detail" and "env" folders
        # get. A renamed copy here would be a second one, dead, one per map.
        # By Questor
        DETAIL_TXT="$WORK_FOLDER_MAPS_S/${MAP_NAME}_detail.txt"
        if [ -f "$DETAIL_TXT" ]; then
            rm -f "$DETAIL_TXT"
        fi

        ez_i.task_stats_end TASK_STATS EXTRA_TASK
        f_manage_logs " > Extra (\"*_extra.txt\") written: $OUTPUT_FILE
TEXTURES: $TEXTURE_COUNT / \"SKYNAME\" SIDES: $SKY_COUNT
REPLACES (AND REMOVES, IT IS IN THE BACKUP): ${MAP_NAME}_detail.txt
$TASK_STATS" "o" 1
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

    REDO_ALL_S exists because each file is named after the content hash of
    its SOURCE texture and not after the settings used to process it. Change
    the model, the target size or the sharpening and every name stays the
    same, so each step finds its output already there and skips it: the new
    setting would have no effect at all, and nothing would say so.

    The backups are never touched.
    '

    local DETAIL_COUNT=0
    local ENV_COUNT=0
    DETAIL_COUNT=$(find "$FINAL_DETAIL_DIR_S" -maxdepth 1 -type f -name "*.png" \
        2> /dev/null | wc -l)
    ENV_COUNT=$(find "$FINAL_ENV_DIR_S" -maxdepth 1 -type f -name "*.png" \
        2> /dev/null | wc -l)

    if [ $((DETAIL_COUNT + ENV_COUNT)) -eq 0 ] \
        && ! ez_i.exists "" "d" "$FAILSAFE_DIR_S"; then
        f_manage_logs " > REDO_ALL_S is on, but there was nothing to throw \
away." "o" 1
        return
    fi

    # NOTE: Asked even though the flag is already the answer. The flag lives
    # in a file and is easy to leave switched on, and what it costs is every
    # image of the last run plus the hours to make them again. By Questor
    ez_i.divider
    ez_i.ask_yes_no "" "REDO_ALL_S is 1 in \"config.bash\", so EVERYTHING IS TO BE MADE AGAIN
from the beginning.

THIS DELETES $DETAIL_COUNT upscaled texture(s) and $ENV_COUNT upscaled \"skyname\" side(s),
and the whole run has to be done over. YOUR BACKUPS ARE NOT TOUCHED.

Answer \"n\", set REDO_ALL_S back to 0, and run again to keep what is there.
Go ahead?" || ez_i.okay_exit "Canceled by user."

    ez_i.progress "a" " > Throwing away everything already produced..."
    rm -rf "${FINAL_DETAIL_DIR_S:?}" "${FINAL_ENV_DIR_S:?}" "${FAILSAFE_DIR_S:?}"
    ez_i.progress "o"
    f_manage_logs " > REDO_ALL_S is on; $DETAIL_COUNT texture(s) and $ENV_COUNT \
\"skyname\" side(s) thrown away. Everything will be made again." "o" 1
}

if [ ${REDO_ALL_S} -eq 1 ]; then
    f_redo_all
fi

# < -----------------------------------------

# > -----------------------------------------
# Resume an unfinished run, or start a new one.

# NOTE: The scan is the whole state of a run. Everything after it skips what
# is already on disk, so resuming is simply not scanning again. By Questor
USR_RESUME_PROCESS=0
if ez_i.exists "" "f" "$SCAN_FILE_S"; then
    ez_i.divider
    ez_i.ask_yes_no USR_RESUME_PROCESS "There is an unfinished upscale process.
Do you want to resume it? (\"y\" highly recommended)

Resuming keeps everything already produced and carries on from there.
Starting over rescans the maps; images already finished are still not redone."
fi

if [ ${USR_RESUME_PROCESS} -eq 1 ]; then
    f_manage_logs " > Unfinished upscale process resumed." "o" 1
    f_load_scan
else
    rm -rf "${FAILSAFE_DIR_S:?}"
    f_manage_logs " > Scan started." "o" 1
    f_scan_assets
    f_load_scan
    f_review_scan
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

# NOTE: The run is complete, so the work in progress state goes away. By Questor
rm -rf "${FAILSAFE_DIR_S:?}"

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# End.
# --------------------------------------

# > -----------------------------------------
# List backup folders.

F_LIST_BACKUP_FOLDERS_R=""
function f_list_backup_folders(){
    : 'Build the list of backups made by this run.'

    local NEW_LINE=""
    local i=0
    for ((i=0;i<=$((${#BACKUPS_R[*]}-1));i++)); do
        F_LIST_BACKUP_FOLDERS_R="$F_LIST_BACKUP_FOLDERS_R$NEW_LINE${BACKUPS_R[$i]}"
        NEW_LINE="
    "
    done
    if [ -z "$F_LIST_BACKUP_FOLDERS_R" ]; then
        F_LIST_BACKUP_FOLDERS_R="<NONE; this run resumed an earlier one>"
    fi
    f_manage_logs " > Backup folders listed." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# End message.

f_manage_logs " > UPSCALER-CS16 - UpScaler CS 1.6 finished." "o"

read -r -d '' TITLE_F << "HEREDOC"
UPSCALER-CS16 - UpScaler CS 1.6 finished! Thanks!
HEREDOC

f_list_backup_folders
read -r -d '' USEFUL_INFO_F << HEREDOC
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
    $WORK_FOLDER_CSTRIKE_S/userconfig.cfg

- Your upscaled images...
    $FINAL_DETAIL_DIR_S
    $FINAL_ENV_DIR_S

- Your backups...
    $F_LIST_BACKUP_FOLDERS_R
HEREDOC

ez_i.end "$TITLE_F" "$USEFUL_INFO_F"

# < -----------------------------------------

# < --------------------------------------------------------------------------

exit 0
