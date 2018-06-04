#!/usr/bin/python
#
# By Joel Fernandes <joel@joelfernandes.org>
# (c) Google LLC.

from __future__ import print_function
from bcc import BPF
import argparse
import ctypes as ct
import sys
import subprocess
import os.path

examples=""

parser = argparse.ArgumentParser(
    description="Trace long critical sections",
    formatter_class=argparse.RawDescriptionHelpFormatter,
    epilog=examples)

parser.add_argument("-p", "--preemptoff", action="store_true",
                    help="Find long sections where preemption was off")

parser.add_argument("-i", "--irqoff", action="store_true",
                    help="Find long sections where IRQ was off")

parser.add_argument("-d", "--duration", default=100,
                    help="Duration in uS (microseconds) below which we filter")

args = parser.parse_args()

preemptoff = False
irqoff = False

if args.irqoff:
    preemptoff = False
    irqoff = True
elif args.preemptoff:
    preemptoff = True
    irqoff = False
    
debugfs_path = subprocess.Popen ("cat /proc/mounts | grep -w debugfs" + 
    " | awk '{print $2}'",
    shell=True,
    stdout=subprocess.PIPE).stdout.read().split("\n")[0]

if debugfs_path == "":
    print("ERROR: Unable to find debugfs mount point");
    sys.exit(0);

trace_path = debugfs_path + "/tracing/events/preemptirq/";

if (not os.path.exists(trace_path + "irq_disable") or
   not os.path.exists(trace_path + "irq_enable") or
   not os.path.exists(trace_path + "preempt_disable") or
   not os.path.exists(trace_path + "preempt_enable")):
    print("ERROR: required tracing events are not available\n" + 
        "Make sure the kernel is built with CONFIG_DEBUG_PREEMPT " + 
        "and CONFIG_PREEMPTIRQ_EVENTS enabled")
    sys.exit(0)

bpf_text = """
#include <uapi/linux/ptrace.h>
#include <linux/sched.h>

enum addr_offs {
    START_CALLER_OFF,
    START_PARENT_OFF,
    END_CALLER_OFF,
    END_PARENT_OFF
};

struct start_data {
    u32 addr_offs[2];
    u64 ts;
    int idle_skip;
    int active;
};

struct data_t {
    u64 time;
    u64 stack_id;
    u32 cpu;
    u64 id;
    u32 addrs[4];   /* indexed by addr_offs */
    char comm[TASK_COMM_LEN];
};

BPF_STACK_TRACE(stack_traces, 16384);
BPF_PERCPU_ARRAY(sts, struct start_data, 1);
BPF_PERCPU_ARRAY(isidle, u64, 1);
BPF_PERF_OUTPUT(events);

TRACEPOINT_PROBE(power, cpu_idle)
{
    int idx = 0;
    u64 val;
    struct start_data *stdp, std;

    stdp = sts.lookup(&idx);
    bpf_probe_read(&std, sizeof(struct start_data), stdp);

    // Mark active sections as that they should be skipped

    // Handle the case CSenter, Ienter, CSexit, Iexit
    // Handle the case CSenter, Ienter, Iexit, CSexit
    if (std.active) {
        std.idle_skip = 1;
        sts.update(&idx, &std);
    }

    // Mark CPU as actively within idle or not.
    if (args->state < 100) {
        bpf_trace_printk(\"Setting idle\\n\");
        val = 1;
        isidle.update(&idx, &val);
    } else {
        bpf_trace_printk(\"Resetting idle\\n\");
        val = 0;
        isidle.update(&idx, &val);
    }
    return 0;
}

static int in_idle(void)
{
     u64 *idlep;
     int idx = 0;

    // Skip event if we're in idle loop
    idlep = isidle.lookup(&idx);
    if (idlep && *idlep)
        return 1;
    return 0;
}

static void reset_state(void)
{
    int idx = 0;
    struct start_data s = {};

    sts.update(&idx, &s);
}

TRACEPOINT_PROBE(preemptirq, TYPE_disable)
{
    int idx = 0;
    struct start_data s;

    // Handle the case Ienter, CSenter, CSexit, Iexit
    // Handle the case Ienter, CSenter, Iexit, CSexit
    if (in_idle()) {
        bpf_trace_printk(\"disable: In idle, resetting\\n\");
        reset_state();
        return 0;
    }

    u64 ts = bpf_ktime_get_ns();

    bpf_trace_printk(\"Entered new section, setting time to %lu\\n\", (unsigned long)ts);
    s.idle_skip = 0;
    s.addr_offs[START_CALLER_OFF] = args->caller_offs;
    s.addr_offs[START_PARENT_OFF] = args->parent_offs;
    s.ts = ts;
    s.active = 1;
    bpf_trace_printk(\"Finished storing\\n\", (unsigned long)ts);

    sts.update(&idx, &s);
    return 0;
}

TRACEPOINT_PROBE(preemptirq, TYPE_enable)
{
    int idx = 0;
    u64 start_ts, end_ts, diff;
    struct start_data *stdp, std;

    // Handle the case CSenter, Ienter, CSexit, Iexit
    // Handle the case Ienter, CSenter, CSexit, Iexit
    if (in_idle()) {
        bpf_trace_printk(\"enable: In idle, resetting\\n\");
        reset_state();
        return 0;
    }

    bpf_trace_printk(\"enable: start lookup\\n\");

    stdp = sts.lookup(&idx);
    bpf_trace_printk(\"enable: start read\\n\");
    bpf_probe_read(&std, sizeof(struct start_data), stdp);

    // Handle the case Ienter, Csenter, Iexit, Csexit
    if (!std.active) {
        reset_state();
        return 0;
    }

    // Handle the case CSenter, Ienter, Iexit, CSexit
    if (std.idle_skip) {
        reset_state();
        return 0;
    }

    bpf_trace_printk(\"enable: start gettime\\n\");
    end_ts = bpf_ktime_get_ns();
    start_ts = std.ts;

    if (start_ts > end_ts) {
        bpf_trace_printk("ERROR: start < end\\n");
        reset_state();
        return 0;
    }

    diff = end_ts - start_ts;
    bpf_trace_printk(\"Exited section, diff is %lu\\n\", (unsigned long)diff);

    if (diff < DURATION) {
        reset_state();
        return 0;
    }

    u64 id = bpf_get_current_pid_tgid();
    struct data_t data = {};

    if (bpf_get_current_comm(&data.comm, sizeof(data.comm)) == 0) {
        data.addrs[START_CALLER_OFF] = std.addr_offs[START_CALLER_OFF];
        data.addrs[START_PARENT_OFF] = std.addr_offs[START_PARENT_OFF];
        data.addrs[END_CALLER_OFF] = args->caller_offs;
        data.addrs[END_PARENT_OFF] = args->parent_offs;

        data.id = id;
        data.stack_id = stack_traces.get_stackid(args, 0);
        data.time = diff;
        data.cpu = bpf_get_smp_processor_id();
        bpf_trace_printk(\"Large diff found: %lu\\n\", (unsigned long)diff);
        events.perf_submit(args, &data, sizeof(data));
    } else {
        bpf_trace_printk("ERROR: Couldn't get process name\\n");
    }

    reset_state();
    return 0;
}
"""
bpf_text = bpf_text.replace('DURATION', '{}'.format(int(args.duration) * 1000))

