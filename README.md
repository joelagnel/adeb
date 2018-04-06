androdeb
--------

**androdeb** provides a powerful Linux shell environment where one can
run popular and mainstream Linux tracing, compiling, editing and other
development tools on an existing Android device. All the commands typically
available on a modern Linux system are supported in androdeb.

Usecases
--------
1. Powerful development environment with all tools ready to go (editors,
compilers, tracers, perl/python etc) for your on-device development.

2. No more cross-compiler needed: Because it comes with gcc and clang, one can
build target packages natively without needing to do any cross compilation. We even
ship git, and have support to run apt-get to get any missing development packages
from the web.

3. Using these one can run popular tools such as BCC that are difficult to run
in an Android environment due to lack of packages, dependencies and cross-compilation
needed for their operation.

4. No more crippled tools: Its often a theme to build a static binary with
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
Host needs debootstrap and qemu-debootstrap packages.
To install it, run `sudo apt-get install qemu-user-static debootstrap`.
Other distributions may work but they are not tested.

Quick Start Instructions
------------------------
* Clone androdeb repository:
```
git clone https://github.com/joelagnel/androdeb.git
cd androdeb
sudo ln -s ./androdeb /usr/bin/androdeb
```

* Fastest way of installing androdeb onto your device:
```
# First make sure device is connected to system
androdeb prepare --download
```

* Now run androdeb shell to enter your new environment!:
```
androdeb shell
```

* Once done, hit `CTRL + D` and you will exit out of the shell.
To remove androdeb from the device, run:
```
androdeb remove
```
If you have multiple devices connected, please add `-s <serialnumber>`.
Serial numbers of all devices connected can be obtained by `adb devices`.

* To update the androdeb you cloned on your host, run:
```
androdeb pull
```

More advanced usage instructions
--------------------------------
### Install kernel headers in addition to preparing androdeb device:
```
androdeb prepare --download --kernelsrc /path/to/kernel-source
```

### Update kernel headers onto an already prepared device:

If you need to put kernel sources for an existing install, run:
```
androdeb prepare --kernelsrc /path/to/kernel-source
```
Note: The kernel sources should have been built (atleast build should have started).

### Build and prepare device with a custom rootfs locally:

The androdeb fs will be prepared locally by downloading packages as needed:
```
androdeb prepare --fullbuild
```
This is unlike `--download` where the androdeb rootfs is itself pulled from the web.

### Add kernel headers to device in addition to building locally:
```
androdeb prepare --fullbuild --kernelsrc /path/to/kernel-source/
```

### Instead of `--fullbuild`, customize what you install:
```
androdeb prepare --editors --compilers
```

### Install only BCC:
```
androdeb prepare --bcc --kernelsrc /path/to/kernel-source/
```
Note: BCC is built while being installed. Also `--kernelsrc` is
recommended for tools to function unless device has them
already.

### Extract the FS from the device, after its prepared:
```
androdeb prepare --fullbuild --buildtar /path/
```
After device is prepared, it will extract the root fs from it
and store it as a tar archive at `/path/androdeb-fs.tgz`. This
can be used later.

### Use a previously prepared androdeb rootfs tar from local:
```
androdeb prepare --archive /path/androdeb-fs.tgz
```
