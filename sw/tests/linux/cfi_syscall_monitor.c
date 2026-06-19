// Copyright 2026 Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// cfi_syscall_monitor.c — Linux userspace CFI syscall-boundary monitor
//
// Paired with cfi_syscall_inspector.c running on Ibex.
//
// Usage
// -----
//   sudo ./cfi_syscall_monitor [--no-ibex] [--strict] <application> [args...]
//
//   --no-ibex  Dry-run mode: skips /dev/mem mapping, Ibex sync, and mbox
//              notification.  Instead, prints the name and number of every
//              sensitive syscall to stdout as it is intercepted.  Useful
//              for testing the ptrace interception layer without SCAR-V
//              hardware — no root or /dev/mem required.
//
//   --bench    Timing baseline mode: intercepts syscalls via ptrace (same
//              code path as normal mode) but never calls notify_ibex and
//              never prints per-syscall lines.  Reports wall time of the
//              monitored process and how many times the filter matched.
//              Use this to quantify the ptrace-stop overhead alone; subtract
//              from a normal-mode run to isolate the Ibex inspection cost.
//              Skips /dev/mem mapping (no root needed for this flag alone).
//              Can be combined with --strict to match the same filter set
//              as a normal --strict run.
//
//   --strict   Enable the extended (L2) syscall filter in addition to the
//              default (L1) one.  L2 adds lower-frequency but high-risk
//              calls: mremap, memfd_create, ptrace, process_vm_writev,
//              namespace ops (unshare/pivot_root/chroot/setns), kernel
//              module and eBPF loading, extended uid/gid/cap setters, dup2/3,
//              and filesystem link calls.  Can be combined with --no-ibex.
//              Every intercepted syscall is tagged [L1] or [L2] in the log.
//
// What it does
// ------------
//  Identical to cfi_launcher.c for steps 1–4 (fork, VA→PA table, Ibex sync).
//  Differs from step 5 onward:
//
//  5. Resumes the child with PTRACE_SYSCALL (not PTRACE_CONT) so every
//     sensitive syscall entry stops the child and wakes the parent.
//
//  6. On each sensitive syscall entry:
//       a. Sets scratch 14 to CFI_RESULT_BUSY (Ibex polling sentinel).
//       b. Writes the syscall number into mbox 1 letter0 and rings the
//          doorbell — Ibex receives PLIC IRQ 159 and inspects the last
//          CFI_WINDOW_SIZE snooper ring entries.
//       c. Spins on scratch 14 until Ibex writes a result.
//       d. If CFI_RESULT_VIOLATION: kills the child and exits.
//       e. Resumes the child with PTRACE_SYSCALL for the next stop.
//
//  7. Non-sensitive syscalls and syscall-exit stops are passed through
//     immediately with no Ibex notification.
//
//  8. When the child exits, writes CFI_MSG_APP_DONE to the mailbox so
//     Ibex can disarm the snooper cleanly.
//
// Sensitive syscall filter
// ------------------------
//  Only syscalls with potential security impact are inspected — this
//  avoids paying the mbox round-trip cost on high-frequency innocuous
//  calls (read, getpid, clock_gettime, ...).  The default list covers
//  the most common ROP payload targets.  Adjust is_sensitive() below.
//
// Requirements
// ------------
//  Same as cfi_launcher.c (root, /dev/mem, mlockall).
//  Kernel >= 5.3 for PTRACE_GET_SYSCALL_INFO.

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/mman.h>
#include <sys/ptrace.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/syscall.h>
#include <linux/ptrace.h>
#include <time.h>
#include <signal.h>

#include "cfi_va_pa_table.h"
// cfi_syscall_proto.h lives in the Ibex common tree; on the Linux side
// we replicate the handful of constants we need directly below so that
// the Linux build does not have to pull in the Ibex include path.
// Keep these in sync with working_dir/opentitan/sw/tests/common/cfi_syscall_proto.h.
#define CFI_SCRATCH_RESULT_OFF   0x38u
#define CFI_RESULT_BUSY          0xFFFFFFFFu
#define CFI_RESULT_PASS          0x00000000u
#define CFI_RESULT_VIOLATION     0x00000001u
#define CFI_MSG_SYSCALL          0x01000000u
#define CFI_MSG_APP_DONE         0x02000000u

