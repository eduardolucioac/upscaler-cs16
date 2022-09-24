#!/bin/bash

# > -----------------------------------------
# Run that script with bash even if the user use sh/dash or any sh like interpreter.
# This way it correctly works with either: "sh ./my_script.bash" or "bash ./my_script.bash"
# or "./my_script.bash".

if [ -z "$BASH_VERSION" ]
then
    exec bash "$0" "$@"
fi

# < -----------------------------------------

# NOTE: Avoids problems with relative paths. By Questor
SCRIPT_DIR_S="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# NOTE: Load ez_i library (in reality a bash script). It provides a number of cool
# features for creating interactive bash scripts, including installers. By Questor
# [Ref(s).: https://github.com/eduardolucioac/ez_i ]
. $SCRIPT_DIR_S/ez_i.bash

# NOTE: Load configurations. By Questor
. $SCRIPT_DIR_S/config.bash

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

    f_chk_fd_fl "$SCRIPT_DIR_S/logs/output" "d"
    if [ ${CHK_FD_FL_R} -eq 1 ] && ls -tp "$SCRIPT_DIR_S/logs/output"**/* 1> /dev/null 2>&1 ; then
        ls -tp "$SCRIPT_DIR_S/logs/output"**/* | grep -v '/$' | tail -n +$((LOGS_KEEP_S+1)) | xargs -d '\n' -r rm --
    fi
    f_chk_fd_fl "$SCRIPT_DIR_S/logs/error" "d"
    if [ ${CHK_FD_FL_R} -eq 1 ] && ls -tp "$SCRIPT_DIR_S/logs/error"**/* 1> /dev/null 2>&1 ; then
        ls -tp "$SCRIPT_DIR_S/logs/error"**/* | grep -v '/$' | tail -n +$((LOGS_KEEP_S+1)) | xargs -d '\n' -r rm --
    fi
}

# NOTE: Clears old logs regardless of the reason the script was terminated. By Questor
f_ez_trap_add "f_clean_old_logs" SIGINT SIGTERM ERR EXIT

# < -----------------------------------------

# > -----------------------------------------
# Allows you to manage script logs easily.

OUTPUT_LOG_PATH_N_NAME=""
ERROR_LOG_PATH_N_NAME=""
function f_manage_logs(){
    : 'Allows you to manage script logs easily.

    Args:
        VALUE_TO_INSERT (str): Value to be inserted in the log;
        LOG_TYPE (str): o - Error log; e - Output log.
        VAL_INS_ON_SCREEN (Optional[int]): 0 - Will NOT print "VALUE_TO_INSERT" on
    screen; 1 - Will PRINT "VALUE_TO_INSERT" on screen. Default 0.
    '

    local VALUE_TO_INSERT=$1
    local LOG_TYPE=$2
    local VAL_INS_ON_SCREEN=$3
    if [ -z "$VAL_INS_ON_SCREEN" ] ; then
        VAL_INS_ON_SCREEN=0
    fi
    case "$LOG_TYPE" in
        "o") # Output
            if [ -z "$OUTPUT_LOG_PATH_N_NAME" ] ; then
                f_log_manager "$VALUE_TO_INSERT" 0 1 "$SCRIPT_DIR_S/logs/output" $VAL_INS_ON_SCREEN
                OUTPUT_LOG_PATH_N_NAME="$F_LOG_MANAGER_R"
            else
                f_log_manager "$VALUE_TO_INSERT" "$OUTPUT_LOG_PATH_N_NAME" 0 "" $VAL_INS_ON_SCREEN
            fi
        ;;
        "e") # Error
            if [ -z "$ERROR_LOG_PATH_N_NAME" ] ; then
                f_log_manager "$VALUE_TO_INSERT" 1 1 "$SCRIPT_DIR_S/logs/error" $VAL_INS_ON_SCREEN
                ERROR_LOG_PATH_N_NAME="$F_LOG_MANAGER_R"
            else
                f_log_manager "$VALUE_TO_INSERT" "$ERROR_LOG_PATH_N_NAME" 0 "" $VAL_INS_ON_SCREEN
            fi
        ;;
        *)
            local ERROR_NOW="Invalid option! (f_manage_logs)"
            f_manage_logs "$ERROR_NOW" "e"
            f_error_exit "$ERROR_NOW"
        ;;
    esac
}

# < -----------------------------------------

# > -----------------------------------------
# Displays an additional warning and adds a log entry if the user cancels execution
# with Ctrl+c.

# [Ref(s).: https://opensource.com/article/20/6/bash-trap ]
function f_canceled_by_user(){
    : 'Displays an additional warning and adds a log entry if the user cancels execution
    with Ctrl+c.
    '

    f_manage_logs " > The execution was terminated!
CAUSE: Canceled by user." "o"
    f_okay_exit "Canceled by user."
}

f_ez_trap_add "f_canceled_by_user" SIGINT

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Start.
# --------------------------------------

f_manage_logs " > USCS16 - UpScaler CS 1.6 started." "o"

read -r -d '' TITLE_F << "HEREDOC"
USCS16 - UpScaler CS 1.6
HEREDOC

# NOTE: For versioning use "MAJOR.MINOR.REVISION.BUILDNUMBER". By Questor
# [Ref(s).: http://programmers.stackexchange.com/questions/24987/what-exactly-is-the-build-number-in-major-minor-buildnumber-revision ]
read -r -d '' VERSION_F << "HEREDOC"
0.1.0.0
HEREDOC

read -r -d '' ABOUT_F << "HEREDOC"
Welcome to UpScaler CS 1.6!
Upscale (increase resolution) your CS 1.6 maps!
This script, basically, is compatible with any Desktop Linux distribution.
HEREDOC

read -r -d '' WARNINGS_F << "HEREDOC"
- We INSTRUCT you...
    READ the README.md.
    INSTALL ALL NECESSARY DEPENDENCIES: Waifu2x (waifu2x-ncnn-vulkan)/Realesrgan 
        (realesrgan-ncnn-vulkan) and ImageMagick (convert, identify), etc...
    CHECK FOR PREVIOUS RUNS. If there is previous runs consider this variant in the 
        process.
    Although this is not mandatory, BACKUP ALL YOUR DATA!
    Make sure you have ENOUGH FREE SPACE on your hard drive.
    TO CANCEL the process at any time use Ctrl+c.

- We NOTICE you...
    This script assumes that your Linux distribution has a all necessary "default" 
        dependencies. This may include some common components like grep, sed, awk, 
        blah, blah, blah... (It is virtually certain that all necessary components
        are present).
    IMAGE UPSCALING IS A LONG, LONG PROCESS that uses a lot of computational resources.
    THE WHOLE PROCESS CAN TAKE HOURS OR DAYS; depending on your machine configuration
        and the number of maps (*.bsp) to be processed.
    Results DEPEND ON THE QUALITY OF YOUR MAPS. Maps with very small or bad textures 
        will not have good results. Don't expect a miracle. But in general we will 
        have BETTER DEFINITION AND CLARITY of textures.
    Metahook doesn't support detail textures =[ .

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

TUX=$(cat $SCRIPT_DIR_S/tux.txt)
f_start "$TITLE_F" "$VERSION_F" "$ABOUT_F$TUX" "$WARNINGS_F" "$COMPANY_F"

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Terms and license.
# --------------------------------------

TERMS_LICEN_F=$(cat $SCRIPT_DIR_S/complete_license.txt)
f_terms_licen "$TERMS_LICEN_F"

f_manage_logs " > Terms and license accepted." "o" 1

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Allows you to resume a process in case of failure or need.
# --------------------------------------

# > -----------------------------------------
# Allows you to resume a process in case of failure or need.

# [Ref(s).: https://unix.stackexchange.com/a/46326/61742 ,
# https://askubuntu.com/a/318211/134723 ,
# https://stackoverflow.com/a/6843928/3223785 ,
# https://unix.stackexchange.com/a/83850/61742 ,
# https://superuser.com/a/1299715/195840 ,
# https://stackoverflow.com/a/793867/3223785 ,
# https://stackoverflow.com/a/638980/3223785 ,
# https://stackoverflow.com/a/20243503/3223785 ,
# https://stackoverflow.com/a/11395181/3223785 ]
F_RESUME_PROCESS_R=0
function f_resume_process(){
    : 'Allows you to resume a process in case of failure or need.

    The basic logic consists of using arrays and files generated with the contents
    of these arrays to resume loops that consume these arrays and have a long duration.

    Args:
        F_RP_OPTION (str): "ck" - Checks if there is a file with the array contents;
    "ct" - Creates a file from the the array contents; "rd" - Reads the file contents
    to an array; rm - Removes the file with the array'\''s contents;
        F_RP_TARGET (str)(by reference): It'\''s basically the name of the array
    and the file you want to create or read.

    Returns:
        F_RESUME_PROCESS_R (int)(if F_RP_OPTION equals "ck"): 0 - If the file with
    the array contents does NOT EXIST; 1 - Otherwise.
    '

    F_RESUME_PROCESS_R=0
    local F_RP_OPTION=$1
    local F_RP_TARGET=$2
    if [ -n "$F_RP_TARGET" ] ; then
        declare -n F_RP_TARGET_ARR=$F_RP_TARGET
    fi
    local F_FAILSAFE_PATH="$SCRIPT_DIR_S/__FAILSAFE__"
    local F_RP_TARGET_PATH="$F_FAILSAFE_PATH/$F_RP_TARGET"
    case "$F_RP_OPTION" in
        "ck") # ChecK
            f_chk_fd_fl "$F_RP_TARGET_PATH" "f"
            F_RESUME_PROCESS_R=$CHK_FD_FL_R
        ;;
        "ct") # CreaTe

            # NOTE: Create the folder "./__FAILSAFE__" if it does not exist. By Questor
            f_chk_fd_fl "$F_FAILSAFE_PATH" "d"
            if [ ${CHK_FD_FL_R} -eq 0 ] ; then
                mkdir "$F_FAILSAFE_PATH"
            fi

            f_arrays_n_files "c" "$F_RP_TARGET_PATH" F_RP_TARGET_ARR[@]
        ;;
        "rd") # ReaD
            f_arrays_n_files "r" "$F_RP_TARGET_PATH"
            F_RP_TARGET_ARR=("${F_ARRAYS_N_FILES_R[@]}")
        ;;
        "rm") # ReMove
            rm -f "$F_RP_TARGET_PATH"

            # NOTE: Remove the "./__FAILSAFE__" directory if it is empty. Hidden
            # files and folders will not be considered. By Questor
            f_del_empty_fl "$F_FAILSAFE_PATH" 1

        ;;
        *)
            local ERROR_NOW="Invalid option! (f_resume_process)"
            f_manage_logs "$ERROR_NOW" "e"
            f_error_exit "$ERROR_NOW"
        ;;
    esac
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Check that there is enough disk space.
# --------------------------------------