if preemptoff:
    bpf_text = bpf_text.replace('TYPE', 'preempt')
else:
    bpf_text = bpf_text.replace('TYPE', 'irq')

b = BPF(text=bpf_text)

TASK_COMM_LEN = 16    # linux/sched.h

class Data(ct.Structure):
    _fields_ = [
        ("time", ct.c_ulonglong),
        ("stack_id", ct.c_ulonglong),
        ("cpu", ct.c_int),
        ("id", ct.c_ulonglong),
        ("addrs", ct.c_int * 4),
        ("comm", ct.c_char * TASK_COMM_LEN),
    ]

def get_syms(kstack):
    syms = []

    for addr in kstack:
        s = b.ksym(addr, show_offset=True)
        syms.append(s)

    return syms

# process event
def print_event(cpu, data, size):
    try:
        global b
        event = ct.cast(data, ct.POINTER(Data)).contents
        stack_traces = b['stack_traces']
        stext = b.ksymname('_stext')

        if event.stack_id < 0:
            print("Empty kernel stack received\n")
            return

        print("===================================")
        print("TASK: %s (pid %5d tid %5d) Total Time: %-9.3fus\n\n" % (event.comm.decode(), \
            (event.id >> 32), (event.id & 0xffffffff), float(event.time) / 1000), end="")
        print("Section start: {} -> {}".format(b.ksym(stext + event.addrs[0]), b.ksym(stext + event.addrs[1])))
        print("Section end:   {} -> {}".format(b.ksym(stext + event.addrs[2]), b.ksym(stext + event.addrs[3])))

        if event.stack_id < 16384:
            kstack = stack_traces.walk(event.stack_id)
            syms = get_syms(kstack)
            if not syms:
                return

            for s in syms:
                print("  ", end="")
                print("%s" % s)
        else:
            print("NO STACK FOUND DUE TO COLLISION")
        print("===================================")
        print("")
    except:
        sys.exit(0)

b["events"].open_perf_buffer(print_event, page_cnt=256)

print("Finding critical section with {} disabled for > {}us".format(('preempt' if preemptoff else 'IRQ'), args.duration))

while 1:
    b.perf_buffer_poll();