// ---------------------------------------------------------------------------
// Platform constants
// ---------------------------------------------------------------------------
#define HOST_REGS_PHYS      0x03000000u
#define HOST_REGS_MAP_SZ    0x1000u

// Mbox peripheral page base — must be page-aligned for mmap(/dev/mem).
// Mbox 1 registers sit at offset 1 * 0x100 within this page.
#define CAR_MBOX_PHYS       0x40000000u
#define CAR_MBOX_MAP_SZ     0x1000u     // one full page covers all mbox instances
#define MBOX_STRIDE         0x100u

// Mbox register offsets within one mailbox instance (from car_memory_map.h)
#define MBOX_INT_SND_SET_OFF  0x04u
#define MBOX_INT_SND_EN_OFF   0x0Cu
#define MBOX_LETTER0_OFF      0x80u

// ---------------------------------------------------------------------------
// Sensitive syscall filter + name table
// ---------------------------------------------------------------------------
static int is_sensitive(uint64_t nr) {
    switch (nr) {
    case __NR_execve:
    case __NR_execveat:
    case __NR_mprotect:
    case __NR_mmap:
    case __NR_clone:
    case __NR_clone3:
    case __NR_write:
    case __NR_writev:
    case __NR_pwrite64:
    case __NR_sendmsg:
    case __NR_sendto:
    case __NR_connect:
    case __NR_bind:
    case __NR_socket:
    case __NR_openat:
    case __NR_unlinkat:
    case __NR_renameat2:
    case __NR_setuid:
    case __NR_setgid:
    case __NR_prctl:
        return 1;
    default:
        return 0;
    }
}

// ---------------------------------------------------------------------------
// L2 (strict) filter — additive on top of L1, enabled with --strict
// ---------------------------------------------------------------------------
static int is_sensitive_strict(uint64_t nr) {
    switch (nr) {
    // Memory remapping / anonymous executable regions
    case __NR_mremap:
    case __NR_memfd_create:
    // Process injection
    case __NR_ptrace:
    case __NR_process_vm_writev:
    // Namespace / container escape
    case __NR_unshare:
    case __NR_pivot_root:
    case __NR_chroot:
    case __NR_setns:
    // Kernel code loading
    case __NR_init_module:
    case __NR_finit_module:
    case __NR_bpf:
    // Extended privilege setters
    case __NR_setresuid:
    case __NR_setresgid:
    case __NR_setfsuid:
    case __NR_setfsgid:
    case __NR_capset:
    // fd redirection (stdio setup before execve)
#ifdef __NR_dup2
    case __NR_dup2:     // not present on RISC-V 64-bit (use dup3)
#endif
    case __NR_dup3:
    // Filesystem links
    case __NR_symlinkat:
    case __NR_linkat:
        return 1;
    default:
        return 0;
    }
}

static const char *syscall_name(uint64_t nr) {
    switch (nr) {
    // L1
    case __NR_execve:          return "execve";
    case __NR_execveat:        return "execveat";
    case __NR_mprotect:        return "mprotect";
    case __NR_mmap:            return "mmap";
    case __NR_clone:           return "clone";
    case __NR_clone3:          return "clone3";
    case __NR_write:           return "write";
    case __NR_writev:          return "writev";
    case __NR_pwrite64:        return "pwrite64";
    case __NR_sendmsg:         return "sendmsg";
    case __NR_sendto:          return "sendto";
    case __NR_connect:         return "connect";
    case __NR_bind:            return "bind";
    case __NR_socket:          return "socket";
    case __NR_openat:          return "openat";
    case __NR_unlinkat:        return "unlinkat";
    case __NR_renameat2:       return "renameat2";
    case __NR_setuid:          return "setuid";
    case __NR_setgid:          return "setgid";
    case __NR_prctl:           return "prctl";
    // L2
    case __NR_mremap:          return "mremap";
    case __NR_memfd_create:    return "memfd_create";
    case __NR_ptrace:          return "ptrace";
    case __NR_process_vm_writev: return "process_vm_writev";
    case __NR_unshare:         return "unshare";
    case __NR_pivot_root:      return "pivot_root";
    case __NR_chroot:          return "chroot";
    case __NR_setns:           return "setns";
    case __NR_init_module:     return "init_module";
    case __NR_finit_module:    return "finit_module";
    case __NR_bpf:             return "bpf";
    case __NR_setresuid:       return "setresuid";
    case __NR_setresgid:       return "setresgid";
    case __NR_setfsuid:        return "setfsuid";
    case __NR_setfsgid:        return "setfsgid";
    case __NR_capset:          return "capset";
#ifdef __NR_dup2
    case __NR_dup2:            return "dup2";
#endif
    case __NR_dup3:            return "dup3";
    case __NR_symlinkat:       return "symlinkat";
    case __NR_linkat:          return "linkat";
    default:                   return "unknown";
    }
}

