#!/bin/bash

# upscaler-cs16 - UpScaler CS 1.6 - configuration.
#
# IMPORTANT: Windows folder paths are case INsensitive, Linux ones are NOT.
# The script itself matches the names it reads out of the BSPs case
# insensitively, but the paths below are yours and must be exact.

# > --------------------------------------------------------------------------
# Folders.
# --------------------------------------

# NOTE: Folder containing the main CS 1.6 executable ("hl.exe", for example).
# By Questor
WORK_FOLDER_S="/home/eduardolac/Data0/_PERSONAL/_CSREMOD/CS_WORKING_FOLDERS/_UPSCALE_IMAGES/_TEST/Counter Strike 1.6 RE-MOD v1.5.0b/Counter Strike 1.6 RE-MOD"

# NOTE: Everything below is relative to the one above and should not normally
# need changing. By Questor
WORK_FOLDER_CSTRIKE_S="$WORK_FOLDER_S/cstrike"
WORK_FOLDER_MAPS_S="$WORK_FOLDER_CSTRIKE_S/maps"
WORK_FOLDER_DETAIL_S="$WORK_FOLDER_CSTRIKE_S/gfx/detail"
WORK_FOLDER_ENV_S="$WORK_FOLDER_CSTRIKE_S/gfx/env"

# NOTE: Where the finished images go, relative to "cstrike". These are the
# paths that end up written into the "*_extra.txt" files, so changing one
# means the renderer looks somewhere else. By Questor
UPSCALED_DETAIL_REL_S="gfx/detail/_upscaled"
UPSCALED_ENV_REL_S="gfx/env/_upscaled"

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Upscaling.
# --------------------------------------

# NOTE: Binary name (or full path) of the upscaler. By Questor
REALESRGAN_BIN_S="realesrgan-ncnn-vulkan"

# NOTE: The model to use.
#
# "realesrgan-x4plus" is the general purpose one: a large network trained on
# real world photographs, which is what CS 1.6 textures mostly are - brick,
# concrete, metal, wood, fabric. It is the one that gives the most detail.
#
# "realesr-animevideov3" is a small network trained for ANIME VIDEO. It is
# much faster and it takes 2, 3 and 4 as factors rather than only 4, but on
# photographic material it flattens detail. Worth it only on hardware that
# cannot afford the other.
#
# IMPORTANT: "realesrgan-x4plus" is a FIXED 4x MODEL. Asking it for "-s 2"
# fails with "find_blob_index_by_name data failed", which is why
# UPSCALE_FACTORS_S below says 4 and nothing else. CHANGE THE MODEL AND YOU
# MUST CHANGE THE FACTORS TO MATCH.
# By Questor
# [Ref(s).: https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan#full-usages ]
REALESRGAN_MODEL_S="realesrgan-x4plus"

# NOTE: Factors the chosen model accepts, ascending and comma separated.
#   realesrgan-x4plus    -> 4
#   realesr-animevideov3 -> 2,3,4
#
# NOTE: Going to 4 and resizing back down is not a compromise. The
# downscale averages away the artefacts the network leaves, so the result is
# generally BETTER than asking for the exact factor - it is supersampling.
# What it costs is time and peak disk for the intermediate images.
# By Questor
UPSCALE_FACTORS_S="4"

# NOTE: Desired size of each image's LARGEST dimension. No image is made
# larger than this. Going above 1024 brings very little for CS 1.6 textures
# and costs a great deal of disk. By Questor
TARGET_MAX_PX_S=1024

# NOTE: Try to get each texture as close to "TARGET_MAX_PX_S" as possible by
# upscaling one step past it and resizing back down, rather than stopping one
# step short. Textures too small to reach "TARGET_MAX_PX_S" even at the
# largest factor are left at that factor, because inventing more pixels than
# the source has brings nothing (1 - ON/0 - OFF). By Questor
TRY_MAX_PX_S=1

# NOTE: Enable "tta mode" (1 - ON/0 - OFF).
# IMPORTANT: Up to 15% more quality for up to 8 times the time, on a process
# that is already very long. Only worth it on strong hardware. By Questor
RSRGAN_ENABLE_TTA_S=0

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Finishing.
# --------------------------------------

# NOTE: The CS 1.6 engine cannot really use the resolution upscaling reaches,
# so a sharper image gives a better result in game together with
# "gl_texturemode GL_LINEAR_MIPMAP_LINEAR" in "userconfig.cfg"
# (1~3, 1 - good results, -1 - OFF). By Questor
# [Ref(s).: http://cs1-6cfg.blogspot.com/p/cs-16-client-and-console-commands.html ]
SHARPEN_IMGS_S=1

