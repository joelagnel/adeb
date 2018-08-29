adeb
--------

**adeb** (also known as **androdeb**) provides a powerful Linux shell
environment where one can run popular and mainstream Linux tracing, compiling,
editing and other development tools on an existing Android device. All the
commands typically available on a modern Linux system are supported in
adeb.

Usecases
--------
1. Powerful development environment with all tools ready to go (editors,
compilers, tracers, perl/python etc) for your on-device development.

2. No more cross-compiler needed: Because it comes with gcc and clang, one can
build target packages natively without needing to do any cross compilation. We even
ship git, and have support to run apt-get to get any missing development packages
from the web.

3. Using these one can run popular tools such as BCC that are difficult to run
in an Android environment due to lack of packages, dependencies and
cross-compilation needed for their operation. [Check BCC on Android using
adeb](https://github.com/joelagnel/adeb/blob/master/BCC.md) for more
information on that.

4. No more crippled tools: Its often a theme to build a static binary with
features disabled, because you couldn't cross-compile the feature's dependencies. One
classic example is perf. However, thanks to adeb, we can build perf natively
on device without having to cripple it.

Requirements for running
------------------------
Target:
An ARM64 android N or later device which has "adb root" supported. Typically
this is a build in a userdebug configuration. Device should have atleast 2 GB
free space in the data partition. If you would like to use other architectures,
see the [Other Architectures](https://github.com/joelagnel/adeb/blob/master/README.md#how-to-use-adeb-for-other-architectures-other-than-arm64) section.

Host:
A machine running recent Ubuntu or Debian, with 4GB of memory and 4GB free space.
Host needs debootstrap and qemu-debootstrap packages.
To install it, run `sudo apt-get install qemu-user-static debootstrap`.
Other distributions may work but they are not tested.

Quick Start Instructions
------------------------
* First clone this repository into adb and cd into it.
```
cd adeb

# Add some short cuts:
sudo ln -s $(pwd)/adeb /usr/bin/adeb

# Cached image downloads result in a huge speed-up. These are automatic if you
# cloned the repository using git. However, if you downloaded the repository
# as a zip file (or you want to host images elsewere), you could set the
# ADEB_REPO_URL environment variable in your bashrc file.
# Disclaimer: Google is not liable for the below URL and this
#             is just an example.
export ADEB_REPO_URL="github.com/joelagnel/adeb/"
```

* Installing adeb onto your device:
First make sure device is connected to system
Then run, for the base image:
```
adeb prepare
```
The previous command only downloads and installs the base image.
Instead if you want to download and install the full image, do:
```
adeb prepare --full
```

* Now run adeb shell to enter your new environment!:
```
adeb shell
```

* Once done, hit `CTRL + D` and you will exit out of the shell.
To remove adeb from the device, run:
```
adeb remove
```
If you have multiple devices connected, please add `-s <serialnumber>`.
Serial numbers of all devices connected can be obtained by `adb devices`.

* To update an existing adeb clone on your host, run:
```
adeb git-pull
```

More advanced usage instructions
--------------------------------
### Install kernel headers in addition to preparing adeb device:
```
adeb prepare --kernelsrc /path/to/kernel-source
```

### Update kernel headers onto an already prepared device:

If you need to put kernel sources for an existing install, run:
```
adeb prepare --kernelsrc /path/to/kernel-source --skip-install
```
Note: The kernel sources should have been built (atleast build should have started).

### Build and prepare device with a custom rootfs locally:

The adeb fs will be prepared locally by downloading packages as needed:
```
adeb prepare --build
```
This is unlike the default behavior, where the adeb rootfs is itself pulled from the web.

If you wish to do a full build (that is locally prepare a rootfs with all packages, including bcc, then do):
```
adeb prepare --full --build
```

### Add kernel headers to device in addition to building locally:
```
adeb prepare --build --kernelsrc /path/to/kernel-source/
```

### Build/install a base image with BCC:
```
adeb prepare --build --bcc --kernelsrc /path/to/kernel-source/
```
Note: BCC is built from source. Also `--kernelsrc` is recommended for tools to
function unless device has them already.

### Extract the FS from the device, after its prepared:
```
adeb prepare --buildtar /path/
```
After device is prepared, it will extract the root fs from it
and store it as a tar archive at `/path/adeb-fs.tgz`. This
can be used later.

### Use a previously prepared adeb rootfs tar from local:
```
adeb prepare --archive /path/adeb-fs.tgz
```

### Build a standalone raw EXT4 image out of the FS:
```
adeb prepare --build-image /path/to/image.img
```
This can then be passed to Qemu as -hda. Note: This option doesn't need a
device connected.

### How to use adeb for other Architectures (other than ARM64)
By default adeb assumes the target Android device is based on ARM64
processor architecture. For other architectures, use the --arch option. For
example for x86_64 architecture, run:
```
adeb prepare --build --arch amd64 --bcc --kernelsrc /path/to/kernel-source/
```
Note: The --download option ignores the --arch flag. This is because we only
provide pre-built filesystems for ARM64 at the moment.

Common Trouble shooting
-----------------
1. Installing g++ with `apt-get install g++` fails.

Solution: Run `adeb shell apt-get update` after the `adeb prepare` stage.

2. It's too slow to use debootstrap to create debian fs

Solution: Use a local mirror, for example in China you could use
https://mirror.tuna.tsinghua.edu.cn/debian/ instead of debian official website
http://deb.debian.org/debian/