// ---------------------------------------------------------------------------
// map_phys / vma helpers (identical to cfi_launcher.c)
// ---------------------------------------------------------------------------
static void *map_phys(int memfd, uint32_t phys, size_t sz) {
    void *p = mmap(NULL, sz, PROT_READ | PROT_WRITE, MAP_SHARED,
                   memfd, (off_t)phys);
    return p;
}

static int vma_is_kernel_special(const char *line) {
    const char *p = strrchr(line, ' ');
    if (!p) p = strrchr(line, '\t');
    if (!p) return 0;
    while (*p == ' ' || *p == '\t') p++;
    if (strncmp(p, "[vdso", 5) == 0) return 1;
    if (strncmp(p, "[vsys", 5) == 0) return 1;
    return 0;
}

static int fault_in_page(int mem_fd, uintptr_t va) {
    char dummy;
    return (pread(mem_fd, &dummy, 1, (off_t)va) < 1) ? -1 : 0;
}

static uint64_t read_pfn(int pagemap_fd, uintptr_t va) {
    uint64_t entry = 0;
    off_t off = (off_t)((va / CFI_PAGE_SIZE) * sizeof(uint64_t));
    if (pread(pagemap_fd, &entry, sizeof(entry), off) != (ssize_t)sizeof(entry))
        return 0;
    if (!(entry & (1ULL << 63)))
        return 0;
    return entry & ((1ULL << 55) - 1);
}