# NOTE: Lossless PNG compression level for "oxipng" (0~6, -1 - OFF). Level 3
# is a good trade; higher levels take much longer for very little. By Questor
# [Ref(s).: https://github.com/shssoichiro/oxipng ]
PNG_COMPRESS_LEVEL_S=3

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Behaviour.
# --------------------------------------

# NOTE: How many hex characters of each image's content hash to use as its
# file name. 16 is ample: it is what makes two identical textures - however
# many maps or WADs carry them - become a single file that is upscaled once.
# CHANGING THIS RENAMES EVERY OUTPUT FILE, so a run started under one value
# cannot be resumed under another. By Questor
HASH_LENGTH_S=16

# NOTE: Stop if a map needs a texture no WAD provides, or a "skyname" side
# that is not in "gfx/env". Turn it off to process what is there and have the
# rest listed in the error log (1 - ON/0 - OFF). By Questor
STOP_WAD_SKYNAME_MISSING_S=1

# NOTE: Textures the engine never draws (CLIP, AAATRIGGER, SKY, ORIGIN and so
# on) are skipped, since replacing them costs time and disk for nothing. Turn
# this off only to investigate something (1 - ON/0 - OFF). By Questor
SKIP_ENGINE_TEXTURES_S=1

# NOTE: When a texture name a map needs is carried by more than one of the
# WADs that map lists, which one wins: 0 - the FIRST one listed; 1 - the LAST
# one. Every such case is written to the output log so you can check the ones
# that actually matter. By Questor
WAD_LAST_WINS_S=0

# NOTE: Throw away everything already produced and make it all again, from
# the beginning (1 - ON/0 - OFF).
#
# IMPORTANT: THIS IS THE ONLY WAY TO APPLY A CHANGE TO HOW THE IMAGES ARE
# MADE. Each file is named after the content hash of its SOURCE texture, not
# after the settings used to process it, so changing REALESRGAN_MODEL_S,
# TARGET_MAX_PX_S, SHARPEN_IMGS_S, UPSCALE_FACTORS_S, RSRGAN_ENABLE_TTA_S or
# PNG_COMPRESS_LEVEL_S produces THE SAME FILE NAMES. Every step then finds
# its output already on disk and skips it, and the new setting has no effect
# whatsoever - silently. Turn this on for one run after changing any of them.
#
# The backups are never touched. Remember to set it back to 0 afterwards, or
# the next run throws the work away again.
# By Questor
REDO_ALL_S=0

# NOTE: Keep the last X logs. By Questor
LOGS_KEEP_S=5

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# NOTES AND REMAINING WORK.
# --------------------------------------

# HOW THE TEXTURES ARE FOUND (this replaced a lot of guesswork):
# A map's BSP carries a texture lump that IS the exact list of the textures
# that map uses, each with its dimensions. A texture is either EMBEDDED there
# (the compiler copied the pixels in) or EXTERNAL (the lump names it and the
# pixels stay in a WAD). So:
#   - there is no need to extract whole WADs and hope;
#   - there is no need to brute force search the BSP binary for names;
#   - there is no need to decide which WADs a map "really" uses: only the
#     handful of names a map leaves external are ever looked up, and only
#     those are read.
# On the project's own test sample 4 of the 5 maps have every texture
# embedded, and the WAD paths their "wad" key lists are the author's build
# time paths that do not exist anywhere.

# WHY THE FILE NAMES ARE HASHES:
# The name a texture has is not unique - two WADs can both carry a "bild1"
# and they can be different images - and the same image turns up in many maps
# under the same or a different name. Naming each output file after the hash
# of its own content makes identical pixels one file, upscaled once, and makes
# the whole run idempotent: anything already on disk is already done. The
# "*_extra.txt" files are what map each map's texture NAME onto the right
# hash, which is exactly what that format is for.

# TODO: Confirm WAD_LAST_WINS_S against the engine. The observation that the
# LAST entry wins came from the "*_extra.txt" files, not from the engine's WAD
# search, and the two need not agree. Every ambiguous name is logged; the
# default here (first wins) matches the usual GoldSrc behaviour.

# TODO: Suggest to the user which WADs are actually needed. With the scan
# above we now know exactly which WADs get read, so the ones never touched can
# be reported as removable. NOTE THAT THE SCRIPT NO LONGER DELETES ANY WAD -
# the old "remove unused WADs" step did, and it was both destructive and
# unnecessary once the BSP drives the work.

# TODO: Also look for WADs in the "valve" folder, not only "cstrike":
#   .../Counter Strike 1.6 RE-MOD/valve/

# TODO: Metahook Plus 0.4 + Renderer 1.5c are needed for the detail textures
# to be used at all, and BASH >= 4.3 for the script itself.

# < --------------------------------------------------------------------------