# > -----------------------------------------
# Check that there is enough disk space.

# [Ref(s).: https://unix.stackexchange.com/a/6014/61742 ,
# https://devconnected.com/how-to-count-files-in-directory-on-linux/ ,
# https://stackoverflow.com/a/45591665/3223785 ]
function f_check_disk_space(){
    : 'Check that there is enough disk space for the files that will be created.'

    f_div_section
    f_process_in_progress "a" " > Checking resources..."
    local BSP_QTTY=$(find "$WORK_FOLDER_MAPS_S" -maxdepth 1 -type f -iname "*.bsp" | wc -l)
    # BSP_QTTY_KB=$((116117*$BSP_QTTY)) # GOLD!
    local BSP_QTTY_KB=$((180000*$BSP_QTTY))
    local DF_QTTY_KB=$(df -Pk "$WORK_FOLDER_S" | tail -1 | awk '{print $4}')
    f_bytes_n_units $BSP_QTTY_KB "KB" "GB"
    local BSP_QTTY_GB=$F_BYTES_N_UNITS_R
    f_bytes_n_units $DF_QTTY_KB "KB" "GB"
    local DF_QTTY_GB=$F_BYTES_N_UNITS_R
    local DISK_WARNING=""
    if (( $(echo $BSP_QTTY_GB $DF_QTTY_GB | awk '{if ($1 > $2) print 1;}') )); then
        DISK_WARNING=" (!!! DISK SPACE WARNING !!!)"
    fi
    f_process_in_progress "o"
    f_div_section
    f_yes_no "You have $BSP_QTTY maps (*.bsp) which will result in APPROXIMATELY $BSP_QTTY_GB GB on your disk.
Your free disk space is $DF_QTTY_GB GB$DISK_WARNING.
Is this OK for you?"
    if [ ${YES_NO_R} -eq 0 ] ; then
        f_okay_exit "Canceled by user."
    fi
    f_manage_logs " > Disk consumption accepted (APPROXIMATELY $BSP_QTTY_GB GB)." "o" 1
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Back up the "detail", "env" folders and the "*_detail.txt" files.
# --------------------------------------

# > -----------------------------------------
# Back up the "detail", "env" folders and the "*_detail.txt" files.

# [Ref(s).: https://unix.stackexchange.com/a/154819/61742 ,
# https://stackoverflow.com/a/5241677/3223785 ,
# https://unix.stackexchange.com/a/714059/61742 ,
# https://stackoverflow.com/a/53228677/3223785 ]
declare -a F_BACKUP_FILES_N_FOLDERS_R=()
function f_backup_files_n_folders(){
    : 'Back up the "detail", "env" folders, (\"maps\" folder) \"*_detail.txt\" files and (\"cstrike\" folder) \"*.wad\" files.'

    # NOTE: "detail" folder backup. By Questor
    f_div_section
    f_process_in_progress "a" " > Backing up \"detail\" folder..."
    f_ez_backup "$WORK_FOLDER_DETAIL_S"
    mkdir "$WORK_FOLDER_DETAIL_S"
    cd "$F_EZ_BACKUP_PATH_R"
    f_get_stderr_stdout "tar -czf \"$F_EZ_BACKUP_NAME_R.tar.gz\" \"$F_EZ_BACKUP_NAME_R\""
    if [ -n "$F_EZ_BACKUP_NAME_R" ] ; then
        rm -rf "$F_EZ_BACKUP_NAME_R"
    fi
    cd "$SCRIPT_DIR_S"
    if [ "$F_GET_STDERR_R" != "" ] || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
        f_process_in_progress "o"
        local ERROR_NOW="An error occurred while compressing the backup folder!
ERROR: \"$F_GET_STDERR_R\"
FOLDER: \"$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R\""
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    fi
    F_BACKUP_FILES_N_FOLDERS_R+=("$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R.tar.gz")
    f_process_in_progress "o"
    f_manage_logs " > Backup of \"detail\" folder done." "o" 1

    # NOTE: "env" folder backup. By Questor
    f_div_section
    f_process_in_progress "a" " > Backing up \"env\" folder..."
    f_ez_backup "$WORK_FOLDER_ENV_S" 0 1
    cd "$F_EZ_BACKUP_PATH_R"
    f_get_stderr_stdout "tar -czf \"$F_EZ_BACKUP_NAME_R.tar.gz\" --transform \"s/^\.\/env/$F_EZ_BACKUP_NAME_R/\" \"./env\""
    cd "$SCRIPT_DIR_S"
    if [ "$F_GET_STDERR_R" != "" ] || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
        f_process_in_progress "o"
        local ERROR_NOW="An error occurred while compressing the backup folder!
ERROR: \"$F_GET_STDERR_R\"
FOLDER: \"$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R\""
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    fi
    F_BACKUP_FILES_N_FOLDERS_R+=("$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R.tar.gz")
    f_process_in_progress "o"
    f_manage_logs " > Backup of \"env\" folder done." "o" 1

    # NOTE: ("maps" folder) "*_detail.txt" files backup. By Questor
    f_div_section
    f_process_in_progress "a" " > Backing up (\"maps\" folder) \"*_detail.txt\" files..."
    f_ez_backup "${WORK_FOLDER_MAPS_S}_detail" 0 1
    mkdir "$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R"
    find "$WORK_FOLDER_MAPS_S" -maxdepth 1 -type f -iname "*_detail.txt" -exec cp -t "$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R/" {} +
    cd "$F_EZ_BACKUP_PATH_R"
    f_get_stderr_stdout "tar -czf \"$F_EZ_BACKUP_NAME_R.tar.gz\" \"$F_EZ_BACKUP_NAME_R\""
    if [ -n "$F_EZ_BACKUP_NAME_R" ] ; then
        rm -rf "$F_EZ_BACKUP_NAME_R"
    fi
    cd "$SCRIPT_DIR_S"
    if [ "$F_GET_STDERR_R" != "" ] || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
        f_process_in_progress "o"
        local ERROR_NOW="An error occurred while compressing the backup folder!
ERROR: \"$F_GET_STDERR_R\"
FOLDER: \"$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R\""
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    else
        rm -rf "$F_EZ_BACKUP_NAME_R"
    fi
    F_BACKUP_FILES_N_FOLDERS_R+=("$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R.tar.gz")
    f_process_in_progress "o"
    f_manage_logs " > Backup of (\"maps\" folder) \"*_detail.txt\" files done." "o" 1

    # NOTE: ("cstrike" folder) "*.wad" files backup. By Questor
    f_div_section
    f_process_in_progress "a" " > Backing up (\"cstrike\" folder) \"*.wad\" files..."
    f_ez_backup "${WORK_FOLDER_CSTRIKE_S}_wad" 0 1
    mkdir "$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R"
    find "$WORK_FOLDER_CSTRIKE_S" -maxdepth 1 -type f -iname "*.wad" -exec cp -t "$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R/" {} +
    cd "$F_EZ_BACKUP_PATH_R"
    f_get_stderr_stdout "tar -czf \"$F_EZ_BACKUP_NAME_R.tar.gz\" \"$F_EZ_BACKUP_NAME_R\""
    if [ -n "$F_EZ_BACKUP_NAME_R" ] ; then
        rm -rf "$F_EZ_BACKUP_NAME_R"
    fi
    cd "$SCRIPT_DIR_S"
    if [ "$F_GET_STDERR_R" != "" ] || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
        f_process_in_progress "o"
        local ERROR_NOW="An error occurred while compressing the backup folder!
ERROR: \"$F_GET_STDERR_R\"
FOLDER: \"$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R\""
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    else
        rm -rf "$F_EZ_BACKUP_NAME_R"
    fi
    F_BACKUP_FILES_N_FOLDERS_R+=("$F_EZ_BACKUP_PATH_R/$F_EZ_BACKUP_NAME_R.tar.gz")
    f_process_in_progress "o"
    f_manage_logs " > Backup of (\"cstrike\" folder) \"*.wad\" files done." "o" 1

}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Defining some BSP entities and other information.
# --------------------------------------

# > -----------------------------------------
# Defining "skynames" images to be processed and calculate image upscale factor.

# NOTE: Consumed by the functions "f_define_skyname" and "f_add_skynames_to_extras_txt".
# By Questor
declare -a SKY_SIDES=("rt" "bk" "lf" "ft" "up" "dn")

SKY_NAME_STATUS_R=""
SKY_NAME_FILE_MISSING_R=0
declare -a F_SKYNAME_N_UPSCL_FACT_R=()
function f_define_skyname(){
    : 'Defining "skynames" images to be processed and calculate image upscale factor.

    Args:
        ENT_FILE (str): Input entity file;
        BSP_NAME (str): BSP file name;
        BSP_FILE (str): BSP file path and name.
    '

    local ENT_FILE=$1
    local BSP_NAME=$2
    local BSP_FILE=$3
    local SKY_NAME_LINE=""
    local SKY_NAME=""
    local SKY_ITEM=""
    f_process_in_progress "a" " > Defining \"skyname\"..."
    SKY_NAME_LINE=$(grep -m 1 -a "\"skyname\" \"" "$ENT_FILE")
    SKY_NAME_STATUS_R="BSP file does not have \"skyname\""
    if [ -n "$SKY_NAME_LINE" ] ; then
        f_master_splitter "$SKY_NAME_LINE" "\""
        SKY_NAME="${F_MASTER_SPLITTER_R[3]}"
        F_SKYNAME_N_UPSCL_FACT_R+=("$BSP_NAME")
        SKY_NAME_STATUS_R="BSP file \"skyname\" components defined"
        for ((j=0;j<=5;j++)); do
            SKY_ITEM=$(find "$WORK_FOLDER_ENV_S" -maxdepth 1 -type f -iname "${SKY_NAME}${SKY_SIDES[$j]}.tga" -print -quit)
            if [ -z "$SKY_ITEM" ] ; then
                SKY_NAME_FILE_MISSING_R=1
                SKY_NAME_STATUS_R="\"Skyname\" file(s) required by the BSP file missing"
                f_manage_logs "A \"skyname\" file (TGA) is missing!
TGA: $WORK_FOLDER_ENV_S/${SKY_NAME}${SKY_SIDES[$j]}.tga (use case-insensitive path)
BSP: $BSP_FILE" "e"
            elif [ ${j} -eq 0 ] ; then
                f_upscl_fact_calc "$SKY_ITEM"
                F_SKYNAME_N_UPSCL_FACT_R+=($F_UPSCL_CALC_R)
            fi
            F_SKYNAME_N_UPSCL_FACT_R+=("$SKY_ITEM")
        done
    fi
    f_process_in_progress "o"
}

# < -----------------------------------------

# > -----------------------------------------
# Defining WAD file(s) in use by a BSP file.

# [Ref(s).: https://stackoverflow.com/a/3686056/3223785 ]
WADS_STATUS_R=""
declare -a WADS_IN_USE_R=()
function f_define_wads(){
    : 'Defining WAD file(s) in use by a BSP file.

    Args:
        ENT_FILE (str): Input entity file.
    '

    # IMPORTANT: Not all WAD files listed in a BSP will be required for it. But with
    # this strategy we eliminate those that are not used in any BSP, avoiding the
    # processing (upscaling) of unnecessary textures. The upscaling process is critical
    # and can be very, very time consuming. Automatic Detail Texture Generator 2007
    # (DTG07) is limited to extracting images from all WADs in the "cstrike" folder
    # without checking that they are consumed by some BSP. We couldn't figure out
    # a strategy to effectively define which WAD files are consumed by each BSP.
    # By Questor

    local ENT_FILE=$1
    local WAD_LINE=""
    declare -a WAD_ITEMS=()
    local WAD_ITEM=""
    local LENGTH_A=0
    local LENGTH_B=0
    local ADD_WAD_ITEM=0
    local i=0
    local j=0
    f_process_in_progress "a" " > Defining BSP file WAD file(s)..."
    WAD_LINE=$(grep -m 1 -a "\"wad\" \"" "$ENT_FILE")
    WADS_STATUS_R="BSP file does not have WAD file(s)"
    if [ -n "$WAD_LINE" ] ; then
        f_master_splitter "$WAD_LINE" "\""
        f_master_splitter "$WAD_LINE" "\""
        f_master_splitter "${F_MASTER_SPLITTER_R[3]}" ";"
        WAD_ITEMS=("${F_MASTER_SPLITTER_R[@]}")
        LENGTH_A=${#WAD_ITEMS[*]}

        # NOTE: When the "wad" attribute is empty, the split will return only one
        # item and it will be empty. When not, it will always have a "length" greater
        # than 2 and the last item will be empty. By Questor
        if [ $LENGTH_A -gt 1 ] ; then
            WADS_STATUS_R="BSP file have unnecessary WAD file(s)"
            for ((i=0;i<=$(($LENGTH_A-2));i++)); do
            # NOTE: The last item is always empty. Hence the value "-2". By Questor

                if [[ "${WAD_ITEMS[$i]}" == *"/"* ]] ; then
                # NOTE: The reason for this conditional is because there was a case
                # using slash and not backslash in our tests. Just in case we decided
                # to add this variant. By Questor

                    f_master_splitter "${WAD_ITEMS[$i]}" "/"
                else
                    f_master_splitter "${WAD_ITEMS[$i]}" "\\"
                fi

                WAD_ITEM=$(find "$WORK_FOLDER_CSTRIKE_S" -maxdepth 1 -type f -iname "${F_MASTER_SPLITTER_R[-1]}" -print -quit 2> /dev/null)
                if [ -n "$WAD_ITEM" ] ; then
                    WADS_STATUS_R="BSP file required WAD file(s) defined"
                    ADD_WAD_ITEM=1
                    LENGTH_B=${#WADS_IN_USE_R[*]}
                    for ((j=0;j<=$(($LENGTH_B-1));j++)); do
                    # NOTE: Avoid repeated items in the array. BASH does not have
                    # native functionality for this. By Questor

                        if [ "${WADS_IN_USE_R[$j]}" == "$WAD_ITEM" ] ; then
                            ADD_WAD_ITEM=0
                            break
                        fi
                    done
                    if [ ${ADD_WAD_ITEM} -eq 1 ] ; then
                        WADS_IN_USE_R+=("$WAD_ITEM")
                    fi
                fi
            done
        fi
    fi
    f_process_in_progress "o"
}

# < -----------------------------------------

# > -----------------------------------------
# Exporting BSP entities and it triggers other methods to process that data.

# [Ref(s).: https://stackoverflow.com/q/2664740/3223785 ,
# https://stackoverflow.com/a/36341390/3223785 ,
# https://stackoverflow.com/a/16623897/3223785 ,
# https://unix.stackexchange.com/a/333133/61742 ,
# https://stackoverflow.com/a/23512981/3223785 ,
# https://stackoverflow.com/a/14093511/3223785 ,
# https://unix.stackexchange.com/a/62883/61742 ]
function f_export_bsp_entities(){
    : 'Exporting BSP entities and it triggers other methods to process that data.'

    f_process_in_progress "a" " > Listing BSP files..."
    declare -a BSP_FILES=()
    while IFS= read -r -d '' INPUT_FILE; do
        BSP_FILES+=("$INPUT_FILE")
    done < <(find "$WORK_FOLDER_MAPS_S" -maxdepth 1 -type f -iname "*.bsp" -print0)
    f_process_in_progress "o"
    local BSP_NAME=""
    local ENT_FILE=""
    local LENGTH=${#BSP_FILES[*]}
    f_long_task_stats "s" $LENGTH
    local i=0
    local j=0
    for ((i=0;i<=$(($LENGTH-1));i++)); do
        f_long_task_stats "a"
        f_process_in_progress "a" " > Exporting BSP file entities..."
        f_get_stderr_stdout "$RIPENT_CMD_S"

        # NOTE: The "[...]Gtk-WARNING **: 18:46:37.008: Theme parsing error: gtk.css:[...]"
        # warning returned by wine was generating a false error detection as the
        # application is not crashing. By Questor
        if ( [[ "$F_GET_STDERR_R" != "" ]] && [[ "$F_GET_STDERR_R" != *"Theme parsing error"* ]] ) || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
            f_process_in_progress "o"
            local ERROR_NOW="An error occurred while exporting the BSP entities!
ERROR: $F_GET_STDERR_R
FILE: ${BSP_FILES[$i]}"
            f_manage_logs "$ERROR_NOW" "e"
            f_error_exit "$ERROR_NOW"
        fi

        BSP_NAME=$(basename "${BSP_FILES[$i]}" ".${BSP_FILES[$i]##*.}")
        ENT_FILE="$WORK_FOLDER_MAPS_S/$BSP_NAME.ent"
        f_process_in_progress "o"
        f_define_skyname "$ENT_FILE" "$BSP_NAME" "${BSP_FILES[$i]}"
        if [ ${SKY_NAME_FILE_MISSING_R} -eq 0 ] ; then
            f_define_wads "$ENT_FILE" "${BSP_FILES[$i]}"
        else
            # NOTE: In case of missing skyname(s), execution will stop after checking
            # these anyway. By Questor

            WADS_STATUS_R="Defining BSP file WAD file(s) skipped"
        fi
        rm -f "$ENT_FILE"
        f_long_task_stats "o"
        f_manage_logs " > $SKY_NAME_STATUS_R/$WADS_STATUS_R: ${BSP_FILES[$i]}
$F_LONG_TASK_STATS_R" "o" 1
    done
    if [ ${SKY_NAME_FILE_MISSING_R} -eq 1 ] ; then
        local ERROR_NOW="There are missing \"skyname\" file(s). See the log file below for what they are.
ERROR_LOG: $ERROR_LOG_PATH_N_NAME"
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    fi
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Remove unused WAD files.
# --------------------------------------

# > -----------------------------------------
# Remove unused WAD files.

function f_remove_unused_wads(){
    : 'Remove unused WAD files.'

    f_process_in_progress "a" " > Listing WAD files..."
    declare -a WAD_FILES=()
    while IFS= read -r -d '' INPUT_FILE; do
        WAD_FILES+=("$INPUT_FILE")
    done < <(find "$WORK_FOLDER_CSTRIKE_S" -maxdepth 1 -type f -iname "*.wad" -print0)
    f_process_in_progress "o"

    local RM_WAD_ITEM=0
    local WADS_IN_USE_ITEM=""
    local ACTION_NOW=""
    local LENGTH_A=${#WAD_FILES[*]}
    local LENGTH_B=${#WADS_IN_USE_R[*]}
    f_long_task_stats "s" $LENGTH_A
    local i=0
    local j=0
    for ((i=0;i<=$(($LENGTH_A-1));i++)); do
        f_long_task_stats "a"
        RM_WAD_ITEM=1
        for ((j=0;j<=$(($LENGTH_B-1));j++)); do
            if [ "${WADS_IN_USE_R[$j]}" == "${WAD_FILES[$i]}" ] ; then
                RM_WAD_ITEM=0
                break
            fi
        done
        ACTION_NOW="WAD file kept"
        if [ ${RM_WAD_ITEM} -eq 1 ] ; then
            rm -f "${WAD_FILES[$i]}"
            ACTION_NOW="WAD file removed"
        fi
        f_long_task_stats "o"
        f_manage_logs " > $ACTION_NOW: ${WAD_FILES[$i]}
$F_LONG_TASK_STATS_R" "o" 1
    done
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Run Detail Texture Generator 2007 (DTG07) program to extract maps textures.
# --------------------------------------

# > -----------------------------------------
# Run Detail Texture Generator 2007 (DTG07) program to extract maps textures.

function f_run_det_texture_gen_07(){
    : 'Run Detail Texture Generator 2007 (DTG07) program to extract maps textures.

    Furthermore, it will modify the behavior of DTG07, forcing an error to occur.
    In this way it is possible to extract all BMPs related to all maps without having
    them converted to TGA in grayscale.
    '

    rm -rf "$WINE_DRIVE_C_S/__CS16__"
    mkdir "$WINE_DRIVE_C_S/__CS16__"
    f_get_stderr_stdout "ln -s \"$WORK_FOLDER_S\" \"$WINE_DRIVE_C_S/__CS16__\""

    # NOTE: To avoid problem with remaining symbolic link in case of error. By Questor
    f_ez_trap_add "rm -rf \"$WINE_DRIVE_C_S/__CS16__\"" SIGINT SIGTERM ERR EXIT

    if [ "$F_GET_STDERR_R" != "" ] || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
        local ERROR_NOW="An error occurred while creating the symbolic link!
ERROR: \"$F_GET_STDERR_R\""
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    fi
    rm -f "$WORK_FOLDER_CSTRIKE_S/!!!!!!!!!!!!.wad"
    echo -n "SYNDROME" > "$WORK_FOLDER_CSTRIKE_S/!!!!!!!!!!!!.wad"
    rm -rf "$WORK_FOLDER_DETAIL_S/!!!!!!!!!!!!"
    mkdir -p "$WORK_FOLDER_DETAIL_S/!!!!!!!!!!!!/root"
    echo -n "SYNDROME" > "$WORK_FOLDER_DETAIL_S/!!!!!!!!!!!!/root/!!!!!!!!!!!!.bmp"
    f_enter_to_cont "Run Detail Texture Generator 2007 (DTG07) program to extract
maps textures.

INSTRUCTIONS:
 I - Select CS 1.6 main folder and click \"MAKE DETAIL TEXTURES\";
  a - The main CS 1.6 folder will be in the folder \"__CS16__\";
  b - This folder is the one containing the main CS 1.6 executable (\"hl.exe\", for
example).
 II - \"Syndrome\" files was created in the \"cstrike\" and \"detail\" folders.
This files will CAUSE A PURPOSEFUL ERROR in the execution of DTG07;
  a - Everything will be finished when DTG07 displays an error dialog (\"Stream read
error\") and something like this in the main window...
\"\"\"
[...]
Counting .BMP files that will be converted to .TGA
Making details from extracted textures \".BMP\" and converting to \".TGA\"
Making details from cs wads textures
Converting: \"!!!!!!!!!!!!\"
\"\"\";
 b - After \"finishing\" the execution of DTG07, close it so that this script execution
continues.
 III - DO NOT CLOSE THIS TERMINAL!"
    f_get_stderr_stdout "$DTG07_CMD_S"
    if [ "$F_GET_STDERR_R" != "" ] && [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
        rm -f "$WORK_FOLDER_CSTRIKE_S/!!!!!!!!!!!!.wad"
        rm -rf "$WORK_FOLDER_DETAIL_S/!!!!!!!!!!!!"
        rm -rf "$WINE_DRIVE_C_S/__CS16__"
        local ERROR_NOW="An error occurred while running Automatic Detail Texture Generator 2007 (DTG07)!
ERROR: \"$F_GET_STDERR_R\""
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    fi
    rm -f "$WORK_FOLDER_CSTRIKE_S/!!!!!!!!!!!!.wad"
    rm -rf "$WORK_FOLDER_DETAIL_S/!!!!!!!!!!!!"
    rm -rf "$WINE_DRIVE_C_S/__CS16__"
    f_div_section
    f_yes_no "Did everything go as expected when running Automatic Detail Texture Generator 2007 (DTG07)?"
    if [ ${YES_NO_R} -eq 0 ] ; then
        local ERROR_NOW="An error occurred while running Automatic Detail Texture Generator 2007 (DTG07)!"
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    fi
    f_manage_logs " > Textures extracted with Automatic Detail Texture Generator 2007 (DTG07)." "o" 1
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Calculate image upscale factor.
# --------------------------------------

# > -----------------------------------------
# Calculate image upscale factor.

declare -a VALID_UPSCALE_VALS=()
if [ "$UPSCALER_IN_USE_S" == "w" ] ; then
    VALID_UPSCALE_VALS=(1 2 4 8 16 32)
elif [ "$UPSCALER_IN_USE_S" == "r" ] ; then
    VALID_UPSCALE_VALS=(1 2 4)
fi
F_UPSCL_CALC_R=0
function f_upscl_fact_calc(){
    : 'Calculate image upscale factor.

    Args:
        F_IMAGE_FILE (str): Image to set the upscale factor.

    Returns:
        F_UPSCL_CALC_R (int): Upscale factor.
    '

    F_IMAGE_FILE=$1
    F_UPSCL_CALC_R=0
    declare -a IMG_W_H=()
    local HI_VALUE=0
    local LENGTH_B=0
    f_get_stderr_stdout "identify -format \"%w %h\" \"$F_IMAGE_FILE\""
    if [ "$F_GET_STDERR_R" != "" ] || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
        local ERROR_NOW="An error occurred while calculating image scaling!
ERROR: \"$F_GET_STDERR_R\"
FILE: \"$F_IMAGE_FILE\""
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    fi
    IMG_W_H=($F_GET_STDOUT_R)
    if (( IMG_W_H[0] >= IMG_W_H[1] )) ; then
        HI_VALUE=${IMG_W_H[0]}
    else
        HI_VALUE=${IMG_W_H[1]}
    fi

    # NOTE: All images that will be processed are multiples of 8 in px. By Questor
    F_UPSCL_CALC_R=$((1024/$HI_VALUE))
    if (( F_UPSCL_CALC_R > MAX_UPSCL_FACT_S )) ; then
        F_UPSCL_CALC_R=$MAX_UPSCL_FACT_S
    else
        LENGTH_B=${#VALID_UPSCALE_VALS[*]}
        local i=0
        for ((i=0;i<=$(($LENGTH_B-1));i++)); do
            if [ ${VALID_UPSCALE_VALS[$i]} -eq $F_UPSCL_CALC_R ] ; then
                break
            fi
            if [ ${VALID_UPSCALE_VALS[$i]} -gt $F_UPSCL_CALC_R ] ; then
                F_UPSCL_CALC_R=${VALID_UPSCALE_VALS[$((i - 1))]}
                break
            fi
        done
    fi

}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Listing textures images to be processed and calculate image upscale factor.
# --------------------------------------

# > -----------------------------------------
# Listing textures images to be processed and calculate image upscale factor.

declare -a F_TEXTURE_N_UPSCL_FACT_R=()
function f_list_textures(){
    : 'Listing textures images to be processed and calculate image upscale factor.'

    declare -a F_BMP_IMAGES_R=()
    local INPUT_FOLDER=""
    local INPUT_FILE=""

    # [Ref(s).:  https://superuser.com/a/370982/195840 ,
    # https://stackoverflow.com/a/18093887/3223785 ,
    # https://serverfault.com/a/739037/276753 ]
    f_process_in_progress "a" " > Listing textures..."
    while IFS= read -r -d '' INPUT_FOLDER; do
        while IFS= read -r -d '' INPUT_FILE; do
            F_BMP_IMAGES_R+=("$INPUT_FILE")
        done < <(find "$INPUT_FOLDER/root" -maxdepth 1 -type f -iname "*.bmp" -print0)
    done < <(find "$WORK_FOLDER_DETAIL_S" -maxdepth 1 -type d -exec test -e '{}'/root \; -print0)
    # NOTE: We need to use process substitution to prevent external variables from
    # losing their scope. By Questor
    # [Ref(s).: https://stackoverflow.com/a/7612420/3223785 ]

    f_process_in_progress "o"
    f_manage_logs " > Textures listed." "o" 1

    local LENGTH=${#F_BMP_IMAGES_R[*]}
    f_long_task_stats "s" $LENGTH 1 0
    local i=0
    for ((i=0;i<=$(($LENGTH-1));i++)); do
        f_long_task_stats "a"
        f_upscl_fact_calc "${F_BMP_IMAGES_R[$i]}"
        F_TEXTURE_N_UPSCL_FACT_R+=("${F_BMP_IMAGES_R[$i]}")
        F_TEXTURE_N_UPSCL_FACT_R+=($F_UPSCL_CALC_R)
        f_long_task_stats "o"
        f_manage_logs " > Upscaling factor calculated: ${F_BMP_IMAGES_R[$i]}
UPSCALING FACTOR: $F_UPSCL_CALC_R
$F_LONG_TASK_STATS_R" "o" 1
    done
    if [ ${LENGTH} -lt 1 ] ; then
        local ERROR_NOW="No \"root\" folder (BMPs folder) found!
Did you run Automatic Detail Texture Generator 2007 (DTG07) as expected?
Are the settings in the \"config.bash\" file correct?"
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    fi
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Convert TGA "skyname" to PNG.
# --------------------------------------

# > -----------------------------------------
# Convert TGA "skyname" to PNG.

function f_conv_skyname_tga_to_png(){
    : 'Convert TGA "skyname" to PNG.'

    local PNG_DIR=""
    local OUTPUT_FILE=""
    local LENGTH_A=${#F_SKYNAME_N_UPSCL_FACT_R[*]}
    local LENGTH_B=$(($LENGTH_A-(($LENGTH_A/8)*2)))
    f_long_task_stats "s" $LENGTH_B
    local i=0
    local j=0
    for ((i=0;i<=$(($LENGTH_A-1));i+=8)); do
        for ((j=$(($i+2));j<=$(($i+7));j++)); do
            f_long_task_stats "a"
            if [ -f "${F_SKYNAME_N_UPSCL_FACT_R[$j]}" ] ; then
            # NOTE: Some maps share the same "skyname". As these files are all validated
            # for their existence in a previous step, so if the file is not present,
            # it is because it has already been converted. By Questor

                if [ -z "$PNG_DIR" ] ; then
                    PNG_DIR="$(dirname "${F_SKYNAME_N_UPSCL_FACT_R[$j]}")/_PNG"
                    mkdir -p "$PNG_DIR"
                fi
                OUTPUT_FILE="$PNG_DIR/"$(basename "${F_SKYNAME_N_UPSCL_FACT_R[$j]}" ".${F_SKYNAME_N_UPSCL_FACT_R[$j]##*.}")".png"

                # NOTE: For some reason "convert" (ImageMagick) inverts the image when
                # converting TGAs. By Questor
                f_get_stderr_stdout "convert \"${F_SKYNAME_N_UPSCL_FACT_R[$j]}\" -flip \"$OUTPUT_FILE\""

                if [ "$F_GET_STDERR_R" != "" ] || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
                    local ERROR_NOW="An error occurred while converting the image to PNG (\"skyname\")!
ERROR: \"$F_GET_STDERR_R\"
FILE: \"${F_SKYNAME_N_UPSCL_FACT_R[$j]}\""
                    f_manage_logs "$ERROR_NOW" "e"
                    f_error_exit "$ERROR_NOW"
                fi
                rm -f "${F_SKYNAME_N_UPSCL_FACT_R[$j]}"
                f_long_task_stats "o"
            else
                f_long_task_stats "k"
            fi
            f_manage_logs " > Converted to PNG (\"skyname\"): ${F_SKYNAME_N_UPSCL_FACT_R[$j]}
$F_LONG_TASK_STATS_R" "o" 1
        done
    done
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Convert texture BMP to PNG.
# --------------------------------------

# > -----------------------------------------
# Convert texture BMP to PNG.

# [Ref(s).: https://stackoverflow.com/a/73428638/3223785
# https://stackoverflow.com/a/73428638/3223785 ,
# https://legacy.imagemagick.org/discourse-server/viewtopic.php?p=41925#p41925 ,
# https://imagemagick.org/script/command-line-options.php ,
# https://legacy.imagemagick.org/discourse-server/viewtopic.php?p=65754&sid=7cfdfe8f5d3bd65e9da0b40f78e234d6#p65754 ]
function f_conv_texture_bmp_to_png(){
    : 'Convert texture BMP to PNG.'

    local PNG_DIR=""
    local OUTPUT_FILE=""
    local LENGTH=${#F_TEXTURE_N_UPSCL_FACT_R[*]}
    f_long_task_stats "s" $LENGTH 2 0
    local i=0
    for ((i=0;i<=$(($LENGTH-1));i+=2)); do
        f_long_task_stats "a"
        PNG_DIR="$(dirname "${F_TEXTURE_N_UPSCL_FACT_R[$i]}")/_PNG"
        OUTPUT_FILE="$PNG_DIR/"$(basename "${F_TEXTURE_N_UPSCL_FACT_R[$i]}" ".${F_TEXTURE_N_UPSCL_FACT_R[$i]##*.}")".png"
        mkdir -p "$PNG_DIR"

        # NOTE: We changed the image's blue - the engine's default image transparency
        # - to the effective PNG format transparency (alpha channel). By Questor
        f_get_stderr_stdout "convert \"${F_TEXTURE_N_UPSCL_FACT_R[$i]}\" -transparent \"#0000ff\" -alpha Associate \"$OUTPUT_FILE\""

        if [ "$F_GET_STDERR_R" != "" ] || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
            local ERROR_NOW="An error occurred while converting the image to PNG (texture)!
ERROR: \"$F_GET_STDERR_R\"
FILE: \"${F_TEXTURE_N_UPSCL_FACT_R[$i]}\""
            f_manage_logs "$ERROR_NOW" "e"
            f_error_exit "$ERROR_NOW"
        fi
        rm -f "${F_TEXTURE_N_UPSCL_FACT_R[$i]}"
        f_long_task_stats "o"
        f_manage_logs " > Converted to PNG (texture): ${F_TEXTURE_N_UPSCL_FACT_R[$i]}
$F_LONG_TASK_STATS_R" "o" 1
    done
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Modify details (\"*_detail.txt\") to Renderer 1.5c format.
# --------------------------------------

# > -----------------------------------------
# Modify details (\"*_detail.txt\") to Renderer 1.5c format.

# [Ref(s).: https://stackoverflow.com/a/24230154/3223785 ,
# https://stackoverflow.com/a/24233771/3223785 ,
# https://stackoverflow.com/a/27658733/3223785 ]
function f_modify_details_txt(){
    : 'Modify details (\"*_detail.txt\") to Renderer 1.5c format.'

    local INPUT_FILE=""
    f_process_in_progress "a" " > Listing details (\"*_detail.txt\")..."
    declare -a DETAIL_TXT_FILES=()
    while IFS= read -r -d '' INPUT_FILE; do
        DETAIL_TXT_FILES+=("$INPUT_FILE")
    done < <(find "$WORK_FOLDER_MAPS_S" -maxdepth 1 -type f -iname "*_detail.txt" -print0)
    f_process_in_progress "o"
    f_manage_logs " > Details (\"*_detail.txt\") listed." "o" 1
    local LENGTH=${#DETAIL_TXT_FILES[*]}
    f_long_task_stats "s" $LENGTH
    local i=0
    for ((i=0;i<=$(($LENGTH-1));i++)); do
        f_long_task_stats "a"
        sed -i '/	detail\//s/^/	{"base" : "/' "${DETAIL_TXT_FILES[$i]}"
        f_power_sed "	detail/" "\", \"replace\" : \"gfx/detail/_upscaled/" "${DETAIL_TXT_FILES[$i]}" "" 0
        f_power_sed "	1.0	1.0" ".png\", \"replacescale\" : \"1.0 1.0\"}," "${DETAIL_TXT_FILES[$i]}" "" 0
        sed -i -z 's/\t{"base" : "/\[\r\n\t{"base" : "/1' "${DETAIL_TXT_FILES[$i]}"
        sed -i -z 's/\(.*\)\.png", "replacescale" : "1\.0 1\.0"},/\1\.png", "replacescale" : "1\.0 1\.0"}\r\n\]/' "${DETAIL_TXT_FILES[$i]}"
        mv "${DETAIL_TXT_FILES[$i]}" "${DETAIL_TXT_FILES[$i]::-11}_extra.txt"
        f_long_task_stats "o"
        f_manage_logs " > Detail (\"*_detail.txt\") adjusted: ${DETAIL_TXT_FILES[$i]}
$F_LONG_TASK_STATS_R" "o" 1
    done
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Add "skynames" to extras (\"*_extra.txt\") (Renderer 1.5c).
# --------------------------------------

# > -----------------------------------------
# Add "skynames" to extras (\"*_extra.txt\") (Renderer 1.5c).

# [Ref(s).: https://stackoverflow.com/a/4182643/3223785 ,
# https://stackoverflow.com/a/24230154/3223785 ,
# https://stackoverflow.com/a/24233771/3223785 ,
# https://stackoverflow.com/a/27658733/3223785 ]
function f_add_skynames_to_extras_txt(){
    : 'Add "skynames" to extras (\"*_extra.txt\") (Renderer 1.5c).'

    local NEW_LINE=""
    local COMMA=""
    local INPUT_FILE=""
    local SKY_ITEMS=""
    local LENGTH_A=${#F_SKYNAME_N_UPSCL_FACT_R[*]}
    local LENGTH_B=$(($LENGTH_A/8))
    f_long_task_stats "s" $LENGTH_B
    local i=0
    local j=0
    local h=0
    for ((i=0;i<=$(($LENGTH_A-1));i+=8)); do
        f_long_task_stats "a"
        INPUT_FILE="${WORK_FOLDER_MAPS_S}/${F_SKYNAME_N_UPSCL_FACT_R[$i]}_extra.txt"
        NEW_LINE=""
        COMMA=","
        SKY_ITEMS=""
        h=0
        for ((j=$(($i+2));j<=$(($i+7));j++)); do
            if [ ${h} -eq 5 ] ; then
                COMMA=""
            fi
            SKY_ITEMS+="$NEW_LINE			\"${SKY_SIDES[$h]}\" : \"gfx/env/_upscaled/"$(basename "${F_SKYNAME_N_UPSCL_FACT_R[$j]}" ".${F_SKYNAME_N_UPSCL_FACT_R[$j]##*.}")".png\"$COMMA"
            NEW_LINE="
"
            ((h++))
        done
        f_power_sed "	{\"base\" : \"" "	{\"base\" : \"sky\", \"replace\" : 
		{
$SKY_ITEMS
		}
	},
	{\"base\" : \"" "$INPUT_FILE" "" 1

        # NOTE: Normalizing line endings to MS-DOS (CRLF). By Questor
        sed -i $'s/\r$//' "$INPUT_FILE"
        sed -i $'s/$/\r/' "$INPUT_FILE"

        f_long_task_stats "o"
        f_manage_logs " > \"Skyname\" added to extra (\"*_extra.txt\"): $INPUT_FILE
$F_LONG_TASK_STATS_R" "o" 1
    done
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Upscale image.
# --------------------------------------

# > -----------------------------------------
# Upscale image.

function f_upscale_image(){
    : 'Upscale image.

    Args:
        INPUT_FILE (str): Input image;
        OUTPUT_FILE (str): Output image;
        UPSCL_FACT (Optional[int]): Upscale factor. Required if '\''UPSCALER_IN_USE_S="w"'\''.
    '

    local INPUT_FILE=$1
    local OUTPUT_FILE=$2
    local UPSCL_FACT=$3
    local RSRGAN_TTA_MODE=""
    local BLOB_INDEX_ERROR_NOW=""
    if [ "$UPSCALER_IN_USE_S" == "w" ] ; then
        f_get_stderr_stdout "$WAIFU2X_BIN_S -i \"$INPUT_FILE\" -o \"$OUTPUT_FILE\" -s $UPSCL_FACT -n 3 -x"
        if (echo "$F_GET_STOUTERR" | grep -iq "error\|usage\|failed") || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
            f_process_in_progress "o"
            local ERROR_NOW="An error occurred while upscaling the PNG image ($WAIFU2X_BIN_S)!
ERROR: $F_GET_STOUTERR
FILE: $INPUT_FILE"
            f_manage_logs "$ERROR_NOW" "e"
            f_error_exit "$ERROR_NOW"
        fi
    elif [ "$UPSCALER_IN_USE_S" == "r" ] ; then
        if [ ${RSRGAN_ENABLE_TTA_S} -eq 1 ] ; then
            RSRGAN_TTA_MODE=" -x"
        fi

        # NOTE: This workaround is to handle an intermittent "realesrgan-ncnn-vulkan"
        # bug. By Questor
        while true ; do
            f_get_stderr_stdout "$REALESRGAN_BIN_S -i \"$INPUT_FILE\" -o \"$OUTPUT_FILE\"$RSRGAN_TTA_MODE -n realesrgan-x4plus"
            if [[ "$F_GET_STDERR_R" != *"find_blob_index_by_name data failed"* ]] ; then
                break
            else
                BLOB_INDEX_ERROR_NOW="An error occurred while upscaling the PNG image ($REALESRGAN_BIN_S)! A workaround was used to solve it.
ERROR: $F_GET_STDERR_R
FILE: $INPUT_FILE"
                f_manage_logs "$BLOB_INDEX_ERROR_NOW" "e"
            fi
        done

        # NOTE: Handle other possible errors. If so, execution will stop. By Questor
        if (echo "$F_GET_STOUTERR" | grep -iq "error\|usage\|failed") || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
            f_process_in_progress "o"
            local ERROR_NOW="An error occurred while upscaling the PNG image ($REALESRGAN_BIN_S)!
ERROR: $F_GET_STOUTERR
FILE: $INPUT_FILE"
            f_manage_logs "$ERROR_NOW" "e"
            f_error_exit "$ERROR_NOW"
        fi
    fi
}

# < -----------------------------------------

# > -----------------------------------------
# Upscale "skynames".

function f_upscale_skynames(){
    : 'Upscale "skynames".'

    local PNG_DIR=""
    local INPUT_FILE=""
    local UPSCL_DIR=""
    local OUTPUT_FILE=""
    local LENGTH_A=${#F_SKYNAME_N_UPSCL_FACT_R[*]}
    local LENGTH_B=$(($LENGTH_A-(($LENGTH_A/8)*2)))
    local UPSCL_FACT=0
    f_long_task_stats "s" $LENGTH_B
    local i=0
    local j=0
    for ((i=0;i<=$(($LENGTH_A-1));i+=8)); do
        UPSCL_FACT=${F_SKYNAME_N_UPSCL_FACT_R[$((i + 1))]}
        for ((j=$(($i+2));j<=$(($i+7));j++)); do
            f_long_task_stats "a"
            if [ -z "$PNG_DIR" ] ; then
                PNG_DIR="$(dirname "${F_SKYNAME_N_UPSCL_FACT_R[$j]}")/_PNG"
            fi
            INPUT_FILE="$PNG_DIR/"$(basename "${F_SKYNAME_N_UPSCL_FACT_R[$j]}" ".${F_SKYNAME_N_UPSCL_FACT_R[$j]##*.}")".png"
            if [ -f "$INPUT_FILE" ] ; then
            # NOTE: Necessary for when there is an unfinished upscale process. By Questor

                f_process_in_progress "a" " > Upscaling \"skyname\"..."
                if [ -z "$UPSCL_DIR" ] ; then
                    UPSCL_DIR="$(dirname "${F_SKYNAME_N_UPSCL_FACT_R[$j]}")/_UPSCL"
                    mkdir -p "$UPSCL_DIR"
                fi
                OUTPUT_FILE="$UPSCL_DIR/"$(basename "${F_SKYNAME_N_UPSCL_FACT_R[$j]}" ".${F_SKYNAME_N_UPSCL_FACT_R[$j]##*.}")".png"
                f_upscale_image "$INPUT_FILE" "$OUTPUT_FILE" $UPSCL_FACT
                rm -f "$INPUT_FILE"
                f_process_in_progress "o"
                f_long_task_stats "o"
            else
                f_long_task_stats "k"
            fi
            f_manage_logs " > Upscaled (\"skyname\"): $INPUT_FILE
$F_LONG_TASK_STATS_R" "o" 1
        done
    done
}

# < -----------------------------------------

# > -----------------------------------------
# Upscale textures.

# [Ref(s).: https://unix.stackexchange.com/a/132481/61742 , 
# https://unix.stackexchange.com/a/267065/61742 , 
# https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan#full-usages ]
function f_upscale_textures(){
    : 'Upscale textures.'

    local PNG_DIR=""
    local INPUT_FILE=""
    local UPSCL_DIR=""
    local OUTPUT_FILE=""
    local LENGTH=${#F_TEXTURE_N_UPSCL_FACT_R[*]}
    local UPSCL_FACT=0
    f_long_task_stats "s" $LENGTH 2 0
    local i=0
    for ((i=0;i<=$(($LENGTH-1));i+=2)); do
        f_long_task_stats "a"
        PNG_DIR="$(dirname "${F_TEXTURE_N_UPSCL_FACT_R[$i]}")/_PNG"
        INPUT_FILE="$PNG_DIR/"$(basename "${F_TEXTURE_N_UPSCL_FACT_R[$i]}" ".${F_TEXTURE_N_UPSCL_FACT_R[$i]##*.}")".png"
        if [ -f "$INPUT_FILE" ] ; then
        # NOTE: Necessary for when there is an unfinished upscale process. By Questor

            f_process_in_progress "a" " > Upscaling texture..."
            UPSCL_DIR="$(dirname "${F_TEXTURE_N_UPSCL_FACT_R[$i]}")/_UPSCL"
            mkdir -p "$UPSCL_DIR"
            OUTPUT_FILE="$UPSCL_DIR/"$(basename "${F_TEXTURE_N_UPSCL_FACT_R[$i]}" ".${F_TEXTURE_N_UPSCL_FACT_R[$i]##*.}")".png"
            UPSCL_FACT=${F_TEXTURE_N_UPSCL_FACT_R[$((i + 1))]}
            f_upscale_image "$INPUT_FILE" "$OUTPUT_FILE" $UPSCL_FACT
            rm -f "$INPUT_FILE"
            f_process_in_progress "o"
            f_long_task_stats "o"
        else
            f_long_task_stats "k"
        fi
        f_manage_logs " > Upscaled (texture): $INPUT_FILE
$F_LONG_TASK_STATS_R" "o" 1
    done
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Compress, move and/or resize a image.
# --------------------------------------

# > -----------------------------------------
# Compress, move and/or resize a image.

# [Ref(s).: https://stackoverflow.com/a/24421013/3223785 ]
F_COMPRESS_MOVE_N_OR_RESIZE_IMAGE_R=""
function f_compress_move_n_or_resize_image(){
    : 'Compress, move and/or resize a image.

    Args:
        INPUT_FILE (str): Input image;
        OUTPUT_FILE (str): Output image;
        UPSCL_FACT (Optional[int]): Upscale factor. Required if '\''UPSCALER_IN_USE_S="r"'\''.
    '

    F_COMPRESS_MOVE_N_OR_RESIZE_IMAGE_R=""
    local INPUT_FILE=$1
    local OUTPUT_FILE=$2
    local UPSCL_FACT=$3
    local RESIZE_FACT=0
    if [ "$UPSCALER_IN_USE_S" == "r" ] && [ $UPSCL_FACT -lt 4 ]; then
        f_process_in_progress "a" " > Resizing and moving the PNG image..."

        # NOTE: Due to a BUG in "realesrgan-ncnn-vulkan" it only supports upscaling
        # to 4. Therefore, we need to make size adjustments (reduce if necessary).
        # By Questor
        # [Ref(s).: https://legacy.imagemagick.org/Usage/resize/ , https://github-com.translate.goog/xinntao/Real-ESRGAN/issues/203?_x_tr_sl=
        # pt&_x_tr_tl=en&_x_tr_hl=en&_x_tr_pto=wapp ]
        RESIZE_FACT=$((100/(4/$UPSCL_FACT)))

        f_get_stderr_stdout "convert \"$INPUT_FILE\" -resize $RESIZE_FACT% \"$OUTPUT_FILE\""
        if [ "$F_GET_STDERR_R" != "" ] || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
            f_process_in_progress "o"
            local ERROR_NOW=="An error occurred while resizing the PNG image!
ERROR: $F_GET_STDERR_R
FILE: $INPUT_FILE"
            f_manage_logs "$ERROR_NOW" "e"
            f_error_exit "$ERROR_NOW"
        fi
        F_COMPRESS_MOVE_N_OR_RESIZE_IMAGE_R="resized, moved"
    else
        f_process_in_progress "a" " > Moving the PNG image..."
        mv "$INPUT_FILE" "$OUTPUT_FILE"
        F_COMPRESS_MOVE_N_OR_RESIZE_IMAGE_R="moved"
    fi
    rm -f "$INPUT_FILE"
    f_process_in_progress "o"
    f_process_in_progress "a" " > Compressing the PNG image..."
    f_get_stderr_stdout "oxipng -o 3 -i 1 --strip safe \"$OUTPUT_FILE\""
    if (echo "$F_GET_STOUTERR" | grep -iq "error\|usage\|failed") || [ $F_GET_EXIT_CODE_R -gt 0 ] ; then
        f_process_in_progress "o"
        local ERROR_NOW=="An error occurred while compressing the PNG image!
ERROR: $F_GET_STOUTERR
FILE: $OUTPUT_FILE"
        f_manage_logs "$ERROR_NOW" "e"
        f_error_exit "$ERROR_NOW"
    fi
    f_process_in_progress "o"
}

# < -----------------------------------------

# > -----------------------------------------
# Clean "skyname" folder.

function f_clean_skyname_fd(){
    : 'Clean "skyname" folder.'

    local ENV_ITEMS=$(find "$WORK_FOLDER_ENV_S" \
        -mindepth 1 \
        -maxdepth 1 \
        -iname "*" \
        -not -path "$WORK_FOLDER_ENV_S/_upscaled*" \
        -print \
        -quit)
    if [ -n "$ENV_ITEMS" ] ; then
    # NOTE: Necessary for when there is an unfinished upscale process. By Questor

        f_process_in_progress "a" " > Cleaning \"skyname\" folder..."
        find "$WORK_FOLDER_ENV_S" \
            -mindepth 1 -maxdepth 1 \
            -iname "*" \
            -not -path "$WORK_FOLDER_ENV_S/_upscaled*" \
            -exec rm -rf {} +
        f_process_in_progress "o"
        f_manage_logs " > \"Skyname\" folder cleaned." "o" 1
    else
        f_manage_logs " > Cleaning \"skyname\" folder skipped." "o" 1
    fi

}

# < -----------------------------------------

# > -----------------------------------------
# Compress, move and/or resize a skynames.

function f_compress_move_n_or_resize_skynames(){
    : 'Compress, move and/or resize a skynames.'

    local UPSCL_DIR=""
    local INPUT_FILE=""
    local OUTPUT_FILE=""
    local UPSCALED_DIR=""
    local UPSCL_FACT=0
    local LENGTH_A=${#F_SKYNAME_N_UPSCL_FACT_R[*]}
    local LENGTH_B=$(($LENGTH_A-(($LENGTH_A/8)*2)))
    f_long_task_stats "s" $LENGTH_B
    local i=0
    local j=0
    for ((i=0;i<=$(($LENGTH_A-1));i+=8)); do
        UPSCL_FACT=${F_SKYNAME_N_UPSCL_FACT_R[$((i + 1))]}
        for ((j=$(($i+2));j<=$(($i+7));j++)); do
            f_long_task_stats "a"
            if [ -z "$UPSCL_DIR" ] ; then
                UPSCL_DIR="$(dirname "${F_SKYNAME_N_UPSCL_FACT_R[$j]}")/_UPSCL"
            fi
            INPUT_FILE="$UPSCL_DIR/"$(basename "${F_SKYNAME_N_UPSCL_FACT_R[$j]}" ".${F_SKYNAME_N_UPSCL_FACT_R[$j]##*.}")".png"
            if [ -f "$INPUT_FILE" ] ; then
            # NOTE: Necessary for when there is an unfinished upscale process. By Questor

                if [ -z "$UPSCALED_DIR" ] ; then
                    UPSCALED_DIR="$(dirname "${F_SKYNAME_N_UPSCL_FACT_R[$j]}")/_upscaled"
                    mkdir -p "$UPSCALED_DIR"
                fi
                OUTPUT_FILE="$UPSCALED_DIR/"$(basename "${F_SKYNAME_N_UPSCL_FACT_R[$j]}" ".${F_SKYNAME_N_UPSCL_FACT_R[$j]##*.}")".png"
                f_compress_move_n_or_resize_image "$INPUT_FILE" "$OUTPUT_FILE" $UPSCL_FACT
                f_long_task_stats "o"
            else
                F_COMPRESS_MOVE_N_OR_RESIZE_IMAGE_R="<SKIPPED ITEM>"
                f_long_task_stats "k"
            fi
            f_manage_logs " > PNG $F_COMPRESS_MOVE_N_OR_RESIZE_IMAGE_R and compressed (\"skyname\"): $INPUT_FILE
$F_LONG_TASK_STATS_R" "o" 1
        done
    done
    f_clean_skyname_fd
}

# < -----------------------------------------

# > -----------------------------------------
# Clean and move texture folders.

# [Ref(s).: https://stackoverflow.com/a/15736463/3223785 ,
# https://unix.stackexchange.com/a/89937/61742 ]
function f_clean_n_move_texture_fds(){
    : 'Clean and move texture folders.'

    local ROOT_FOLDERS=$(find "$WORK_FOLDER_DETAIL_S" \
        -mindepth 2 \
        -maxdepth 2 \
        -name "root" \
        -type d \
        -print \
        -quit)
    if [ -n "$ROOT_FOLDERS" ] ; then
    # NOTE: Necessary for when there is an unfinished upscale process. By Questor

        f_process_in_progress "a" " > Cleaning texture folders..."

        # NOTE: Remove "root" folders. By Questor
        find "$WORK_FOLDER_DETAIL_S" \
            -mindepth 2 \
            -maxdepth 2 \
            -name "root" \
            -type d \
            -exec rm -rf {} +

        f_process_in_progress "o"
        f_manage_logs " > Texture folders cleaned." "o" 1
    else
        f_manage_logs " > Cleaning texture folders skipped." "o" 1
    fi

    local FOLDERS_TO_MOVE=$(find "$WORK_FOLDER_DETAIL_S" \
        -mindepth 1 \
        -maxdepth 1 \
        -iname "*" \
        -not -path "$WORK_FOLDER_DETAIL_S/_upscaled*" \
        -type d \
        -print \
        -quit)
    if [ -n "$FOLDERS_TO_MOVE" ] ; then
    # NOTE: Necessary for when there is an unfinished upscale process. By Questor

        f_process_in_progress "a" " > Moving texture folders..."

        # NOTE: Create a folder for the final destination of the folders with the
        # texture set for each map. By Questor
        mkdir -p "$WORK_FOLDER_DETAIL_S/_upscaled"

        # NOTE: Move the folders with the texture set for each map to the final destination.
        # By Questor
        find "$WORK_FOLDER_DETAIL_S" \
            -mindepth 1 -maxdepth 1 \
            -iname "*" \
            -not -path "$WORK_FOLDER_DETAIL_S/_upscaled*" \
            -type d \
            -exec mv -t "$WORK_FOLDER_DETAIL_S/_upscaled/" {} +

        f_process_in_progress "o"
        f_manage_logs " > Texture folders moved." "o" 1
    else
        f_manage_logs " > Moving texture folders skipped." "o" 1
    fi
}

# < -----------------------------------------

# > -----------------------------------------
# Compress, move and/or resize a textures.

# [Ref(s).: https://stackoverflow.com/a/27269509/3223785 ,
# https://sburris.xyz/posts/best-png-compression/ ,
# https://manpages.ubuntu.com/manpages/focal/en/man1/pngcrush.1.html ,
# https://github.com/shssoichiro/oxipng ]
function f_compress_move_n_or_resize_textures(){
    : 'Compress, move and/or resize a textures.'

    local UPSCL_DIR=""
    local INPUT_FILE=""
    local BSP_ENVS_FD=""
    local OUTPUT_FILE=""
    local UPSCL_FACT=0
    local LENGTH=${#F_TEXTURE_N_UPSCL_FACT_R[*]}
    f_long_task_stats "s" $LENGTH 2 0
    local i=0
    for ((i=0;i<=$(($LENGTH-1));i+=2)); do
        f_long_task_stats "a"
        UPSCL_DIR="$(dirname "${F_TEXTURE_N_UPSCL_FACT_R[$i]}")/_UPSCL"
        INPUT_FILE="$UPSCL_DIR/"$(basename "${F_TEXTURE_N_UPSCL_FACT_R[$i]}" ".${F_TEXTURE_N_UPSCL_FACT_R[$i]##*.}")".png"
        if [ -f "$INPUT_FILE" ] ; then
        # NOTE: Necessary for when there is an unfinished upscale process. By Questor

            BSP_ENVS_FD="${F_TEXTURE_N_UPSCL_FACT_R[$i]%/*/*}"
            OUTPUT_FILE="$BSP_ENVS_FD/"$(basename "${F_TEXTURE_N_UPSCL_FACT_R[$i]}" ".${F_TEXTURE_N_UPSCL_FACT_R[$i]##*.}")".png"
            UPSCL_FACT=${F_TEXTURE_N_UPSCL_FACT_R[$((i + 1))]}
            f_compress_move_n_or_resize_image "$INPUT_FILE" "$OUTPUT_FILE" $UPSCL_FACT
            f_long_task_stats "o"
        else
            F_COMPRESS_MOVE_N_OR_RESIZE_IMAGE_R="<SKIPPED ITEM>"
            f_long_task_stats "k"
        fi
        f_manage_logs " > PNG $F_COMPRESS_MOVE_N_OR_RESIZE_IMAGE_R and compressed (texture): $INPUT_FILE
$F_LONG_TASK_STATS_R" "o" 1
    done
    f_clean_n_move_texture_fds
}

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# MAIN SECTION:
# Control and manage script functions.
# --------------------------------------

# > -----------------------------------------
# Control and manage script functions.

USR_RESUME_PROCESS=0
f_resume_process "ck" "F_TEXTURE_N_UPSCL_FACT_R"
RESUME_PROCESS_MEMBERS=$(($RESUME_PROCESS_MEMBERS+$F_RESUME_PROCESS_R))
f_resume_process "ck" "F_BACKUP_FILES_N_FOLDERS_R"
RESUME_PROCESS_MEMBERS=$(($RESUME_PROCESS_MEMBERS+$F_RESUME_PROCESS_R))
f_resume_process "ck" "F_SKYNAME_N_UPSCL_FACT_R"
RESUME_PROCESS_MEMBERS=$(($RESUME_PROCESS_MEMBERS+$F_RESUME_PROCESS_R))
if [ ${RESUME_PROCESS_MEMBERS} -eq 3 ] ; then
    f_div_section
    f_yes_no "There is an unfinished upscale process.
Do you want to resume the process? (\"y\" highly recommended)"
    USR_RESUME_PROCESS=$YES_NO_R
    if [ ${USR_RESUME_PROCESS} -eq 1 ] ; then
        f_manage_logs " > Unfinished upscale process resumed." "o" 1
    else
        f_manage_logs " > Unfinished upscale process removed." "o" 1
    fi
fi

if [ ${USR_RESUME_PROCESS} -eq 1 ] ; then
    f_resume_process "rd" "F_TEXTURE_N_UPSCL_FACT_R"
    f_resume_process "rd" "F_BACKUP_FILES_N_FOLDERS_R"
    f_resume_process "rd" "F_SKYNAME_N_UPSCL_FACT_R"
else
    f_resume_process "rm" "F_TEXTURE_N_UPSCL_FACT_R"
    f_resume_process "rm" "F_BACKUP_FILES_N_FOLDERS_R"
    f_resume_process "rm" "F_SKYNAME_N_UPSCL_FACT_R"
    f_manage_logs " > Check disk space started." "o" 1
    f_check_disk_space
    f_manage_logs " > Backup files and folders started." "o" 1
    f_backup_files_n_folders
    f_manage_logs " > List \"skynames\" started." "o" 1
    f_export_bsp_entities
    f_manage_logs " > Remove unused WADs started." "o" 1
    f_remove_unused_wads
    f_manage_logs " > Run Detail Texture Generator 2007 (DTG07) started." "o" 1
    f_run_det_texture_gen_07
    f_manage_logs " > List textures started." "o" 1
    f_list_textures
    f_manage_logs " > Convert TGA \"skyname\" to PNG started." "o" 1
    f_conv_skyname_tga_to_png
    f_manage_logs " > Convert texture BMP to PNG started." "o" 1
    f_conv_texture_bmp_to_png
    f_manage_logs " > Modify details (\"*_detail.txt\") started." "o" 1
    f_modify_details_txt
    f_manage_logs " > Add \"skynames\" to extras (\"*_extra.txt\") started." "o" 1
    f_add_skynames_to_extras_txt
    f_resume_process "ct" "F_TEXTURE_N_UPSCL_FACT_R"
    f_manage_logs " > Failsafe file \"F_TEXTURE_N_UPSCL_FACT_R\" created." "o" 1
    f_resume_process "ct" "F_BACKUP_FILES_N_FOLDERS_R"
    f_manage_logs " > Failsafe file \"F_BACKUP_FILES_N_FOLDERS_R\" created." "o" 1
    f_resume_process "ct" "F_SKYNAME_N_UPSCL_FACT_R"
    f_manage_logs " > Failsafe file \"F_SKYNAME_N_UPSCL_FACT_R\" created." "o" 1
    f_manage_logs " > The script has enabled failsafe mode." "o" 1
    f_enter_to_cont "From now this script can be interrupted (use Ctrl+c) at any time 
and be resumed where it left off by running it again." 10
fi

f_manage_logs " > Upscale \"skynames\" started." "o" 1
f_upscale_skynames
f_manage_logs " > Upscale textures started." "o" 1
f_upscale_textures
f_manage_logs " > Compress, move and/or resize \"skynames\" started." "o" 1
f_compress_move_n_or_resize_skynames
f_manage_logs " > Compress, move and/or resize \"textures\" started." "o" 1
f_compress_move_n_or_resize_textures
f_resume_process "rm" "F_TEXTURE_N_UPSCL_FACT_R"
f_resume_process "rm" "F_BACKUP_FILES_N_FOLDERS_R"
f_resume_process "rm" "F_SKYNAME_N_UPSCL_FACT_R"

# < -----------------------------------------

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# End.
# --------------------------------------

# > -----------------------------------------
# List backup folders.

F_LIST_BACKUP_FOLDERS_R=""
function f_list_backup_folders(){
    : 'List backup folders.'

    local NEW_LINE=""
    local LENGTH=${#F_BACKUP_FILES_N_FOLDERS_R[*]}
    local i=0
    for ((i=0;i<=$(($LENGTH-1));i++)); do
        F_LIST_BACKUP_FOLDERS_R="$F_LIST_BACKUP_FOLDERS_R$NEW_LINE${F_BACKUP_FILES_N_FOLDERS_R[$i]}"
        NEW_LINE="
    "
    done
    f_manage_logs " > Backup folders listed." "o" 1
}

# < -----------------------------------------

# > -----------------------------------------
# End message.

f_manage_logs " > USCS16 - UpScaler CS 1.6 finished." "o"

read -r -d '' TITLE_F << "HEREDOC"
USCS16 - UpScaler CS 1.6 finished! Thanks!
HEREDOC

f_list_backup_folders
read -r -d '' USEFUL_INFO_F << HEREDOC
- To enable (if necessary) the detail textures type the following commands in the
 CS 1.6 console...
    r_detailtextures 1
    r_detailtexturessupported 1
    gl_max_size 16384

- To definitely apply the above settings, they must be in the configurations file...
    $WORK_FOLDER_CSTRIKE_S/userconfig.cfg

- Your backups...
    $F_LIST_BACKUP_FOLDERS_R
HEREDOC

f_end "$TITLE_F" "$USEFUL_INFO_F"

# < -----------------------------------------

# < --------------------------------------------------------------------------

exit 0
