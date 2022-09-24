#!/bin/bash

# > -----------------------------------------
# CONFIGURATION:

# IMPORTANT: Windows folder paths are case INsensitive, Linux is NOT! By Questor

# NOTE: Folder containing the main CS 1.6 executable ("hl.exe", for example). By Questor
# WORK_FOLDER_S="/home/eduardolac/Data1/Games/CS_WORKING_FOLDERS/_UPSCALE_IMAGES/Counter Strike 1.6 RE-MOD v1.5.0b/Counter Strike 1.6 RE-MOD"
WORK_FOLDER_S="/home/eduardolac/Data1/Games/Counter Strike 1.6 RE-MOD v1.5.0b/Counter Strike 1.6 RE-MOD"

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

# NOTE: Enable "tta mode". By Questor
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
# RIPENT_CMD_S='WINEDEBUG=-all WINEPREFIX="/home/eduardolac/vluzacns_zhlt_v34" wine "$SCRIPT_DIR_S/Vluzacn'"'"'s ZHLT v34/tools/ripent.exe" -export "$(winepath -w "${BSP_FILES[$i]}" 2> /dev/null)"'

# NOTE: Automatic Detail Texture Generator 2007 command (DTG07) command. Do not use double quotes around the value of this parameter.
DTG07_CMD_S='export WINEDEBUG=-all && export POL_IgnoreWineErrors=True && /usr/share/playonlinux4/playonlinux --run "DetailTextureGen"'

# DTG07_CMD_S EXAMPLES:
#   * Using system Wine
# DTG07_CMD_S='WINEDEBUG=-all wine "$SCRIPT_DIR_S/Automatic Detail Texture Generator 2007/DetailTextureGen.exe"'
#   * Using Wine with PlayOnLinux (Recommended)
# DTG07_CMD_S='export WINEDEBUG=-all && export POL_IgnoreWineErrors=True && /usr/share/playonlinux4/playonlinux --run "DetailTextureGen"'
#   * Using a Wine prefix
# DTG07_CMD_S='WINEDEBUG=-all WINEPREFIX="/home/eduardolac/cs16_txt_gen" wine "$SCRIPT_DIR_S/Automatic Detail Texture Generator 2007/DetailTextureGen.exe"'

# NOTE: Wine "drive_c". By Questor
WINE_DRIVE_C_S="/home/eduardolac/.PlayOnLinux/wineprefix/cs16_txt_gen/drive_c"

# WINE_DRIVE_C_S EXAMPLES:
#   * Using system Wine
#   WINE_DRIVE_C_S=~/".wine/drive_c"
#   * Using a Wine prefix with PlayOnLinux
#   WINE_DRIVE_C_S="/home/eduardolac/.PlayOnLinux/wineprefix/cs16_txt_gen/drive_c"
#   * Using a Wine prefix
#   WINE_DRIVE_C_S="/home/eduardolac/cs16_txt_gen/drive_c"

# NOTE: Keep the last X logs. By Questor
LOGS_KEEP_S=5


# TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: 
# TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: 
# TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: 
# Backup files "bug"(?)!
# TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: 
# TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: 
# TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: 


# TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: 
# O "sonho" aconteceu! Finalmente uma solução simples, completa e automatizada para aumentar a resolução (texture upscaler) dos antigos mapas do CS 1.6! Wow!
# Tenha em mente que o USCS16 - UpScaler CS 1.6 não fará milagre, pois é uma solução geral para centenas de problemas específicos.
# Alguns mapas vão melhorar drasticamente, outros nem tanto; alguns apresentaram "bugs" nas texturas. Mas, DE MANEIRA GERAL O USCS16 - UPSCALER CS 1.6 APRESENTARÁ RESULTADOS EXCELENTES!
# NOTE: A quase todos os "bugs" nas texturas podem ser resolvidos com alguns ajustes manuais.
# TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: TODO: 

# TODO: Todos os maps devem estar perfeitamente funcionais!
# TODO: Garanta que a os seus recursos de hardware estejam o mais desocupados possivel. Em alguns casos, reiniciar seu SO ajudará significamente a melhorar a performance do script.
# TODO: You will need a metahook for the scheme to work. Metahook Plus 0.4, Renderer 1.5c and Bash >= 4.3...
# TODO: Recalcular o uso de disco.
# TODO: "skynames" will be on the "WORK_FOLDER_ENV_S" folder and "textures" on the "WORK_FOLDER_DETAIL_S".

# < -----------------------------------------
