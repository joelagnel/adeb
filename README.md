Project to give a rich Android development environment for end-users to use over adb.

androdeb aims to provide a powerful Linux environment where one can run popular
and mainstream Linux tracing, compiling, editing and other development tools.

Usecases
--------
(1) Powerful development environment with all tools ready to go (editors,
compilers, tracers, perl/python etc) for your on-device development.

(2) No more cross-compiler needed: Because it comes with gcc and clang, one can
build target packages natively without needing to do any cross compilation. We even
ship git, and have support to run apt-get to get any missing development packages.

(3) Using these one can run popular tools such as BCC that are difficult to run
in an Android environment due to lack of packages, dependencies and cross-compilation
needed for their operation.

(4) No more crippled tools: Its often a theme to build a static binary with
features disabled, because you couldn't cross-compile the feature's dependencies. One
classic example is perf. However, thanks to androdeb, we can build perf natively
on device without having to cripple it.

Requirements for running
------------------------
Target:
An ARM64 android N or later device which has "adb root" supported. Typically
this is a build in a userdebug configuration. Device should have atleast 2 GB
free space in the data partition.

Host:
A machine running recent Ubuntu or Debian, with 4GB of memory and 4GB free space.
Host needs qemu-debootstrap package installed. Run `apt-get install qemu-debootstrap`.

Notes:
* This project is pre-alpha and work in progress!
