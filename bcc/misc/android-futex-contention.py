# futex contention
# (c) 2010, Arnaldo Carvalho de Melo <acme@redhat.com>
# Licensed under the terms of the GNU GPL License version 2
#
# Translation of:
#
# http://sourceware.org/systemtap/wiki/WSFutexContention
#
# to perf python scripting.
#
# Measures futex contention

import os, sys
sys.path.append(os.environ['PERF_EXEC_PATH'] + '/scripts/python/Perf-Trace-Util/lib/Perf/Trace')
from Util import *

process_names = {}
thread_thislock = {}
thread_blocktime = {}

lock_waits = {} # long-lived stats on (tid,lock) blockage elapsed time
waker_wakee = {} # maps the futex waker to wakee
max_waits = {} # Details about a maximum contention like owner, owner chain
process_names = {} # long-lived pid-to-execname mapping

def android_lock(callchain):
    for c in callchain:
        if 'sym' in c and 'name' in c['sym']:
            name = c['sym']['name']
        else:
            continue

        if 'art::Monitor::Lock' in name:
            return True
    return False

def print_callchain(callchain):
    for c in callchain:
        if 'sym' in c and 'name' in c['sym']:
            name = c['sym']['name']
        else:
            continue

        print("    %s" % (name))

def sched__sched_waking(event_name, context, common_cpu,
        common_secs, common_nsecs, common_pid, common_comm,
        common_callchain, comm, pid, prio, success,
        target_cpu):
        waker_wakee[pid] = [common_pid, common_callchain]

def syscalls__sys_enter_futex(event, ctxt, cpu, s, ns, tid, comm, callchain,
			      nr, uaddr, op, val, utime, uaddr2, val3):

	cmd = op & FUTEX_CMD_MASK
        if cmd != FUTEX_WAIT or android_lock(callchain) == False:
		return # we don't care about originators of WAKE events 
                       # or futex uses that aren't android locks.

	process_names[tid] = comm
	thread_thislock[tid] = uaddr
	thread_blocktime[tid] = nsecs(s, ns)

def syscalls__sys_exit_futex(event, ctxt, cpu, s, ns, tid, comm, callchain,
			     nr, ret):

        waker_pid = -1
        waker_chain = "[no call chain]"

	if thread_blocktime.has_key(tid):
                # Gather stats about the contention (sum, min, max)
		elapsed = nsecs(s, ns) - thread_blocktime[tid]
		add_stats(lock_waits, (tid, thread_thislock[tid]), elapsed)

                # Track details about the maximum contention seen
                # including owner and its callchain
                if (tid, thread_thislock[tid]) in max_waits:
                    prev_wait = max_waits[(tid, thread_thislock[tid])][0]
                else:
                    prev_wait = 0

                if elapsed > prev_wait:
                    if tid in waker_wakee:
                        waker_pid = waker_wakee[tid][0]
                        waker_chain = waker_wakee[tid][1]

                    max_waits[(tid, thread_thislock[tid])] = [elapsed, waker_pid, waker_chain, callchain]

		del thread_blocktime[tid]
		del thread_thislock[tid]

def trace_begin():
	print "Press control+C to stop and show the summary"

def trace_end():
	for (tid, lock) in lock_waits:
                print("\n==============================================================\n")
		min, max, avg, count = lock_waits[tid, lock]
		print "%s[%d] lock %x contended %d times, %d avg ns, %d max ns" % \
		      (process_names[tid], tid, lock, count, avg, max)
                print ""

                if not (tid, lock) in max_waits:
                    print"Max contention info not available"
                    continue

                print "Callstack of suffering task:"
                print_callchain(max_waits[tid, lock][3])
                print ""

                waker_pid = max_waits[tid, lock][1]
                waker_name = process_names[waker_pid] if waker_pid in process_names else "nameless-owner"
                print "Owner %s caused this contention of %d ns. Owner's Call stack below:" % (waker_name, max_waits[tid, lock][0])
                print_callchain(max_waits[tid, lock][2])