static int build_table(pid_t pid, cfi_va_pa_table_t *tbl) {
    char path[64];

    snprintf(path, sizeof(path), "/proc/%d/mem", (int)pid);
    int mem_fd = open(path, O_RDONLY);
    if (mem_fd < 0) { perror("[cfi] open /proc/<pid>/mem"); return -1; }

    snprintf(path, sizeof(path), "/proc/%d/pagemap", (int)pid);
    int pagemap_fd = open(path, O_RDONLY);
    if (pagemap_fd < 0) { perror("[cfi] open pagemap"); close(mem_fd); return -1; }

    snprintf(path, sizeof(path), "/proc/%d/maps", (int)pid);
    FILE *maps = fopen(path, "r");
    if (!maps) { perror("[cfi] fopen maps"); close(pagemap_fd); close(mem_fd); return -1; }

    memset(tbl, 0, sizeof(*tbl));
    tbl->magic            = CFI_TABLE_MAGIC;
    tbl->va_range_start_l = 0xFFFFFFFFu;
    tbl->va_range_start_h = 0xFFFFFFFFu;

    char line[512];
    while (fgets(line, sizeof(line), maps)) {
        uintptr_t va_start = 0, va_end = 0;
        char perms[8] = {0};
        if (sscanf(line, "%lx-%lx %7s", &va_start, &va_end, perms) < 3) continue;
        if (perms[2] != 'x') continue;
        if (vma_is_kernel_special(line)) continue;

        printf("[cfi]   VMA 0x%lx-0x%lx %s\n", va_start, va_end, perms);

        for (uintptr_t fva = va_start; fva < va_end; fva += CFI_PAGE_SIZE)
            fault_in_page(mem_fd, fva);

        uintptr_t va = va_start;
        while (va < va_end && tbl->num_segs < CFI_MAX_SEGS) {
            uint64_t pfn = read_pfn(pagemap_fd, va);
            if (pfn == 0) { va += CFI_PAGE_SIZE; continue; }

            uintptr_t seg_va = va;
            uint64_t  seg_pfn = pfn;
            uint32_t  n = 0;
            while (va < va_end) {
                uint64_t p = read_pfn(pagemap_fd, va);
                if (p != seg_pfn + n) break;
                n++; va += CFI_PAGE_SIZE;
            }

            cfi_segment_t *s = &tbl->seg[tbl->num_segs++];
            s->va_base_l = (uint32_t)(seg_va & 0xFFFFFFFFUL);
            s->va_base_h = (uint32_t)(seg_va >> 32);
            s->pa_base   = (uint32_t)(seg_pfn * CFI_PAGE_SIZE);
            s->num_pages = n;
            printf("[cfi]     seg[%u]: VA=0x%08x_%08x PA=0x%08x pages=%u\n",
                   tbl->num_segs - 1, s->va_base_h, s->va_base_l, s->pa_base, n);

            uintptr_t seg_end = seg_va + (uintptr_t)n * CFI_PAGE_SIZE;
            uintptr_t cur_s   = ((uintptr_t)tbl->va_range_start_h << 32) | tbl->va_range_start_l;
            uintptr_t cur_e   = ((uintptr_t)tbl->va_range_end_h   << 32) | tbl->va_range_end_l;
            if (seg_va  < cur_s) { tbl->va_range_start_l = (uint32_t)seg_va;  tbl->va_range_start_h = (uint32_t)(seg_va  >> 32); }
            if (seg_end > cur_e) { tbl->va_range_end_l   = (uint32_t)seg_end; tbl->va_range_end_h   = (uint32_t)(seg_end >> 32); }
        }
    }

    fclose(maps);
    close(pagemap_fd);
    close(mem_fd);

    if (tbl->num_segs == 0) { fprintf(stderr, "[cfi] ERROR: no executable pages\n"); return -1; }

    __sync_synchronize();
    tbl->ready = CFI_TABLE_READY_MAGIC;
    printf("[cfi] Table: %u segs, VA=[0x%08x_%08x, 0x%08x_%08x)\n",
           tbl->num_segs,
           tbl->va_range_start_h, tbl->va_range_start_l,
           tbl->va_range_end_h,   tbl->va_range_end_l);
    return 0;
}

// ---------------------------------------------------------------------------
// notify_ibex — write syscall_nr to mbox 1 and poll scratch 14 for result.
// Returns CFI_RESULT_PASS (0) or CFI_RESULT_VIOLATION (1).
// *elapsed_ns is filled with the round-trip time in nanoseconds (doorbell
// write → scratch14 result).  Pass NULL to skip the measurement.
// ---------------------------------------------------------------------------
static uint32_t notify_ibex(volatile uint32_t *host_regs,
                             volatile uint32_t *mbox1,
                             uint64_t nr,
                             uint64_t *elapsed_ns) {
    // Arm the polling sentinel before raising the IRQ so Ibex always sees
    // BUSY before writing its result (avoids a stale PASS from a prior run).
    host_regs[CFI_SCRATCH_RESULT_OFF / 4] = CFI_RESULT_BUSY;
    __sync_synchronize();

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    mbox1[MBOX_LETTER0_OFF / 4]    = (uint32_t)(CFI_MSG_SYSCALL | (nr & 0x00FFFFFFu));
    __sync_synchronize();
    mbox1[MBOX_INT_SND_EN_OFF  / 4] = 1u;
    mbox1[MBOX_INT_SND_SET_OFF / 4] = 1u;
    __sync_synchronize();

    // Spin until Ibex writes a result.  A timeout here would prevent
    // indefinite stall if Ibex firmware is not running.
    uint32_t result;
    do {
        result = host_regs[CFI_SCRATCH_RESULT_OFF / 4];
    } while (result == CFI_RESULT_BUSY);

    clock_gettime(CLOCK_MONOTONIC, &t1);

    if (elapsed_ns)
        *elapsed_ns = (uint64_t)(t1.tv_sec  - t0.tv_sec)  * 1000000000ULL +
                      (uint64_t)(t1.tv_nsec - t0.tv_nsec);

    return result;
}

