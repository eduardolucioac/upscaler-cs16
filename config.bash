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
WORK_FOLDER="/home/eduardolac/Data0/_PERSONAL/_CSREMOD/CS_WORKING_FOLDERS/_UPSCALE_IMAGES/_TEST/Counter Strike 1.6 RE-MOD v1.5.0b/Counter Strike 1.6 RE-MOD"

# NOTE: Everything below is relative to the one above and should not normally
# need changing.
WORK_FOLDER_CSTRIKE="$WORK_FOLDER/cstrike"
WORK_FOLDER_MAPS="$WORK_FOLDER_CSTRIKE/maps"
WORK_FOLDER_DETAIL="$WORK_FOLDER_CSTRIKE/gfx/detail"
WORK_FOLDER_ENV="$WORK_FOLDER_CSTRIKE/gfx/env"

# NOTE: The base game, where the WADs the mod does not carry live. It is read
# AFTER "cstrike", which is the order the engine searches in: a WAD the mod
# carries under a name the base game also uses is the one that counts.
#
# In a stock installation "halflife.wad", "decals.wad", "liquids.wad",
# "xeno.wad" and "gfx.wad" are only here. Measured on a real installation with
# those taken out of "cstrike": 83 texture names across 14 of 81 maps had
# nowhere to come from, and this folder answered 81 of them.
#
# Leave it empty to look in "cstrike" alone.
WORK_FOLDER_VALVE="$WORK_FOLDER/valve"

# NOTE: Where the finished images go, relative to "cstrike". These are the
# paths that end up written into the "*_extra.txt" files, so changing one
# means the renderer looks somewhere else.
UPSCALED_DETAIL_REL="gfx/detail/_upscaled"
UPSCALED_ENV_REL="gfx/env/_upscaled"

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Upscaling.
# --------------------------------------

# NOTE: Binary name (or full path) of the upscaler.
REALESRGAN_BIN="realesrgan-ncnn-vulkan"

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
# UPSCALE_FACTORS below says 4 and nothing else. CHANGE THE MODEL AND YOU
# MUST CHANGE THE FACTORS TO MATCH.
# [Ref(s).: https://github.com/xinntao/Real-ESRGAN-ncnn-vulkan#full-usages ]
REALESRGAN_MODEL="realesrgan-x4plus"

# NOTE: Factors the chosen model accepts, ascending and comma separated.
#   realesrgan-x4plus    -> 4
#   realesr-animevideov3 -> 2,3,4
#
# NOTE: Going to 4 and resizing back down is not a compromise. The
# downscale averages away the artefacts the network leaves, so the result is
# generally BETTER than asking for the exact factor - it is supersampling.
# What it costs is time and peak disk for the intermediate images.
UPSCALE_FACTORS="4"

# NOTE: Desired size of each image's LARGEST dimension. No image is made
# larger than this. Going above 1024 brings very little for CS 1.6 textures
# and costs a great deal of disk.
TARGET_MAX_PX=1024

# NOTE: Try to get each texture as close to "TARGET_MAX_PX" as possible by
# upscaling one step past it and resizing back down, rather than stopping one
# step short. Textures too small to reach "TARGET_MAX_PX" even at the
# largest factor are left at that factor, because inventing more pixels than
# the source has brings nothing (1 - ON/0 - OFF).
TRY_MAX_PX=1

# NOTE: Enable "tta mode" (1 - ON/0 - OFF).
# IMPORTANT: Up to 15% more quality for up to 8 times the time, on a process
# that is already very long. Only worth it on strong hardware.
RSRGAN_ENABLE_TTA=0

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Finishing.
# --------------------------------------

# NOTE: The CS 1.6 engine cannot really use the resolution upscaling reaches,
# so a sharper image gives a better result in game together with
# "gl_texturemode GL_LINEAR_MIPMAP_LINEAR" in "userconfig.cfg"
# (1~3, 1 - good results, -1 - OFF).
# [Ref(s).: http://cs1-6cfg.blogspot.com/p/cs-16-client-and-console-commands.html ]
SHARPEN_IMGS=1

# NOTE: Lossless PNG compression level for "oxipng" (0~6, -1 - OFF). Level 3
# is a good trade; higher levels take much longer for very little.
# [Ref(s).: https://github.com/shssoichiro/oxipng ]
PNG_COMPRESS_LEVEL=3

# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Behaviour.
# --------------------------------------

# NOTE: How many hex characters of each image's content hash to use as its
# file name. 16 is ample: it is what makes two identical textures - however
# many maps or WADs carry them - become a single file that is upscaled once.
# CHANGING THIS RENAMES EVERY OUTPUT FILE, so a run started under one value
# cannot be resumed under another.
HASH_LENGTH=16

# NOTE: Stop if a map needs a texture no WAD provides, or a "skyname" side
# that is not in "gfx/env". Turn it off to process what is there and have the
# rest listed in the error log (1 - ON/0 - OFF).
STOP_WAD_SKYNAME_MISSING=1

# NOTE: Textures the engine never draws (CLIP, AAATRIGGER, SKY, ORIGIN and so
# on) are skipped, since replacing them costs time and disk for nothing. Turn
# this off only to investigate something (1 - ON/0 - OFF).
SKIP_ENGINE_TEXTURES=1

# NOTE: When a texture name a map needs is carried by more than one of the
# WADs that map lists, which one wins: 0 - the FIRST one listed; 1 - the LAST
# one. Every such case is written to the output log so you can check the ones
# that actually matter.
WAD_LAST_WINS=0

# NOTE: Throw away everything already produced and make it all again, from
# the beginning (1 - ON/0 - OFF).
#
# IMPORTANT: THIS IS THE ONLY WAY TO APPLY A CHANGE TO HOW ANYTHING IS MADE.
# Every step skips what is already on disk, and nothing this script writes
# records the settings it was written under.
#
# For the IMAGES: each file is named after the content hash of its SOURCE
# texture, so changing REALESRGAN_MODEL, TARGET_MAX_PX, SHARPEN_IMGS,
# UPSCALE_FACTORS, RSRGAN_ENABLE_TTA or PNG_COMPRESS_LEVEL produces
# THE SAME FILE NAMES, and every one of them is skipped.
#
# For the "*_extra.txt": the file is skipped when it is already there, so a
# changed "black_list.txt", HASH_LENGTH, SKIP_ENGINE_TEXTURES,
# WAD_LAST_WINS or UPSCALED_*_REL does not reach it either.
#
# In both cases the new setting has no effect whatsoever - silently. Turn
# this on for one run after changing any of them.
#
# The backups are never touched. Remember to set it back to 0 afterwards, or
# the next run throws the work away again.
REDO_ALL=0

# NOTE: Keep the last X logs.
LOGS_KEEP=5

# < --------------------------------------------------------------------------

