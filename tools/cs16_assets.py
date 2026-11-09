#!/usr/bin/env python3
"""Native reader for GoldSrc (Half-Life/CS 1.6) BSP and WAD3 assets.

This replaces the Wine-dependent chain that "upscaler-cs16" used before
("ripent.exe", "HLExtract.exe" and Automatic Detail Texture Generator 2007).
It needs nothing but Python, Pillow and NumPy.

Two subcommands, both speaking JSON so that the BASH side can load the result
with "json-like":

    scan    Inspect every BSP, say which textures each map really uses, where
            the pixels for each of them live and what each one should be
            upscaled by. Nothing is written.
    export  Turn the textures named in a scan into PNG files, each one named
            after the hash of its own content so identical pixels are only
            ever written - and therefore only ever upscaled - once.

WHY THE BSP AND NOT THE WADS: a map's texture lump is the exact list of the
textures that map uses, and it carries each one's dimensions. Reading it
replaces both the "extract every WAD and hope" strategy and the brute force
search for texture names inside the BSP binary. On the project's own test
sample it cuts the images to upscale from 4075 to 533.

ERRORS: anything that stops the run is written to stderr and exits non zero,
so the BASH side can report it the same way it reports any other failure.

upscaler-cs16 - UpScaler CS 1.6 - 2024
Eduardo Lucio Amorim Costa
"""

import argparse
import fnmatch
import hashlib
import json
import os
import struct
import sys

try:
    import numpy as np
    from PIL import Image
except ImportError as exc:  # pragma: no cover - environment problem
    sys.stderr.write(
        'Missing a Python dependency (%s).\n'
        'Install Pillow and NumPy, for example:\n'
        '    sudo pacman -S --needed python-pillow python-numpy\n' % exc
    )
    sys.exit(2)


# > --------------------------------------------------------------------------
# GoldSrc binary formats.
# --------------------------------------

# NOTE: A BSP v30 header is a version int followed by 15 (offset, length)
# pairs. We only ever need two of those lumps.
BSP_VERSION_GOLDSRC = 30
BSP_LUMP_COUNT = 15
BSP_LUMP_ENTITIES = 0
BSP_LUMP_TEXTURES = 2

# NOTE: A WAD3 directory entry is 32 bytes and type 0x43 is "miptex", the only
# type that carries a texture.
WAD3_MAGIC = b'WAD3'
WAD3_ENTRY_SIZE = 32
WAD3_TYPE_MIPTEX = 0x43

# NOTE: A miptex is a 16 byte name, width, height and the offsets of its four
# mip levels, all relative to the start of the miptex itself.
MIPTEX_NAME_SIZE = 16
MIPTEX_HEADER_SIZE = 40
MIPTEX_MIP_LEVELS = 4

# NOTE: Always this many, in every miptex ever written. It is what makes it
# possible to tell a palette from whatever else a bad offset points at.
MIPTEX_PALETTE_COLOURS = 256

# NOTE: A texture whose name starts with "{" is masked: palette index 255 is
# the transparent one. Reading the index is exact, which is why this code does
# not need the "-fuzz 2% -transparent #0000ff" guess the old pipeline used -
# that guess was needed because the key colour is not always #0000ff (in the
# project's own sample "{ikcanopt" has (0, 0, 252)).
MASKED_TEXTURE_PREFIX = '{'
MASKED_PALETTE_INDEX = 255

# NOTE: Textures the engine never draws. They exist for the compiler or for
# engine behaviour, so upscaling them costs time and disk for nothing. The
# skybox is handled separately, through "skyname".
ENGINE_TEXTURES = frozenset((
    'aaatrigger', 'bevel', 'black_hidden', 'boundingbox', 'clip', 'clipbevel',
    'clipbevelbrush', 'cliphull1', 'cliphull2', 'cliphull3', 'contentempty',
    'contentwater', 'hint', 'noclip', 'null', 'origin', 'skip', 'sky',
    'solidhint', 'translucent',
))


class AssetError(Exception):
    """Anything that makes an asset unusable."""


def _read_file(path):
    """Read a whole file.

    Args:
        path (str): File to read.

    Returns:
        bytes: The file contents.

    Raises:
        AssetError: If the file cannot be read.
    """
    try:
        with open(path, 'rb') as handle:
            return handle.read()
    except OSError as exc:
        raise AssetError('cannot read "%s": %s' % (path, exc))


