#!/bin/bash

# > -----------------------------------------
# CONFIGURATION:

# IMPORTANT: Windows folder paths are case INsensitive, Linux is NOT! By Questor

# NOTE: Folder containing the main CS 1.6 executable ("hl.exe", for example). By Questor
WORK_FOLDER_S="/home/<SOME_USER>/Counter Strike 1.6"

# NOTE: Subfolder "cstrike" (relative). By Questor
WORK_FOLDER_CSTRIKE_S="$WORK_FOLDER_S/cstrike"

# NOTE: Subfolder "maps" (relative). By Questor
WORK_FOLDER_MAPS_S="$WORK_FOLDER_CSTRIKE_S/maps"

# NOTE: Subfolder "detail" (relative). By Questor
WORK_FOLDER_DETAIL_S="$WORK_FOLDER_CSTRIKE_S/gfx/detail"

# NOTE: Subfolder "env" (relative). By Questor
WORK_FOLDER_ENV_S="$WORK_FOLDER_CSTRIKE_S/gfx/env"

# NOTE: Upscaler in use:
# r - Realesrgan
# More realistic (more detailed) results, need more resources and limited to upscale by 4.
# w - Waifu2x
# More cartoonish (less detailed) results, needs fewer resources.
# . By Questor
UPSCALER_IN_USE_S="r"

# IMPORTANT: Due to a BUG in "realesrgan-ncnn-vulkan" it only supports upscaling
# to 4 (default). Therefore, we need to make size adjustments (reduce if necessary)
# when converting to TGA (512 px limit). For this same reason the value in MAX_UPSCL_FACT_S
# cannot be used because it generates decimal values in the calculations in the size
# adjustments. By Questor 20220714.2306
# [Ref(s).: https://github-com.translate.goog/xinntao/Real-ESRGAN/issues/203?_x_tr_sl=
# pt&_x_tr_tl=en&_x_tr_hl=en&_x_tr_pto=wapp ]

# NOTES:
# I - Maximum possible scaling factor for each image. No image can be larger than
# 1024 px in any dimension. Valid values are:
# . If Waifu2x ("w" above): 1, 2, 4, 8, 16 and 32;
# . If Realesrgan ("r" above): 1, 2, 3 and 4. Note that 4 is the only bug-free value.
# This is a Realesrgan bug. Therefore, DO NOT CHANGE this value.
# II - Values above 4 will hardly bring effective gains and will cause a lot of disk
# consumption.
# By Questor
MAX_UPSCL_FACT_S=4

# NOTE: Waifu2x binary name. By Questor
WAIFU2X_BIN_S="waifu2x-ncnn-vulkan"

# NOTE: Realesrgan binary name. By Questor
REALESRGAN_BIN_S="realesrgan-ncnn-vulkan"

# NOTE: Enable "tta mode" (1 - ON/0 - OFF). By Questor
# IMPORTANT: Enable this mode only if you have a powerful hardware setup, as it can
# make the process up to 8 times longer (it's already very time consuming naturally)
# for a quality gain of up to 15%. By Questor
RSRGAN_ENABLE_TTA_S=0

# IMPORTANT: You will need the latest version of Wine. We used version 21.0.0-cx
# (through PlayOnLinux) in our tests. By Questor 20220715.1858

# NOTE: AVluzacn's ZHLT v34 (ripent.exe) command. Do not use double quotes around the value of this parameter.
RIPENT_CMD_S='export WINEDEBUG=-all && export POL_IgnoreWineErrors=True && /usr/share/playonlinux4/playonlinux --run "ripent" -export "$(winepath -w "${BSP_FILES[$i]}" 2> /dev/null)"'

