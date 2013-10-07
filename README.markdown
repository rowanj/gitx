# What is GitX?

GitX is a graphical client for the `git` version control system, written
specifically for OS X Lion (10.7) and higher.

There last build compatible with OS X Snow Leopard (10.6) is [0.14.81](http://builds.phere.net/GitX/development/GitX-dev-81.dmg), from February 4th 2013.

This means that it has a native interface and tries to integrate with the
operating system as good as possible. Examples of this are drag and drop
support and QuickLook support.

# What is GitX-dev?

This fork (variant) of GitX focuses on programmer-oriented features for those
working with the latest tools for developing software for current Apple platforms.
As such, it only supports 64-bit Intel macs, and currently deploying versions of OS X and Xcode.

Drawing several important early improvements from mainline "official" GitX 
from GitX (L) and others, we are prioritizing moving away from deprecated
or unreliable technologies like a dependency on command-line `git` usage
to drive GitX features; and staying up-to-date with Apple and third-party
frameworks and libraries that are used.

# Getting GitX-dev

## Download the latest binary

[![Latest GitX-dev Package](http://rowanj.github.com/gitx/images/gitx.jpg)](http://builds.phere.net/GitX/development/GitX-dev.dmg)

*[Download the latest .DMG](http://builds.phere.net/GitX/development/GitX-dev.dmg)*

GitX-dev uses the [Sparkle](http://sparkle.andymatuschak.org/) framework for in-app updates; so once you have version 0.11 (December 2011) or later, you can check for or update to new builds from the GitX menu at any time, or opt-in for automatic updates.

## Archived binaries

Old binary archives are available on the [GitHub project downloads page](http://github.com/rowanj/gitx/downloads).

# Features

The project is well underway, and based on the solid foundations of GitX and
GitX (L), used day-to-day by our developers.  We consider GitX-dev to be
close to feature-complete, with very few workflows dependant on manual
command-line `git` usage.

  * History browsing of your repository
  * See a nicely formatted diff of any revision
  * Search based on author or revision subject
  * Look at the complete tree of any revision
    * Preview any file in the tree in a text view or with QuickLook
    * Drag and drop files out of the tree view to copy them to your system
  * Support for all parameters git rev-list has
  * Good performance on large (200+ MB) repositories

# Development

Developing for GitX-dev has a few requirements above and beyond those
for mainline GitX.

Most third-party code is referenced with Git submodules, so [read up](http://book.git-scm.com/5_submodules.html) on those if you're not familiar.

  * Very recent Xcode install, 4.5 release strongly recommended.
  * Most development is done on OS X Lion, Snow Leopard may or may not work
  * `CMake` with a working command-line compiling environment for building `libgit2`
  * `node.js` for building `SyntaxHighlighter` (not necessary unless you're updating SyntaxHighlighter itself)

To get GitX-dev to compile locally you need to:

  1. Clone the repository locally: `git clone https://github.com/rowanj/gitx.git`
  2. After cloning it `cd gitx` and then recursively initialize all submodules: `git submodule update --init --recursive`
  3. Then compile objective-git `cd objective-git && ./script/update_libgit2`

After that you should be able to open the Xcode project and build successfully.

# License

GitX is licensed under the GPL version 2. For more information, see the attached COPYING file.

# Usage

GitX itself is fairly simple. Most of its power is in the 'gitx' binary, which
you should install through the menu. the 'gitx' binary supports most of git
rev-list's arguments. For example, you can run `gitx --all` to display all
branches in the repository, or `gitx -- Documentation` to only show commits
relating to the 'Documentation' subdirectory. With `gitx -Shaha`, gitx will
only show commits that contain the word 'haha'. Similarly, with `gitx
v0.2.1..`, you will get a list of all commits since version 0.2.1.

# Helping out

Any help on GitX is welcome. GitX is programmed in Objective-C, but even if
you are not a programmer you can do useful things. A short selection:

  * Give feedback
  * File [bug reports](https://github.com/rowanj/gitx/issues?labels=Bug) and [feature requests](https://github.com/rowanj/gitx/issues?labels=Feature).