def _texture_name(buffer, offset):
    """Read a miptex name.

    Args:
        buffer (bytes): Buffer holding the miptex.
        offset (int): Where the miptex starts.

    Returns:
        str: The name, without its NUL padding.
    """
    raw = buffer[offset:offset + MIPTEX_NAME_SIZE]
    return raw.split(b'\0')[0].decode('latin-1')


def _read_miptex(buffer, offset):
    """Read one miptex, pixels included when it has any.

    A miptex with a zero first mip offset is a placeholder: the map names the
    texture but the pixels live in a WAD.

    Args:
        buffer (bytes): Buffer holding the miptex.
        offset (int): Where the miptex starts.

    Returns:
        dict: "name", "width", "height" and - only when the miptex carries its
    own pixels - "indices" and "palette".

    Raises:
        AssetError: If the miptex is malformed.
    """
    if offset + MIPTEX_HEADER_SIZE > len(buffer):
        raise AssetError('miptex header runs past the end of the data')
    name = _texture_name(buffer, offset)
    width, height = struct.unpack_from('<II', buffer, offset + 16)
    mips = struct.unpack_from('<%dI' % MIPTEX_MIP_LEVELS, buffer, offset + 24)
    texture = {'name': name, 'width': width, 'height': height}
    if mips[0] == 0:

        # NOTE: Declared by the map but stored in a WAD.
        return texture

    if not width or not height or width % 16 or height % 16:

        # NOTE: GoldSrc requires both dimensions to be multiples of 16 because
        # of the four mip levels. Anything else is corrupt.
        raise AssetError(
            'texture "%s" has an invalid size (%dx%d)' % (name, width, height)
        )

    indices_at = offset + mips[0]
    indices = buffer[indices_at:indices_at + width * height]
    if len(indices) != width * height:
        raise AssetError('texture "%s" has a truncated first mip' % name)

    # NOTE: The palette sits right after the smallest mip level, prefixed by
    # its own entry count, which is ALWAYS 256.
    #
    # Where that is comes from the DIMENSIONS and not from "mips[3]". The
    # four levels are laid out contiguously after the 40 byte header, so the
    # two agree in a well formed miptex - and where they disagree, it is
    # "mips[3]" that is wrong. Maps edited by texture replacing tools carry
    # offsets left over from a different layout: in one map of this
    # project's own collection, 9 of 53 textures point "mips[3]" into the
    # middle of nowhere, giving palettes of 37299 or 57519 colours that
    # Pillow then refuses with "invalid palette size". Read from the
    # dimensions, all 53 come back with the 256 they should have.
    #
    # "mips[3]" is still tried as a fallback, for the opposite case: a file
    # with padding between the levels, which the dimensions would not
    # account for. Whichever yields 256 wins.
    def _palette_at(position):
        if position + 2 > len(buffer):
            return None
        count, = struct.unpack_from('<H', buffer, position)
        if count != MIPTEX_PALETTE_COLOURS:
            return None
        colours = buffer[position + 2:position + 2 + count * 3]
        if len(colours) != count * 3:
            return None
        return colours

    palette = _palette_at(
        offset + MIPTEX_HEADER_SIZE + width * height
        + (width // 2) * (height // 2)
        + (width // 4) * (height // 4)
        + (width // 8) * (height // 8)
    )
    if palette is None:
        palette = _palette_at(offset + mips[3] + (width // 8) * (height // 8))
    if palette is None:
        raise AssetError(
            'texture "%s" has no readable palette; it is neither where its '
            'size says nor where its mip offsets say' % name
        )

    texture['indices'] = indices
    texture['palette'] = palette
    return texture


def _is_fully_masked(texture):
    """Say whether every pixel of a texture is the transparent index.

    Args:
        texture (dict): A miptex, which may have no pixels of its own.

    Returns:
        bool: True when the texture is masked and draws nothing at all.
    """
    if not texture['name'].startswith(MASKED_TEXTURE_PREFIX):
        return False
    indices = texture.get('indices')
    if not indices:
        return False
    return bool((np.frombuffer(indices, dtype=np.uint8)
                 == MASKED_PALETTE_INDEX).all())


def content_hash(texture, length):
    """Hash what a texture actually looks like.

    The name is deliberately left out: two textures with different names and
    identical pixels must collapse onto a single file, and the same texture
    carried by several WADs must not be upscaled more than once. The size goes
    in because it decides the upscale factor.

    Args:
        texture (dict): A miptex as returned by "_read_miptex".
        length (int): How many hex characters to keep.

    Returns:
        str: The truncated hex digest.
    """
    digest = hashlib.sha256()
    digest.update(struct.pack('<II', texture['width'], texture['height']))
    digest.update(texture['indices'])
    digest.update(texture['palette'])
    return digest.hexdigest()[:length]


def read_bsp(path):
    """Read a BSP's entity text and its texture lump.

    Args:
        path (str): BSP file.

    Returns:
        tuple: (entities_text, textures) where "textures" is a list of dicts
    as returned by "_read_miptex", each carrying the "offset" at which it was
    found inside the file.

    Raises:
        AssetError: If the file is not a GoldSrc BSP or is malformed.
    """
    buffer = _read_file(path)
    if len(buffer) < 4 + BSP_LUMP_COUNT * 8:
        raise AssetError('"%s" is too small to be a BSP' % path)
    version, = struct.unpack_from('<i', buffer, 0)
    if version != BSP_VERSION_GOLDSRC:
        raise AssetError(
            '"%s" is a BSP version %d; only version %d (GoldSrc) is supported'
            % (path, version, BSP_VERSION_GOLDSRC)
        )
    lumps = [struct.unpack_from('<ii', buffer, 4 + i * 8)
             for i in range(BSP_LUMP_COUNT)]

    entities_at, entities_length = lumps[BSP_LUMP_ENTITIES]
    entities = buffer[entities_at:entities_at + entities_length]
    entities = entities.split(b'\0')[0].decode('latin-1', errors='replace')

    textures_at, _ = lumps[BSP_LUMP_TEXTURES]
    textures = []
    if textures_at > 0:
        count, = struct.unpack_from('<i', buffer, textures_at)
        offsets = struct.unpack_from('<%di' % count, buffer, textures_at + 4)
        for offset in offsets:
            if offset < 0:

                # NOTE: -1 marks a slot the compiler left empty.
                continue

            texture = _read_miptex(buffer, textures_at + offset)
            texture['offset'] = textures_at + offset
            textures.append(texture)
    return entities, textures


def read_wad(path):
    """Read a WAD3's texture directory.

    Only the directory is parsed; the pixels are read later, and only for the
    few textures a map turns out to need.

    Args:
        path (str): WAD file.

    Returns:
        dict: Lower cased texture name -> offset of its miptex in the file.

    Raises:
        AssetError: If the file is not a WAD3.
    """
    buffer = _read_file(path)
    if buffer[:4] != WAD3_MAGIC:
        raise AssetError('"%s" is not a WAD3 file' % path)
    count, directory_at = struct.unpack_from('<ii', buffer, 4)
    entries = {}
    for index in range(count):
        entry_at = directory_at + index * WAD3_ENTRY_SIZE
        if entry_at + WAD3_ENTRY_SIZE > len(buffer):
            break
        offset, _, _, kind, _, _ = struct.unpack_from('<iiiBBh', buffer, entry_at)
        if kind != WAD3_TYPE_MIPTEX:
            continue
        name = _texture_name(buffer, entry_at + 16)

        # NOTE: Texture names are case insensitive everywhere in GoldSrc, in
        # the BSP, in the WAD and in the files the renderer reads.
        entries[name.lower()] = offset
    return entries


def parse_entities(text):
    """Pull the worldspawn keys we care about out of the entity lump.

    Args:
        text (str): Entity lump text.

    Returns:
        dict: "skyname" (str) and "wads" (list of bare WAD names, in the order
    the map lists them).
    """
    result = {'skyname': '', 'wads': []}
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith('"'):
            continue
        parts = line.split('"')
        if len(parts) < 4:
            continue
        key, value = parts[1].lower(), parts[3]
        if key == 'skyname' and not result['skyname']:
            result['skyname'] = value
        elif key == 'wad' and not result['wads']:
            for item in value.split(';'):

                # NOTE: These are the author's build time paths and they use
                # either slash; only the bare name is of any use.
                item = item.replace('\\', '/').strip()
                if not item:
                    continue
                name = os.path.basename(item)
                if name.lower().endswith('.wad'):
                    name = name[:-4]
                if name:
                    result['wads'].append(name)
    return result


# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Upscale planning.
# --------------------------------------

def plan_upscale(width, height, factors, target_px, try_max_px):
    """Decide how much to upscale an image by, and whether to resize after.

    The upscalers only take whole factors, and not every factor gets an image
    to exactly "target_px". When it does not, and "try_max_px" is on, we go one
    step over and resize down, which is what keeps textures as close to
    "target_px" as they can get.

    Args:
        width (int): Source width.
        height (int): Source height.
        factors (list): Factors the upscaler accepts, ascending.
        target_px (int): Desired size of the largest dimension.
        try_max_px (bool): Overshoot and resize down rather than undershoot.

    Returns:
        tuple: (factor, resize) where "resize" is an ImageMagick geometry such
    as "1024x512!" or "" when none is needed.
    """
    largest = max(width, height)
    biggest_factor = max(factors)
    needed = target_px / float(largest)

    if needed >= biggest_factor:

        # NOTE: Even the largest factor will not reach "target_px". Going past
        # it would only invent detail that is not there.
        return biggest_factor, ''

    exact = [f for f in factors if f == needed]
    if exact:
        return exact[0], ''

    over = [f for f in factors if f > needed]
    if not try_max_px:
        under = [f for f in factors if f < needed]
        return (max(under) if under else min(factors)), ''

    factor = min(over)
    scale = target_px / float(largest)
    if width >= height:
        resize = '%dx%d!' % (target_px, int(round(height * scale)))
    else:
        resize = '%dx%d!' % (int(round(width * scale)), target_px)
    return factor, resize


# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Image writing.
# --------------------------------------

def _bleed_colour_outwards(rgb, alpha, passes=4):
    """Push the colour of visible pixels into the invisible ones around them.

    Known as alpha bleeding. Each pass gives every fully transparent pixel
    the average colour of whichever of its four neighbours are already
    carrying one, so the visible colour spreads outwards a ring at a time.

    Args:
        rgb (ndarray): Height x width x 3, uint8.
        alpha (ndarray): Height x width, uint8. 0 is transparent.
        passes (int): How many rings to fill. Four is more than an upscaler
    reaches across.

    Returns:
        ndarray: The colours, with the transparent ones replaced.
    """
    out = rgb.astype(np.float32).copy()
    known = (alpha > 0)
    if not known.any() or known.all():
        return rgb

    for _ in range(passes):
        if known.all():
            break
        total = np.zeros_like(out)
        count = np.zeros(known.shape, dtype=np.float32)
        for axis, shift in ((0, 1), (0, -1), (1, 1), (1, -1)):
            shifted_rgb = np.roll(out, shift, axis=axis)
            shifted_known = np.roll(known, shift, axis=axis)

            # NOTE: "np.roll" wraps around, so the row or column that came
            # from the far side is not a neighbour and is dropped.
            edge = [slice(None)] * 2
            edge[axis] = 0 if shift > 0 else -1
            shifted_known = shifted_known.copy()
            shifted_known[tuple(edge)] = False

            total += shifted_rgb * shifted_known[..., None]
            count += shifted_known
        fillable = (~known) & (count > 0)
        if not fillable.any():
            break
        out[fillable] = total[fillable] / count[fillable][..., None]
        known = known | fillable

    return out.round().astype(np.uint8)


def miptex_to_png(texture, path):
    """Write a miptex out as a PNG.

    A masked texture ("{" prefix) becomes RGBA with palette index 255 fully
    transparent; every other texture becomes RGB.

    Args:
        texture (dict): A miptex carrying "indices" and "palette".
        path (str): File to write.
    """
    width, height = texture['width'], texture['height']
    image = Image.frombytes('P', (width, height), texture['indices'])
    image.putpalette(texture['palette'])

    if texture['name'].startswith(MASKED_TEXTURE_PREFIX):
        indices = np.frombuffer(texture['indices'], dtype=np.uint8)
        indices = indices.reshape(height, width)
        alpha = np.where(indices == MASKED_PALETTE_INDEX, 0, 255).astype(np.uint8)
        rgb = np.array(image.convert('RGB'))

        # NOTE: The colour UNDER the transparent pixels is pushed outwards
        # from the visible ones before anything is upscaled.
        #
        # Those pixels hold the key colour, which in every masked texture of
        # this project's own collection is pure blue (0, 0, 255). Alpha hides
        # it, but an upscaler does not work on alpha alone: it interpolates
        # the COLOUR channels across the edge, so a pixel that ends up half
        # visible is mixed half with that blue. The result is the blue fringe
        # around ladders, grates and foliage - and the same in red or green
        # wherever the key colour happens to be something else.
        #
        # Replacing the hidden colour with the nearest visible one leaves the
        # interpolation nothing wrong to mix in. It changes no pixel anyone
        # can see: alpha is untouched, and every pixel written here was
        # already invisible. By Questor
        rgb = _bleed_colour_outwards(rgb, alpha)
        image = Image.fromarray(np.dstack([rgb, alpha]), 'RGBA')
    else:
        image = image.convert('RGB')

    image.save(path, 'PNG', optimize=False)


def tga_to_png(source, target):
    """Convert a skybox TGA to PNG.

    Args:
        source (str): TGA file.
        target (str): PNG file to write.

    Raises:
        AssetError: If the TGA cannot be read.
    """
    try:
        with Image.open(source) as image:
            image.convert('RGB').save(target, 'PNG', optimize=False)
    except (OSError, ValueError) as exc:
        raise AssetError('cannot convert "%s": %s' % (source, exc))


# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Subcommand: scan.
# --------------------------------------

SKY_SIDES = ('rt', 'bk', 'lf', 'ft', 'up', 'dn')


def read_black_list(path):
    """Read the list of textures that must never be replaced.

    Two forms are accepted, one per line, "#" starting a comment:

        rex_wall02              block the name wherever it comes from
        de_rex/rex_wall02       block it only when it comes from "de_rex"

    where the part before the slash is the BSP or WAD the texture was read
    from, without its extension. Both halves are matched case insensitively.

    Args:
        path (str): File to read, or "" for no blacklist.

    Returns:
        tuple: (bare_names, qualified_pairs) as two sets.

    Raises:
        AssetError: If the file is given but cannot be read.
    """
    bare, qualified = set(), set()
    if not path:
        return bare, qualified
    try:
        with open(path) as handle:
            lines = handle.readlines()
    except OSError as exc:
        raise AssetError('cannot read the blacklist "%s": %s' % (path, exc))
    for line in lines:
        line = line.split('#', 1)[0].strip().lower()
        if not line:
            continue
        if '/' in line:
            source, _, name = line.rpartition('/')
            qualified.add((source, name))
        else:
            bare.add(line)
    return bare, qualified


def _find_file(folder, name):
    """Find a file in a folder, ignoring case.

    Windows paths are case insensitive and Linux ones are not, so the names a
    BSP carries rarely match what is on disk exactly.

    Args:
        folder (str): Folder to look in.
        name (str): File name to match.

    Returns:
        str: Full path, or "" when there is no match.
    """
    wanted = name.lower()
    try:
        for entry in os.listdir(folder):
            if entry.lower() == wanted:
                return os.path.join(folder, entry)
    except OSError:
        pass
    return ''


def _list_by_extension(folder, extension):
    """List a folder's files with the given extension, ignoring case.

    Args:
        folder (str): Folder to list.
        extension (str): Extension to match, dot included.

    Returns:
        list: Full paths, sorted.
    """
    try:
        entries = os.listdir(folder)
    except OSError:
        return []
    wanted = extension.lower()
    return sorted(os.path.join(folder, e) for e in entries
                  if e.lower().endswith(wanted))


def _output_pixels(images):
    """Total pixels the finished images will occupy.

    Used to estimate disk consumption before anything is written. The resize
    geometry, when there is one, is what the image ends up at; otherwise it is
    the source size times the factor.

    Args:
        images (dict): Hash -> image record.

    Returns:
        int: Sum of width * height over every finished image.
    """
    total = 0
    for image in images.values():
        if image['resize']:
            width, height = image['resize'].rstrip('!').split('x')
            total += int(width) * int(height)
        else:
            factor = image['factor']
            total += image['width'] * factor * image['height'] * factor
    return total


def command_scan(args):
    """Inspect every BSP and say what has to be produced for it.

    Writes a JSON object to stdout with three keys: "maps" (what each map
    needs), "images" (every distinct texture, by content hash) and "sky"
    (every distinct skybox side, by content hash).

    WADs are read from the mod folder first and from every "--valve" folder
    after it, which is the order the engine searches in: a WAD the mod carries
    under a name the base game also uses is the one that counts.

    Args:
        args (Namespace): Parsed command line.

    Returns:
        int: Process exit code.
    """
    factors = sorted(int(f) for f in args.factors.split(','))
    skip_engine = not args.keep_engine_textures
    black_bare, black_qualified = read_black_list(args.black_list)

    # NOTE: Read every WAD directory once. Only the directories, which is a
    # few hundred kilobytes even for a full "cstrike" folder.
    #
    # The mod folder FIRST and the base game ("valve") after it, which is the
    # order the engine itself searches in - and a WAD the mod carries under a
    # name the base game also uses WINS, exactly as it does in the game. In a
    # stock installation "halflife.wad", "decals.wad", "liquids.wad",
    # "xeno.wad" and "gfx.wad" live only in "valve": measured on a real
    # installation with those taken out of "cstrike", 83 texture names across
    # 14 of 81 maps had nowhere to come from, and "valve" answered 81 of them.
    #
    # And the ones a mod DOES carry are not the same files: in that same
    # installation "cstrike/halflife.wad" is 43.8 MB against 37.9 MB in
    # "valve", and "cstrike/xeno.wad" 29 KB against 6.5 MB. Reading them in
    # the wrong order would hand the map a texture the engine would never use.
    wad_directory = {}
    wad_order = []
    for folder in [args.cstrike] + list(args.valve):
        for path in _list_by_extension(folder, '.wad'):
            name = os.path.splitext(os.path.basename(path))[0].lower()
            if name in wad_directory:
                continue
            try:
                wad_directory[name] = (path, read_wad(path))
                wad_order.append(name)
            except AssetError as exc:
                sys.stderr.write('WARNING: %s\n' % exc)

    wad_buffers = {}

    def wad_texture(wad_name, texture_name):
        """Read one texture out of an already indexed WAD."""
        path, entries = wad_directory[wad_name]
        offset = entries[texture_name.lower()]
        if path not in wad_buffers:
            wad_buffers[path] = _read_file(path)
        texture = _read_miptex(wad_buffers[path], offset)
        texture['offset'] = offset
        return texture

    maps = {}
    images = {}
    sky_images = {}
    ambiguous = []

    # NOTE: "--only" exists so a change can be judged on ONE map before it is
    # let loose on a whole collection. Upscaling 81 maps is hours; upscaling
    # "fy_factory" to see whether a fix worked is a couple of minutes.
    wanted = [p.strip().lower() for p in (args.only or '').split(',') if p.strip()]

    for bsp_path in _list_by_extension(args.maps, '.bsp'):
        bsp_name = os.path.splitext(os.path.basename(bsp_path))[0]
        if wanted and not any(fnmatch.fnmatch(bsp_name.lower(), p) for p in wanted):
            continue
        try:
            entity_text, textures = read_bsp(bsp_path)
        except AssetError as exc:
            sys.stderr.write('ERROR: %s\n' % exc)
            return 1
        worldspawn = parse_entities(entity_text)

        entry = {
            'bsp': bsp_path,
            'skyname': worldspawn['skyname'],
            'wads': worldspawn['wads'],
            'texture_list': [],
            'skipped': [],
            'blacklisted': [],
            'unresolved': [],
            'sky': [],
            'sky_missing': [],
            'fully_masked': [],
        }

        # > ----- textures -----
        for texture in textures:
            name = texture['name']
            if skip_engine and name.lower() in ENGINE_TEXTURES:
                entry['skipped'].append(name)
                continue
            if name.lower() in black_bare:
                entry['blacklisted'].append(name)
                continue

            if 'indices' not in texture:

                # NOTE: Named by the map but stored in a WAD. Search the WADs
                # the map lists, in its own order, then - only if that fails -
                # every other WAD present.
                found = []
                for wad_name in worldspawn['wads']:
                    key = wad_name.lower()
                    if key in wad_directory and name.lower() in wad_directory[key][1]:
                        found.append(key)
                if not found:
                    for key in wad_order:
                        if name.lower() in wad_directory[key][1]:
                            found.append(key)
                if not found:
                    entry['unresolved'].append(name)
                    continue
                if len(found) > 1:
                    ambiguous.append({
                        'map': bsp_name, 'texture': name, 'wads': found,
                        'used': found[-1 if args.wad_last_wins else 0],
                    })
                chosen = found[-1 if args.wad_last_wins else 0]
                try:
                    resolved = wad_texture(chosen, name)
                except (AssetError, KeyError) as exc:
                    sys.stderr.write(
                        'WARNING: "%s" needed by "%s": %s\n'
                        % (name, bsp_name, exc)
                    )
                    entry['unresolved'].append(name)
                    continue
                source_kind, source_path = 'wad', wad_directory[chosen][0]
                source_name = chosen
                texture = resolved
            else:
                source_kind, source_path = 'bsp', bsp_path
                source_name = bsp_name.lower()

            if (source_name, name.lower()) in black_qualified:
                entry['blacklisted'].append('%s/%s' % (source_name, name))
                continue

            # NOTE: A texture that is ENTIRELY the mask index draws nothing.
            # These are the "invisible but solid" brushes - "{blue",
            # "{invisible", "{null", "{nosee" and the rest - used for
            # ladders, clip volumes and light sources.
            #
            # Replacing them is worse than pointless. There is nothing in
            # them to upscale, and what comes out the other end is a black
            # PNG: ImageMagick works on PREMULTIPLIED alpha, so resizing an
            # image whose alpha is zero everywhere takes its colour to zero
            # too, and the renderer then draws a black surface where the map
            # author wanted to see straight through. That is the black crate
            # in "de_quarry".
            #
            # Recognised rather than left to the black list. The names vary
            # from map to map, a black list entry is tied to one source, and
            # a texture embedded in a BSP is a different source from the
            # same name in a WAD - which is exactly how "halflife/{blue"
            # being on the list still let "de_quarry" come out black.
            if _is_fully_masked(texture):
                entry['fully_masked'].append(name)
                continue

            digest = content_hash(texture, args.hash_length)
            entry['texture_list'].append({'base': name, 'hash': digest})
            if digest not in images:
                factor, resize = plan_upscale(
                    texture['width'], texture['height'],
                    factors, args.target_px, args.try_max_px,
                )
                images[digest] = {
                    'name': name,
                    'width': texture['width'],
                    'height': texture['height'],
                    'kind': source_kind,
                    'source': source_path,
                    'offset': texture['offset'],
                    'masked': name.startswith(MASKED_TEXTURE_PREFIX),
                    'factor': factor,
                    'resize': resize,
                }
        # < ----- textures -----

        # > ----- skybox -----
        if worldspawn['skyname'] and args.env:
            for side in SKY_SIDES:
                path = _find_file(args.env, '%s%s.tga' % (worldspawn['skyname'], side))
                if not path:
                    entry['sky_missing'].append(side)
                    continue
                digest = hashlib.sha256(_read_file(path)).hexdigest()[:args.hash_length]
                entry['sky'].append({'side': side, 'hash': digest})
                if digest not in sky_images:
                    try:
                        with Image.open(path) as image:
                            width, height = image.size
                    except (OSError, ValueError) as exc:
                        sys.stderr.write('WARNING: cannot read "%s": %s\n' % (path, exc))
                        entry['sky_missing'].append(side)
                        entry['sky'].pop()
                        continue
                    factor, resize = plan_upscale(
                        width, height, factors, args.target_px, args.try_max_px,
                    )
                    sky_images[digest] = {
                        'source': path,
                        'width': width,
                        'height': height,
                        'factor': factor,
                        'resize': resize,
                    }
        # < ----- skybox -----

        maps[bsp_name] = entry

    report = {
        'map_order': sorted(maps),
        'image_order': sorted(images),
        'sky_order': sorted(sky_images),
        'maps': maps,
        'images': images,
        'sky': sky_images,
        'ambiguous': ambiguous,
        'totals': {
            'maps': len(maps),
            'output_pixels': _output_pixels(images) + _output_pixels(sky_images),
            'texture_refs': sum(len(m['texture_list']) for m in maps.values()),
            'images': len(images),
            'sky': len(sky_images),
            'blacklisted': sum(len(m['blacklisted']) for m in maps.values()),
            'fully_masked': sum(len(m['fully_masked']) for m in maps.values()),
            'unresolved': sum(len(m['unresolved']) for m in maps.values()),
            'sky_missing': sum(len(m['sky_missing']) for m in maps.values()),
        },
    }
    json.dump(report, sys.stdout, indent=args.indent, sort_keys=True)
    sys.stdout.write('\n')
    return 0


# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Subcommand: export.
# --------------------------------------

def command_export(args):
    """Write every distinct image named by a scan out as a PNG.

    The files are written into one subfolder per upscale factor, because the
    ncnn upscalers take a whole folder at a time and loading their model is
    far more expensive than any single image. One batch per factor means the
    model is loaded a handful of times instead of once per image.

    Anything already finished - present in one of the "--done" folders - is
    not written at all, which is what makes an interrupted run resumable by
    simply being run again.

    Args:
        args (Namespace): Parsed command line.

    Returns:
        int: Process exit code.
    """
    try:
        with open(args.plan) as handle:
            report = json.load(handle)
    except (OSError, ValueError) as exc:
        sys.stderr.write('ERROR: cannot read the scan "%s": %s\n' % (args.plan, exc))
        return 1

    def is_done(digest):
        """True when this image has already been finished somewhere."""
        name = '%s.png' % digest
        return any(os.path.exists(os.path.join(d, name)) for d in args.done)

    buffers = {}
    written = done = 0
    factors = set()

    def bucket_for(factor):
        """Make and return the folder that holds a given factor's inputs."""
        path = os.path.join(args.out, str(factor))
        if factor not in factors:
            os.makedirs(path, exist_ok=True)
            factors.add(factor)
        return path

    for digest, image in sorted(report.get('images', {}).items()):
        if is_done(digest):
            done += 1
            continue
        target = os.path.join(bucket_for(image['factor']), '%s.png' % digest)
        if os.path.exists(target):
            continue
        source = image['source']
        if source not in buffers:
            try:
                buffers[source] = _read_file(source)
            except AssetError as exc:
                sys.stderr.write('ERROR: %s\n' % exc)
                return 1
        try:
            texture = _read_miptex(buffers[source], image['offset'])
            miptex_to_png(texture, target)
        except (AssetError, OSError, ValueError) as exc:
            sys.stderr.write(
                'ERROR: cannot export "%s" from "%s": %s\n'
                % (image['name'], source, exc)
            )
            return 1
        written += 1

    for digest, image in sorted(report.get('sky', {}).items()):
        if is_done(digest):
            done += 1
            continue
        target = os.path.join(bucket_for(image['factor']), '%s.png' % digest)
        if os.path.exists(target):
            continue
        try:
            tga_to_png(image['source'], target)
        except AssetError as exc:
            sys.stderr.write('ERROR: %s\n' % exc)
            return 1
        written += 1

    # NOTE: The "already finished" half is only said when there IS one. On a
    # first run it is always zero, and a zero that can never be anything else
    # is noise in the one line the user reads.
    if done:
        sys.stdout.write('%d written, %d already finished\n' % (written, done))
    else:
        sys.stdout.write('%d written\n' % written)
    return 0


# < --------------------------------------------------------------------------

# > --------------------------------------------------------------------------
# Command line.
# --------------------------------------

def build_parser():
    """Build the command line parser.

    Returns:
        ArgumentParser: The parser.
    """
    parser = argparse.ArgumentParser(
        prog='cs16_assets.py', description=__doc__.splitlines()[0],
    )
    commands = parser.add_subparsers(dest='command', required=True)

    scan = commands.add_parser('scan', help='inspect BSPs and plan the work')
    scan.add_argument('--maps', required=True, help='the "maps" folder')
    scan.add_argument('--cstrike', required=True, help='the "cstrike" folder')
    scan.add_argument('--valve', action='append', default=[],
                      metavar='FOLDER',
                      help='another folder of WADs, searched after "cstrike" '
                           '(the "valve" folder of the base game); may be '
                           'given more than once')
    scan.add_argument('--env', default='', help='the "gfx/env" folder')
    scan.add_argument('--target-px', type=int, default=1024,
                      help='desired size of the largest dimension')
    scan.add_argument('--factors', default='4',
                      help='comma separated factors the upscaler accepts')
    scan.add_argument('--try-max-px', action='store_true',
                      help='overshoot and resize down rather than undershoot')
    scan.add_argument('--hash-length', type=int, default=16,
                      help='how many hex characters of the hash to use')
    scan.add_argument('--black-list', default='',
                      help='file listing textures that must not be replaced')
    scan.add_argument('--keep-engine-textures', action='store_true',
                      help='do not skip textures the engine never draws')
    scan.add_argument('--wad-last-wins', action='store_true',
                      help='on a name carried by several WADs take the last, '
                           'not the first, of the ones the map lists')
    scan.add_argument('--only', default='',
                      help='comma separated map names, globs allowed, to scan '
                           'instead of every map in the folder')
    scan.add_argument('--indent', type=int, default=0,
                      help='JSON indentation, 0 for none')
    scan.set_defaults(handler=command_scan)

    export = commands.add_parser('export', help='write the planned PNGs')
    export.add_argument('--plan', required=True, help='a scan, as a JSON file')
    export.add_argument('--out', required=True,
                        help='folder to write into, one subfolder per factor')
    export.add_argument('--done', action='append', default=[],
                        help='folder whose "<hash>.png" files are already '
                             'finished; may be given more than once')
    export.set_defaults(handler=command_export)

    return parser


def main(argv=None):
    """Entry point.

    Args:
        argv (Optional[list]): Arguments, defaulting to the real ones.

    Returns:
        int: Process exit code.
    """
    args = build_parser().parse_args(argv)
    if getattr(args, 'indent', 0) == 0:
        args.indent = None
    try:
        return args.handler(args)
    except AssetError as exc:
        sys.stderr.write('ERROR: %s\n' % exc)
        return 1
    except BrokenPipeError:  # pragma: no cover
        return 0


if __name__ == '__main__':
    sys.exit(main())

# < --------------------------------------------------------------------------