# RIPENT_CMD_S EXAMPLES:
#   * Using system Wine
# RIPENT_CMD_S='WINEDEBUG=-all wine "$SCRIPT_DIR_S/Vluzacn'"'"'s ZHLT v34/tools/ripent.exe" -export "$(winepath -w "${BSP_FILES[$i]}" 2> /dev/null)"'
#   * Using Wine with PlayOnLinux (Recommended)
# RIPENT_CMD_S='export WINEDEBUG=-all && export POL_IgnoreWineErrors=True && /usr/share/playonlinux4/playonlinux --run "ripent" -export "$(winepath -w "${BSP_FILES[$i]}" 2> /dev/null)"'
#   * Using a Wine prefix
# RIPENT_CMD_S='WINEDEBUG=-all WINEPREFIX="/home/<SOME_USER>/vluzacns_zhlt_v34" wine "$SCRIPT_DIR_S/Vluzacn'"'"'s ZHLT v34/tools/ripent.exe" -export "$(winepath -w "${BSP_FILES[$i]}" 2> /dev/null)"'

# NOTE: Automatic Detail Texture Generator 2007 command (DTG07) command. Do not use double quotes around the value of this parameter.
DTG07_CMD_S='export WINEDEBUG=-all && export POL_IgnoreWineErrors=True && /usr/share/playonlinux4/playonlinux --run "DetailTextureGen"'

# DTG07_CMD_S EXAMPLES:
#   * Using system Wine
# DTG07_CMD_S='WINEDEBUG=-all wine "$SCRIPT_DIR_S/Automatic Detail Texture Generator 2007/DetailTextureGen.exe"'
#   * Using Wine with PlayOnLinux (Recommended)
# DTG07_CMD_S='export WINEDEBUG=-all && export POL_IgnoreWineErrors=True && /usr/share/playonlinux4/playonlinux --run "DetailTextureGen"'
#   * Using a Wine prefix
# DTG07_CMD_S='WINEDEBUG=-all WINEPREFIX="/home/<SOME_USER>/cs16_txt_gen" wine "$SCRIPT_DIR_S/Automatic Detail Texture Generator 2007/DetailTextureGen.exe"'

# NOTE: Detail Texture Generator 2007 (DTG07) wine "drive_c". By Questor
WINE_DRIVE_C_S="/home/<SOME_USER>/.PlayOnLinux/wineprefix/cs16_txt_gen/drive_c"

# WINE_DRIVE_C_S EXAMPLES:
#   * Using system Wine
#   WINE_DRIVE_C_S=~/".wine/drive_c"
#   * Using a Wine prefix with PlayOnLinux
#   WINE_DRIVE_C_S="/home/<SOME_USER>/.PlayOnLinux/wineprefix/cs16_txt_gen/drive_c"
#   * Using a Wine prefix
#   WINE_DRIVE_C_S="/home/<SOME_USER>/cs16_txt_gen/drive_c"

# NOTE: Keep the last X logs. By Questor
LOGS_KEEP_S=5

# NOTE: It will try to keep textures as sized (1024 px) as possible for their largest
# dimension (X or Y). This will always happen if calculations that use the "MAX_UPSCL_FACT_S"
# parameter do not allow multiple maximums of the texture's original resolution to
# exactly 1024 px for its largest dimension. Very small textures that do not exceed
# 1024 px when multiplied by "MAX_UPSCL_FACT_S" do not fit into this strategy as
# overscaling will yield no benefit in virtually all cases (1 - ON/0 - OFF). By Questor
TRY_MAX_PX_S=1

# NOTE: Due to limitations of the original textures and the limitations of the CS 1.6
# engine itself, it is not possible to effectively use the resolutions reached by the
# upscaling process. So sharper images will result in better results with the "gl_texturemode GL_LINEAR_MIPMAP_LINEAR"
# ("userconfig.cfg") setting (1~3, 1 - Gives good results, -1 - OFF).
# [Ref(s).: http://cs1-6cfg.blogspot.com/p/cs-16-client-and-console-commands.html , 
# https://www.halolinux.us/ubuntu-hacks/sharpen-images-at-the-command-line.html ]
SHARPEN_IMGS_S=1

# < -----------------------------------------
