BCC (BPF compiler collection) for Android
=========================================

Introduction
------------
BCC is a compiler and a toolkit, containing powerful kernel tracing tools that
trace at the lowest levels, including adding hooks to functions in kernel space
and user space to deeply understand system behavior while being low in
overhead. [Here's a presentation with an
overview](http://www.joelfernandes.org/resources/bcc-ospm.pdf) and visit [BCC's
project page](https://github.com/iovisor/bcc) for the official BCC
documentation.

Quick Start
-----------
adeb is the primary vehicle for running BCC on Android. It supports preparing
the target Android device, cloning and building BCC on device, and other setup.
Take a look a quick look at [adeb
README](https://github.com/joelagnel/adeb/blob/master/README.md) so that you're
familiar with what it is.

To download a prebuilt filesystem with BCC already built/installed for an ARM
64-bit device, you can just run:
```
adeb prepare --full
```

This downloads a prebuilt filesystem for ARM 64-bit and sets it up on your device.

If your device is an architecture other than ARM64, see the [Other
Architectures
section](https://github.com/joelagnel/adeb/blob/master/BCC.md#other-architectures-other-than-arm64)

Now to run BCC, just start an adeb shell: `adeb shell`. This uses adb
in the background to start a shell into your adeb environment. Try running
`opensnoop` or any of the other BCC tracers to confirm that the setup worked
correctly.

If building your own kernel, following are the kernel requirements:

You need kernel 4.9 or newer. Anything less needs backports. Your kernel also
needs to be built with the following config options at the minimum:
```
CONFIG_KPROBES=y
CONFIG_KPROBE_EVENT=y
CONFIG_BPF_SYSCALL=y
CONFIG_IKHEADERS=m
```
Optionally,
```
CONFIG_UPROBES=y
CONFIG_UPROBE_EVENT=y
```

Build BCC during adeb install (Optional)
--------------------------------------------
If you would like the latest upstream BCC built and installed on your Android
device, you can run:
```
adeb prepare --build --bcc
```
NOTE: This is a slow process and can take a long time. Since it not only builds
BCC but also installs all non-BCC debian packages onto the filesystem and configures them.

Other Architectures (other than ARM64)
-----------------------
By default adeb assumes the target Android device is based on ARM64
processor architecture. For other architectures, use the --arch option. For
example for x86_64 architecture, run:
```
adeb prepare --arch amd64 --build --bcc
```
Note: The --download option ignores the --arch flag. This is because we only
provide pre-built filesystems for ARM64 at the moment.
Note: For arch other than 64-bit ARM, you have to pass --build, because
prebuilt filesystems are not available for other non-ARM64 architectures at the
moment.

Common Issues
-------------
Here are some common issues you may face when running different BCC tools.

* Issue 1: Headers are missing on the target device.

Symptom: This will usually result in an error like the following:
```
root@localhost:/# criticalstat

In file included from <built-in>:2
In file included from /virtual/include/bcc/bpf.h:12:
In file included from include/linux/types.h:5:
include/uapi/linux/types.h:4:10: fatal error: 'asm/types.h' file not found

#include <asm/types.h>                                                                                                                                                                   

         ^~~~~~~~~~~~~
1 error generated.
Traceback (most recent call last):

  File "./criticalstat.py", line 138, in <module>
    b = BPF(text=bpf_text)
  File "/usr/lib/python2.7/dist-packages/bcc/__init__.py", line 297, in __init__
    raise Exception("Failed to compile BPF text:\n%s" % text)
Exception: Failed to compile BPF text:
                                                                                                                                                                                         
#include <uapi/linux/ptrace.h>                                                                                                                                                           
#include <uapi/linux/limits.h>                                                                                                                                                           
#include <linux/sched.h>                                                                                                                                                                 

extern char _stext[];
```

* Issue 2: `CONFIG_KPROBES` isn't enabled.

Symptom: This will result in an error like the following:
```
Traceback (most recent call last):
  File "/usr/share/bcc/tools/cachetop", line 263, in <module>
    curses.wrapper(handle_loop, args)
  File "/usr/lib/python2.7/curses/wrapper.py", line 43, in wrapper
    return func(stdscr, *args, **kwds)
  File "/usr/share/bcc/tools/cachetop", line 172, in handle_loop
    b.attach_kprobe(event="add_to_page_cache_lru", fn_name="do_count")
  File "/usr/lib/python2.7/dist-packages/bcc/__init__.py", line 543, in
attach_kprobe
    fn = self.load_func(fn_name, BPF.KPROBE)
  File "/usr/lib/python2.7/dist-packages/bcc/__init__.py", line 355, in
load_func
    (func_name, errstr))
Exception: Failed to load BPF program do_count: Invalid argument
```

* Issue 3: `CONFIG_BPF_SYSCALL` isn't enabled.

Symptom: This may result in a compilation error like the following:
```
root@localhost:/# cachetop
Traceback (most recent call last):
  File "/usr/share/bcc/tools/cachetop", line 263, in <module>
    curses.wrapper(handle_loop, args)
  File "/usr/lib/python2.7/curses/wrapper.py", line 43, in wrapper
    return func(stdscr, *args, **kwds)
  File "/usr/share/bcc/tools/cachetop", line 171, in handle_loop
    b = BPF(text=bpf_text)
  File "/usr/lib/python2.7/dist-packages/bcc/__init__.py", line 297, in __init__
    raise Exception("Failed to compile BPF text:\n%s" % text)
Exception: Failed to compile BPF text:


    #include <uapi/linux/ptrace.h>
    struct key_t {
        u64 ip;
        u32 pid;
        u32 uid;
        char comm[16];
    };

    BPF_HASH(counts, struct key_t);

    int do_count(struct pt_regs *ctx) {
        struct key_t key = {};
        u64 zero = 0 , *val;
        u64 pid = bpf_get_current_pid_tgid();
        u32 uid = bpf_get_current_uid_gid();

        key.ip = PT_REGS_IP(ctx);
        key.pid = pid & 0xFFFFFFFF;
        key.uid = uid & 0xFFFFFFFF;
        bpf_get_current_comm(&(key.comm), 16);

        val = counts.lookup_or_init(&key, &zero);  // update counter
        (*val)++;
        return 0;
    }
```
