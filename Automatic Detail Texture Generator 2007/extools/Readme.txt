================================
================================
 HLLib BY: RYAN "NEMESIS" GREGG
================================
================================

===========================
Library/Author Information:
===========================

---- General Library Information ----
Date                     : January 9th 2007
Author                   : Ryan Gregg
                           Michael Mohr (Linux Port)
Title                    : HLLib
Build                    : 2.0.6
Email address            : ryansgregg@hotmail.com (Ryan Gregg)
                           m.mohr@laposte.net (Michael Mohr)
Home page /  Website     : http://nemesis.thewavelength.net/

---- Library Construction Information ----
Written In               : C, C++

======
Other:
======

The library contains four folders:

  Bin
  - Contains library and example program binaries.

  HLExtract
  - Contains example program source code.

  HLLib
  - Contains library source code.

  Lib
  - Contains library C/C++ Header and Inline Files.

The project files are for Visual Studio .NET 2003; no .NET extensions are used.

================
HLExtract Usage:
================

Correct HLExtract usage:
 -p <filepath>       (Package to load.)
 -d <path>           (Destination extraction directory.)
 -e <itempath>       (Item in package to extract.)
 -t <itempath>       (Item in package to validate.)
 -l[d][f] [filepath] (List the contents of the package.)
 -f                  (Defragment package.)
 -c                  (Console mode.)
 -s                  (Silent mode.)
 -m                  (Use file mapping.)
 -q                  (Use quick file mapping.)
 -v                  (Allow volatile access.)
 -o                  (Don't overwrite files.)
 -r                  (Force defragmenting on all files.)
 -n <path>           (NCF file's root path.)

Example HLExtract usage:
HLExtract.exe -p "C:\half-life.gcf" -d "C:\backup" -e "root\valve\models" -e "root\valve\config.cfg"
HLExtract.exe -p "C:\half-life.gcf" -c -m -q -v
HLExtract.exe -p "C:\half-life.gcf" -lf "C:\half-life.txt" -m -s
HLExtract.exe -p "C:\half-life.gcf" -m -f

Console Commands (Interactive console mode):

  dir [filter]		Directory listing.
  cd <folder>		Change directory to <folder>.
  info <item>		Information on <item>.
  extract <item>	Extract <item> to <path> specified by -d.
  validate <item>	Validate <item> data.
  find <filter>		Search the current folder for <item> recursively.
  type <file>		Type <file> to the console.
  open <file>		Open nested package <file>.
  root			Change directory to root\.
  status		Package information.
  cls			Clear screen.
  help			Display help.
  exit			Exit HLExtract.

============
Linux Setup:
============

#
# Run the following commands from this directory:
#

# Build and install HLLib.
make -C HLLib -f Makefile install

# Update dynamic linker run time bindings.
ldconfig

# Build HLExtract.
gcc -O2 -g HLExtract/Main.c -o HLExtract/hlextract -lhl

# Install HLExtract.
cp HLExtract/hlextract /usr/local/bin

==================
Library Changelog:
==================

  v2.0.6
  - Added generic write support to mapping interface.
  - Added no recurse option to FindFirst()/FindNext().
  - Improved package item attribute consistency.
  - Fixed GCC visibility support.
  - Fixed unnecessary GCF bounds check.
  - Fixed BSP unused lump check.

  v2.0.5
  - Added Linux support.
  - Fixed near infinite find next recursion.

  v2.0.4
  - Fixed bug in GCF file defragmentation progress.

  v2.0.3
  - Added NCF file support.

  v2.0.2
  - Added GCF file defragmentation.
  - Added fragmentation property to GCF files.
  - Added Dark Messiah VBSP support.
  - Fixed hlPackageCreateStream() bug.
  - Fixed CMapping::GetTotalMemoryUsed() calculation.
  - Fixed PAK file path parsing.
  - Improved error messages.
  - Improved file mapping performance.

  v2.0.1
  - Added memory tracking.
  - Improved view management.
  - Fixed memory mapping bug.
  - Fixed user data bug in proc reader.
  - Fixed WAD file GetImageData() bug.
  - Fixed default mapping stream view size.
  - Fixed a minor memory leak.

  v2.0.0
  - Rewrote entire library.
  - Open packages from anywhere (files, memory, abstract streams).
  - Get package and item attributes.
  - Stream package data.
  - Validate package data.
  - Added a C wrapper.
  - Improved and optimized package loading code.
  - Improved package detection.

  v1.1.8
  - Added CXZPFile support.

  v1.1.7
  - Added Source engine BSP support.

  v1.1.6
  - Added mipmap level option to CWADFile.

  v1.1.5
  - Improved CWADFile file support.

  v1.1.4
  - Improved detection of corrupt packages.

  v1.1.3
  - Extended CGCFFile.
  - Extended CFileMapping and CPrimitiveFileMapping to allow for volatile access.
  - Fixed CPackageUtility::Extract() bug caused by illegal characters.
  - Files of size 0 B are now treated as valid files.

  v1.1.2
  - Extended CPackage.
  - Extended CMappedPackage.
  - Improved error messages for system calls.

  v1.1.1
  - Fixed last error not being set in CMappedPackage::Open().

  v1.1.0
  - Rewrote mapping code to be more flexible.
  - Packages located on disk or in memory can now be loaded.
  - Optimized file mapping.
  - Fixed CPackage::Root bug.
  - Fixed CGCFFile::GetFileSizeOnDisk() bug.

  v1.0.4
  - Fixed CPackage memory leak.
  - Fixed CMappedPackage initialization bug.
  - Fixed CMappedPackage deinitialization bug.
  - Changed CDirectoryItem::Parent to a CDirectoryFolder.
  - Extended CWADFile.
  - Added CBSPFile which acts like CWADFile on a BSP's textures.

  v1.0.3
  - Extended CWADFile.
  - Changed GetFileSizeEx() to GetFileSize() (Not all versions of Windows supported the former).

  v1.0.2
  - Extended CPackage.
  - Extended CGCFFile.
  - Converted from bool to BOOL.
  - HLLib now used by GCFScape.

  v1.0.1
  - Added callback functionality to CPackageUtility::Extract().
  - Extended CGCFFile.
  - Minor bug fixes.

  v1.0.0
  - Original build.

==============================
Program Copyright-Permissions:
==============================

See the lgpl.txt (HLLib) and gpl.txt (HLExtract) files contained in the distribution.