// ---------------------------------------------------------------------------
// send_app_done — notify Ibex that the monitored process has exited.
// ---------------------------------------------------------------------------
static void send_app_done(volatile uint32_t *mbox1) {
    mbox1[MBOX_LETTER0_OFF / 4]    = CFI_MSG_APP_DONE;
    __sync_synchronize();
    mbox1[MBOX_INT_SND_EN_OFF  / 4] = 1u;
    mbox1[MBOX_INT_SND_SET_OFF / 4] = 1u;
    __sync_synchronize();
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
int main(int argc, char *argv[]) {
    int no_ibex = 0, strict = 0, bench = 0;
    while (argc >= 2) {
        if      (strcmp(argv[1], "--no-ibex") == 0) { no_ibex = 1; argv++; argc--; }
        else if (strcmp(argv[1], "--strict")  == 0) { strict  = 1; argv++; argc--; }
        else if (strcmp(argv[1], "--bench")   == 0) { bench   = 1; argv++; argc--; }
        else break;
    }
    if (argc < 2) {
        fprintf(stderr,
                "Usage: %s [--no-ibex] [--bench] [--strict] <application> [args...]\n",
                argv[0]);
        return 1;
    }
    // --bench implies no Ibex involvement; no_ibex controls /dev/mem mapping.
    if (bench) no_ibex = 1;

    // -----------------------------------------------------------------------
    // 1. Map physical regions via /dev/mem  (skipped in --no-ibex mode)
    // -----------------------------------------------------------------------
    int memfd = -1;
    cfi_va_pa_table_t       *tbl      = NULL;
    volatile uint32_t       *host_regs = NULL;
    volatile uint32_t       *mbox1     = NULL;

    if (!no_ibex) {
        memfd = open("/dev/mem", O_RDWR | O_SYNC);
        if (memfd < 0) { perror("[cfi] open /dev/mem"); return 1; }

        tbl = map_phys(memfd, CFI_TABLE_PHYS_BASE, CFI_TABLE_PHYS_SIZE);
        if (tbl == MAP_FAILED) { perror("[cfi] mmap CFI table"); return 1; }

        host_regs = map_phys(memfd, HOST_REGS_PHYS, HOST_REGS_MAP_SZ);
        if (host_regs == MAP_FAILED) { perror("[cfi] mmap host_regs"); return 1; }

        // mmap requires a page-aligned offset; map the full mbox page and
        // advance the pointer to mbox 1 (offset 1 * MBOX_STRIDE = 0x100).
        void *mbox_page = map_phys(memfd, CAR_MBOX_PHYS, CAR_MBOX_MAP_SZ);
        if (mbox_page == MAP_FAILED) { perror("[cfi] mmap mbox"); return 1; }
        mbox1 = (volatile uint32_t *)((char *)mbox_page + 1u * MBOX_STRIDE);
    }

    // -----------------------------------------------------------------------
    // 2. Fork + PTRACE_TRACEME
    // -----------------------------------------------------------------------
    pid_t pid = fork();
    if (pid < 0) { perror("[cfi] fork"); return 1; }

    if (pid == 0) {
        if (ptrace(PTRACE_TRACEME, 0, NULL, NULL) < 0) { perror("[cfi child] PTRACE_TRACEME"); _exit(1); }
        if (mlockall(MCL_CURRENT | MCL_FUTURE) < 0)    { perror("[cfi child] mlockall");       _exit(1); }
        execvp(argv[1], &argv[1]);
        perror("[cfi child] execvp"); _exit(1);
    }

    printf("[cfi] child pid=%d\n", (int)pid);

    int status;
    if (waitpid(pid, &status, 0) < 0) { perror("[cfi] waitpid"); return 1; }
    if (!WIFSTOPPED(status) || WSTOPSIG(status) != SIGTRAP) {
        fprintf(stderr, "[cfi] unexpected stop 0x%x\n", (unsigned)status);
        ptrace(PTRACE_KILL, pid, NULL, NULL); return 1;
    }
    printf("[cfi] child at entry point\n");

    // Enable syscall-stop reporting: SIGTRAP|0x80 on syscall entry and exit.
    if (ptrace(PTRACE_SETOPTIONS, pid, NULL,
               (void *)(PTRACE_O_TRACESYSGOOD |
                        PTRACE_O_TRACECLONE   |
                        PTRACE_O_TRACEFORK)) < 0) {
        perror("[cfi] PTRACE_SETOPTIONS"); return 1;
    }

    // -----------------------------------------------------------------------
    // 3. Build VA→PA table  (skipped in --no-ibex mode)
    // -----------------------------------------------------------------------
    if (!no_ibex && build_table(pid, tbl) != 0) {
        ptrace(PTRACE_KILL, pid, NULL, NULL); return 1;
    }

    // -----------------------------------------------------------------------
    // 4. Sync with Ibex: publish table, wait for snooper-armed ack
    // -----------------------------------------------------------------------
    if (!no_ibex) {
        host_regs[CFI_SCRATCH_IBEX_OFF     / 4] = 0u;
        host_regs[CFI_SCRATCH_LAUNCHER_OFF / 4] = 0u;
        host_regs[CFI_SCRATCH_RESULT_OFF   / 4] = 0u;
        __sync_synchronize();

        host_regs[CFI_SCRATCH_LAUNCHER_OFF / 4] = SYNC_TABLE_PUBLISHED;
        __sync_synchronize();
        printf("[cfi] waiting for Ibex snooper arm...\n");
        while (host_regs[CFI_SCRATCH_IBEX_OFF / 4] != SYNC_IBEX_CFI_READY)
            ;
        printf("[cfi] Ibex armed\n");
    }

    // -----------------------------------------------------------------------
    // 5. Release child with syscall tracing active
    // -----------------------------------------------------------------------
    struct timespec wall_t0, wall_t1;
    clock_gettime(CLOCK_MONOTONIC, &wall_t0);
    if (ptrace(PTRACE_SYSCALL, pid, NULL, NULL) < 0) {
        perror("[cfi] PTRACE_SYSCALL"); return 1;
    }

    // -----------------------------------------------------------------------
    // 6. Syscall interception loop
    // -----------------------------------------------------------------------
    uint32_t inspections = 0, violations = 0, bench_hits = 0;
    uint64_t lat_total_ns = 0, lat_min_ns = UINT64_MAX, lat_max_ns = 0;

    while (1) {
        pid_t stopped = waitpid(-1, &status, 0);
        if (stopped < 0) {
            if (errno == ECHILD) break;   // no more children
            perror("[cfi] waitpid loop"); break;
        }

        if (WIFEXITED(status) || WIFSIGNALED(status)) {
            if (stopped == pid) break;    // monitored process exited
            continue;
        }

        if (!WIFSTOPPED(status)) {
            ptrace(PTRACE_SYSCALL, stopped, NULL, NULL);
            continue;
        }

        int sig = WSTOPSIG(status);

        // PTRACE_O_TRACESYSGOOD sets bit 7 on the stop signal for syscall stops.
        if (sig == (SIGTRAP | 0x80)) {
            struct ptrace_syscall_info info;
            if (ptrace(PTRACE_GET_SYSCALL_INFO, stopped,
                       sizeof(info), &info) >= 0 &&
                info.op == PTRACE_SYSCALL_INFO_ENTRY) {
                uint64_t nr = info.entry.nr;
                int l1 = is_sensitive(nr);
                int l2 = strict && is_sensitive_strict(nr);
                if (l1 || l2) {
                    const char *tag = l1 ? "L1" : "L2";
                    if (bench) {
                        bench_hits++;   // count only — no Ibex, no print
                    } else if (no_ibex) {
                        inspections++;
                        printf("[cfi] syscall: %s (%llu) pid %d [%s]\n",
                               syscall_name(nr), (unsigned long long)nr,
                               (int)stopped, tag);
                    } else {
                        uint64_t lat_ns = 0;
                        uint32_t result = notify_ibex(host_regs, mbox1, nr, &lat_ns);
                        inspections++;
                        lat_total_ns += lat_ns;
                        if (lat_ns < lat_min_ns) lat_min_ns = lat_ns;
                        if (lat_ns > lat_max_ns) lat_max_ns = lat_ns;
                        if (result == CFI_RESULT_VIOLATION) {
                            fprintf(stderr,
                                    "[cfi] CFI VIOLATION: syscall %s (%llu) pid %d [%s] — killing\n",
                                    syscall_name(nr), (unsigned long long)nr,
                                    (int)stopped, tag);
                            violations++;
                            kill(stopped, SIGKILL);
                            waitpid(stopped, NULL, 0);
                            if (stopped == pid) goto done;
                            continue;
                        }
                    }
                }
            }
            // syscall-exit stops and non-sensitive entries fall through here
            ptrace(PTRACE_SYSCALL, stopped, NULL, NULL);
            continue;
        }

        // Clone/fork notification — attach tracing to new child
        if (status >> 8 == (SIGTRAP | (PTRACE_EVENT_CLONE << 8)) ||
            status >> 8 == (SIGTRAP | (PTRACE_EVENT_FORK  << 8))) {
            unsigned long new_pid = 0;
            ptrace(PTRACE_GETEVENTMSG, stopped, NULL, &new_pid);
            ptrace(PTRACE_SETOPTIONS, (pid_t)new_pid, NULL,
                   (void *)(PTRACE_O_TRACESYSGOOD |
                            PTRACE_O_TRACECLONE   |
                            PTRACE_O_TRACEFORK));
            ptrace(PTRACE_SYSCALL, (pid_t)new_pid, NULL, NULL);
            ptrace(PTRACE_SYSCALL, stopped, NULL, NULL);
            continue;
        }

        // Deliver other signals (SIGSEGV, SIGTERM, ...) unchanged.
        ptrace(PTRACE_SYSCALL, stopped, NULL, (void *)(uintptr_t)sig);
    }

done:
    clock_gettime(CLOCK_MONOTONIC, &wall_t1);
    {
        uint64_t wall_ns = (uint64_t)(wall_t1.tv_sec  - wall_t0.tv_sec)  * 1000000000ULL +
                           (uint64_t)(wall_t1.tv_nsec - wall_t0.tv_nsec);
        double   wall_ms = wall_ns / 1e6;

        if (bench) {
            printf("[cfi] bench: hits=%u wall=%.1f ms"
                   " (ptrace-only, no Ibex)\n",
                   bench_hits, wall_ms);
        } else if (no_ibex) {
            printf("[cfi] monitored process exited."
                   " syscalls_logged=%u wall=%.1f ms (no Ibex)\n",
                   inspections, wall_ms);
        } else {
            printf("[cfi] monitored process exited."
                   " inspections=%u violations=%u wall=%.1f ms\n",
                   inspections, violations, wall_ms);
            if (inspections > 0) {
                uint64_t lat_mean_ns = lat_total_ns / inspections;
                printf("[cfi] mbox round-trip latency (us):"
                       " mean=%.1f min=%.1f max=%.1f  ibex_total=%.1f ms\n",
                       lat_mean_ns / 1e3,
                       lat_min_ns  / 1e3,
                       lat_max_ns  / 1e3,
                       lat_total_ns / 1e6);
            }
        }
    }

    if (!no_ibex) {
        send_app_done(mbox1);
        // Keep scratch 12 protocol compatible with the original cfi_launcher
        // so the snooper can drain any remaining ring entries before exiting.
        host_regs[CFI_SCRATCH_LAUNCHER_OFF / 4] = SYNC_APP_DONE;
        __sync_synchronize();
    }

    return (violations > 0) ? 1 : 0;
}
