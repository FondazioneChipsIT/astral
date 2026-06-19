// Copyright 2026 Fondazione Chips-IT.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// cfi_launcher.c — Linux userspace CFI launcher (CVA6 side)
//
// Usage
// -----
//   sudo ./cfi_launcher <application> [args...]
//
// What it does
// ------------
//  1. fork() + PTRACE_TRACEME: forks the monitored application and uses
//     ptrace to stop the child at its entry point (just before _start runs)
//     after the kernel has loaded all ELF segments and dynamic libraries.
//
//  2. Reads /proc/<child>/maps to find all executable VMAs and
//     /proc/<child>/pagemap to read the physical page frame number (PFN)
//     of every code page.  Contiguous PFN runs are coalesced into segments.
//
//  3. Writes the resulting cfi_va_pa_table_t into CFI_TABLE_PHYS_BASE via
//     /dev/mem.  Ibex firmware can read it directly at that physical address.
//
//  4. Signals Ibex via HOST scratch register 12 (SYNC_TABLE_PUBLISHED).
//     Spins on scratch register 13 until Ibex replies SYNC_IBEX_CFI_READY,
//     meaning the snooper has been armed with the correct VA range.
//
//  5. Releases the child (PTRACE_CONT).  The snooper is now active and
//     will log branches as the application runs.
//
//  6. After the child exits, writes SYNC_APP_DONE to scratch 12.
//
// Requirements
// ------------
//  - Run as root (CAP_SYS_RAWIO + CAP_SYS_PTRACE + CAP_IPC_LOCK).
//  - Kernel with /dev/mem access: CONFIG_STRICT_DEVMEM=n or
//    CONFIG_DEVMEM_IS_OF_CONCERN=n (common on embedded kernels).
//  - /proc/self/pagemap PFN access requires kernel < 4.0 OR root.
//
// Limitations (first prototype)
// ------------------------------
//  - The child calls mlockall(MCL_CURRENT|MCL_FUTURE) before exec, preventing
//    page migration and swap-out for the lifetime of the monitored process.
//    For even stronger guarantees (huge pages, NUMA pinning) consider a
//    CMA-backed contiguous mapping instead.
//  - dlopen() after startup will add new VMAs that are NOT in the table.
//    Extend by sending a SIGSTOP to the child, rebuilding, and reissuing
//    SYNC_TABLE_PUBLISHED.
//  - 32-bit physical addresses only (PA[63:32] assumed 0).

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
#include <time.h>

// The shared table definition is compiled on the Linux side too;
// the guard #ifndef __linux__ in cfi_va_pa_table.h skips the Ibex helper.
#include "cfi_va_pa_table.h"

// ---------------------------------------------------------------------------
// Platform constants
// ---------------------------------------------------------------------------
#define HOST_REGS_PHYS    0x03000000u
#define HOST_REGS_MAP_SZ  0x1000u

// ---------------------------------------------------------------------------
// vma_is_kernel_special — returns 1 if the VMA name is a kernel-managed
// special region that should NOT be included in the CFI table.
// These include [vdso], [vdso_data], [vsyscall] etc.
// Including them would extend the snooper range to cover nearly all of
// userspace (vDSO is mapped near the top of the 39-bit VA space, at ~0x3f...).
// ---------------------------------------------------------------------------
static int vma_is_kernel_special(const char *maps_line) {
    // Find the optional path/name field (last whitespace-separated token).
    const char *p = strrchr(maps_line, ' ');
    if (!p) p = strrchr(maps_line, '\t');
    if (!p) return 0;
    // Skip whitespace
    while (*p == ' ' || *p == '\t') p++;
    // Kernel special VMAs are enclosed in brackets: [vdso], [stack], etc.
    if (*p == '[') {
        // Only skip vDSO and vsyscall — we still want to track [heap] if
        // somehow it becomes executable, but in practice filter all [...].
        // To be safe, skip everything that starts with '[v' (vdso, vsyscall)
        // and leave others (stack, heap) — they won't be r-xp anyway.
        if (strncmp(p, "[vdso",  5) == 0) return 1;
        if (strncmp(p, "[vsys",  5) == 0) return 1;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// map_phys — map a physical region into userspace via /dev/mem
// ---------------------------------------------------------------------------
static void *map_phys(int memfd, uint32_t phys, size_t sz) {
    void *p = mmap(NULL, sz, PROT_READ | PROT_WRITE, MAP_SHARED,
                   memfd, (off_t)phys);
    return p;   // caller checks against MAP_FAILED
}

/* Optional pagemap debug dump file descriptor.  When >=0, every pagemap
 * read is logged to /tmp/cfi_pagemap_<pid>.txt so the user can inspect
 * the raw pagemap entries after the launcher exits (useful when no
 * separate terminal is available on the target).
 */
static int pagemap_log_fd = -1;
static int maps_log_fd = -1;

static void log_maps_line(const char *line) {
    if (maps_log_fd < 0)
        return;
    size_t l = strlen(line);
    write(maps_log_fd, line, l);
}

static void log_pagemap_entry(uintptr_t va, uint64_t entry) {
    if (pagemap_log_fd < 0)
        return;
    char buf[256];
    int n = 0;
    if (entry == 0) {
        n = snprintf(buf, sizeof(buf), "va=0x%016lx entry=0x%016llx\n",
                     (unsigned long)va, (unsigned long long)entry);
    } else {
        uint64_t present = (entry >> 63) & 1ULL;
        uint64_t pfn = entry & ((1ULL << 55) - 1);
        uint64_t pa = pfn * (uint64_t)CFI_PAGE_SIZE;
        n = snprintf(buf, sizeof(buf),
                     "va=0x%016lx entry=0x%016llx present=%llu pfn=0x%llx pa=0x%llx\n",
                     (unsigned long)va, (unsigned long long)entry,
                     (unsigned long long)present,
                     (unsigned long long)pfn,
                     (unsigned long long)pa);
    }
    if (n > 0)
        write(pagemap_log_fd, buf, (size_t)n);
}

// ---------------------------------------------------------------------------
// read_pfn — return the page frame number for virtual address va inside
//            the process identified by pagemap_fd.
//            Returns 0 if the page is not present or on read error.
// ---------------------------------------------------------------------------
static uint64_t read_pfn(int pagemap_fd, uintptr_t va) {
    uint64_t entry = 0;
    off_t off = (off_t)((va / CFI_PAGE_SIZE) * sizeof(uint64_t));
    ssize_t r = pread(pagemap_fd, &entry, sizeof(entry), off);
    if (r != (ssize_t)sizeof(entry)) {
        if (r < 0)
            perror("[cfi] pagemap pread");
        /* Log a zero entry for visibility */
        log_pagemap_entry(va, (uint64_t)0);
        return 0;
    }

    /* Log the raw 64-bit pagemap entry for debugging */
    log_pagemap_entry(va, entry);
    if (!(entry & (1ULL << 63)))   // bit 63: page present
        return 0;
    return entry & ((1ULL << 55) - 1);  // bits [54:0]: PFN
}

// ---------------------------------------------------------------------------
// build_table — populate *tbl from /proc/<pid>/maps + /proc/<pid>/pagemap.
//
// Only executable VMAs (permission string has 'x') are included.
// Physically contiguous page runs within each VMA are coalesced.
// ---------------------------------------------------------------------------
// fault_in_page — force a single page into physical memory by reading one
// byte from /proc/<pid>/mem.  The child must be stopped (ptrace) for this
// to work.  Returns 0 on success, -1 if the read failed (page unreadable).
static int fault_in_page(int mem_fd, uintptr_t va) {
    char dummy;
    ssize_t r = pread(mem_fd, &dummy, 1, (off_t)va);
    if (r < 1) {
        /* Not necessarily fatal — some pages (guard pages etc.) are
         * legitimately unreadable.  Log and continue. */
        fprintf(stderr, "[cfi] fault_in_page: pread va=0x%lx failed: %s\n",
                (unsigned long)va, strerror(errno));
        return -1;
    }
    return 0;
}

static int build_table(pid_t pid, cfi_va_pa_table_t *tbl) {
    char path[64];

    /* Open /proc/<pid>/mem so we can fault pages in before reading pagemap.
     * The child must be stopped via ptrace for pread() on mem to work.
     * Without this, pages that were never accessed have bit 63 = 0 in
     * pagemap (demand paging: VMA exists but no physical page allocated
     * yet) and we would wrongly skip them. */
    snprintf(path, sizeof(path), "/proc/%d/mem", (int)pid);
    int mem_fd = open(path, O_RDONLY);
    if (mem_fd < 0) {
        perror("[cfi] open /proc/<pid>/mem");
        fprintf(stderr, "[cfi] (hint: launcher must be the ptrace parent)\n");
        return -1;
    }

    snprintf(path, sizeof(path), "/proc/%d/pagemap", (int)pid);
    int pagemap_fd = open(path, O_RDONLY);
    if (pagemap_fd < 0) {
        perror("[cfi] open pagemap");
        close(mem_fd);
        return -1;
    }

    /* Open a pagemap dump file so the launcher can write raw pagemap entries
     * for offline inspection. This is useful when you cannot attach another
     * terminal on the target (FPGA). The file is written to /tmp and named
     * cfi_pagemap_<pid>.txt. Failure to open is non-fatal.
     */
    char dump_path[128];
    snprintf(dump_path, sizeof(dump_path), "/tmp/cfi_pagemap_%d.txt", (int)pid);
    pagemap_log_fd = open(dump_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (pagemap_log_fd >= 0) {
        char hdr[128];
        int hn = snprintf(hdr, sizeof(hdr), "pagemap dump for pid %d\n", (int)pid);
        if (hn > 0) write(pagemap_log_fd, hdr, (size_t)hn);
    }

    /* Also open a maps dump file for the child's /proc/<pid>/maps output */
    char maps_dump_path[128];
    snprintf(maps_dump_path, sizeof(maps_dump_path), "/tmp/cfi_maps_%d.txt", (int)pid);
    maps_log_fd = open(maps_dump_path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (maps_log_fd >= 0) {
        char mhdr[128];
        int mhn = snprintf(mhdr, sizeof(mhdr), "maps dump for pid %d\n", (int)pid);
        if (mhn > 0) write(maps_log_fd, mhdr, (size_t)mhn);
    }

    snprintf(path, sizeof(path), "/proc/%d/maps", (int)pid);
    FILE *maps = fopen(path, "r");
    if (!maps) {
        perror("[cfi] fopen maps");
        close(pagemap_fd);
        return -1;
    }

    memset(tbl, 0, sizeof(*tbl));
    tbl->magic             = CFI_TABLE_MAGIC;
    tbl->num_segs          = 0;
    // Initialise range to inverted extremes (64-bit).
    tbl->va_range_start_l  = 0xFFFFFFFFu;
    tbl->va_range_start_h  = 0xFFFFFFFFu;
    tbl->va_range_end_l    = 0x00000000u;
    tbl->va_range_end_h    = 0x00000000u;

    char line[512];
    while (fgets(line, sizeof(line), maps)) {
        uintptr_t va_start = 0, va_end = 0;
        char perms[8] = {0};

        // Format: start-end perms offset dev ino [path]
        if (sscanf(line, "%lx-%lx %7s", &va_start, &va_end, perms) < 3)
            continue;

        // Skip non-executable VMAs — we only need code pages.
        if (perms[2] != 'x') {
            log_maps_line(line);
            continue;
        }

        // Skip kernel-managed special VMAs (vDSO, vsyscall).
        // Including vDSO would extend the snooper range to cover the entire
        // 39-bit VA space, producing spurious hits and potentially overflowing
        // the snooper range registers on Ibex.
        if (vma_is_kernel_special(line)) {
            printf("[cfi]   VMA 0x%lx-0x%lx %s  [skipped: kernel special]\n",
                   va_start, va_end, perms);
            log_maps_line(line);
            continue;
        }

        printf("[cfi]   VMA 0x%lx-0x%lx %s\n", va_start, va_end, perms);
        /* also log the VMA line to the maps dump */
        log_maps_line(line);

        /* Fault in every page in this VMA before reading pagemap.
         * The child is stopped at its entry point (SIGTRAP after exec),
         * so no page has been demand-faulted yet — pagemap would return
         * all zeros without this step. */
        {
            unsigned int faulted = 0, failed = 0;
            for (uintptr_t fva = va_start; fva < va_end; fva += CFI_PAGE_SIZE) {
                if (fault_in_page(mem_fd, fva) == 0)
                    faulted++;
                else
                    failed++;
            }
            printf("[cfi]     faulted %u pages, %u unreadable\n", faulted, failed);
        }

        // Walk pages, coalescing physically contiguous runs into segments.
        uintptr_t va = va_start;
        while (va < va_end && tbl->num_segs < CFI_MAX_SEGS) {
            uint64_t pfn = read_pfn(pagemap_fd, va);
            if (pfn == 0) {
                // Page not present yet (lazy allocation); skip.
                va += CFI_PAGE_SIZE;
                continue;
            }

            // Start of a new contiguous run.
            uintptr_t seg_va  = va;
            uint64_t  seg_pfn = pfn;
            uint32_t  n       = 0;

            while (va < va_end) {
                uint64_t p = read_pfn(pagemap_fd, va);
                if (p != seg_pfn + n)
                    break;
                n++;
                va += CFI_PAGE_SIZE;
            }

            cfi_segment_t *s = &tbl->seg[tbl->num_segs++];
            s->va_base_l = (uint32_t)(seg_va & 0xFFFFFFFFUL);
            s->va_base_h = (uint32_t)((seg_va >> 32) & 0xFFFFFFFFUL);
            s->pa_base   = (uint32_t)(seg_pfn * CFI_PAGE_SIZE);
            s->num_pages = n;

            printf("[cfi]     seg[%u]: VA=0x%08x_%08x PA=0x%08x pages=%u\n",
                   (unsigned)(tbl->num_segs - 1),
                   s->va_base_h, s->va_base_l, s->pa_base, s->num_pages);

            /* Log segment info to maps dump for easy cross-checking */
            if (maps_log_fd >= 0) {
                char sbuf[256];
                int sn = snprintf(sbuf, sizeof(sbuf),
                                  "seg[%u]: VA=0x%08x_%08x PA=0x%08x pages=%u\n",
                                  (unsigned)(tbl->num_segs - 1),
                                  s->va_base_h, s->va_base_l, s->pa_base, s->num_pages);
                if (sn > 0) write(maps_log_fd, sbuf, (size_t)sn);
            }

            // Update 64-bit VA range (compare as full uintptr_t).
            uintptr_t seg_va_full  = seg_va;
            uintptr_t seg_end_full = seg_va + (uintptr_t)n * CFI_PAGE_SIZE;
            uintptr_t cur_start    = ((uintptr_t)tbl->va_range_start_h << 32) |
                                      tbl->va_range_start_l;
            uintptr_t cur_end      = ((uintptr_t)tbl->va_range_end_h   << 32) |
                                      tbl->va_range_end_l;
            if (seg_va_full  < cur_start) {
                tbl->va_range_start_l = (uint32_t)(seg_va_full  & 0xFFFFFFFFUL);
                tbl->va_range_start_h = (uint32_t)(seg_va_full  >> 32);
            }
            if (seg_end_full > cur_end) {
                tbl->va_range_end_l   = (uint32_t)(seg_end_full & 0xFFFFFFFFUL);
                tbl->va_range_end_h   = (uint32_t)(seg_end_full >> 32);
            }
        }

        if (tbl->num_segs >= CFI_MAX_SEGS) {
            fprintf(stderr, "[cfi] WARNING: hit CFI_MAX_SEGS=%u limit; "
                    "remaining VMAs skipped\n", (unsigned)CFI_MAX_SEGS);
            break;
        }
    }

    fclose(maps);
    if (maps_log_fd >= 0)
        close(maps_log_fd);
    if (pagemap_log_fd >= 0)
        close(pagemap_log_fd);
    close(pagemap_fd);
    close(mem_fd);

    if (tbl->num_segs == 0) {
        fprintf(stderr, "[cfi] ERROR: no executable pages found\n");
        return -1;
    }

    printf("[cfi] Table complete: %u segs, VA=[0x%08x_%08x, 0x%08x_%08x)\n",
           (unsigned)tbl->num_segs,
           tbl->va_range_start_h, tbl->va_range_start_l,
           tbl->va_range_end_h,   tbl->va_range_end_l);

    /* Dump the final table to /tmp for offline inspection */
    {
        char tpath[128];
        snprintf(tpath, sizeof(tpath), "/tmp/cfi_table_%d.txt", (int)pid);
        int tfd = open(tpath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (tfd >= 0) {
            char hbuf[256];
            int hn = snprintf(hbuf, sizeof(hbuf), "CFI table for pid %d: %u segs\n",
                              (int)pid, (unsigned)tbl->num_segs);
            if (hn > 0) write(tfd, hbuf, (size_t)hn);
            for (uint32_t i = 0; i < tbl->num_segs; i++) {
                cfi_segment_t *s = &tbl->seg[i];
                char lbuf[256];
                int ln = snprintf(lbuf, sizeof(lbuf),
                                  "seg[%u] VA=0x%08x_%08x PA=0x%08x pages=%u\n",
                                  (unsigned)i, s->va_base_h, s->va_base_l,
                                  s->pa_base, s->num_pages);
                if (ln > 0) write(tfd, lbuf, (size_t)ln);
            }
            close(tfd);
        }
    }

    // Write the ready sentinel last.  The compiler barrier + the store itself
    // acts as the visibility fence between the segment writes above and the
    // sentinel.  Ibex polls tbl->ready before trusting any other field.
    __sync_synchronize();
    tbl->ready = CFI_TABLE_READY_MAGIC;
    return 0;
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
int main(int argc, char *argv[]) {
    // Parse optional --no-ibex flag (skip Ibex sync — useful for CVA6-only
    // testing when no snooper_fetch_linux firmware is loaded on Ibex).
    int no_ibex = 0;
    if (argc >= 2 && strcmp(argv[1], "--no-ibex") == 0) {
        no_ibex = 1;
        argv++;
        argc--;
    }

    if (argc < 2) {
        fprintf(stderr, "Usage: %s [--no-ibex] <application> [args...]\n", argv[0]);
        fprintf(stderr, "  --no-ibex  skip Ibex sync (test CVA6 side only)\n");
        return 1;
    }

    // -----------------------------------------------------------------------
    // 1. Open /dev/mem and map the two physical regions we need:
    //    - CFI table buffer (written to Ibex)
    //    - Cheshire HOST scratch registers (signaling channel)
    // -----------------------------------------------------------------------
    int memfd = open("/dev/mem", O_RDWR | O_SYNC);
    if (memfd < 0) {
        perror("[cfi] open /dev/mem");
        fprintf(stderr, "  (hint: run as root and ensure CONFIG_STRICT_DEVMEM=n)\n");
        return 1;
    }

    cfi_va_pa_table_t *tbl = map_phys(memfd, CFI_TABLE_PHYS_BASE,
                                       CFI_TABLE_PHYS_SIZE);
    if (tbl == MAP_FAILED) {
        perror("[cfi] mmap CFI table");
        return 1;
    }

    volatile uint32_t *host_regs = map_phys(memfd, HOST_REGS_PHYS,
                                            HOST_REGS_MAP_SZ);
    if (host_regs == MAP_FAILED) {
        perror("[cfi] mmap host_regs");
        return 1;
    }

    // -----------------------------------------------------------------------
    // 2. Fork the monitored application.
    //
    //    Child:  calls PTRACE_TRACEME then execvp.  The kernel delivers a
    //            SIGTRAP to the parent after exec, stopping the child at its
    //            entry point with all ELF segments already mapped.
    //    Parent: waits for that stop, builds the table, then PTRACE_CONTs.
    // -----------------------------------------------------------------------
    pid_t pid = fork();
    if (pid < 0) {
        perror("[cfi] fork");
        return 1;
    }

    if (pid == 0) {
        // --- Child ---
        if (ptrace(PTRACE_TRACEME, 0, NULL, NULL) < 0) {
            perror("[cfi child] PTRACE_TRACEME");
            _exit(1);
        }
        // Lock all current and future pages before exec so that no code page
        // can migrate or be swapped out between build_table() and steady-state
        // execution.  Requires CAP_IPC_LOCK (already required by the launcher).
        if (mlockall(MCL_CURRENT | MCL_FUTURE) < 0) {
            perror("[cfi child] mlockall");
            _exit(1);
        }
        execvp(argv[1], &argv[1]);
        perror("[cfi child] execvp");
        _exit(1);
    }

    // --- Parent ---
    printf("[cfi] Launched child pid=%d, waiting for entry-point stop...\n",
           (int)pid);

    int status;
    if (waitpid(pid, &status, 0) < 0) {
        perror("[cfi] waitpid");
        return 1;
    }

    // After PTRACE_TRACEME + exec, the kernel stops the child with SIGTRAP.
    if (!WIFSTOPPED(status) || WSTOPSIG(status) != SIGTRAP) {
        fprintf(stderr, "[cfi] unexpected child stop status 0x%x\n",
                (unsigned)status);
        ptrace(PTRACE_KILL, pid, NULL, NULL);
        return 1;
    }

    printf("[cfi] Child stopped at entry point (all segments loaded).\n");

    // -----------------------------------------------------------------------
    // 3. Build the VA→PA table from the child's address space.
    // -----------------------------------------------------------------------
    if (build_table(pid, tbl) != 0) {
        ptrace(PTRACE_KILL, pid, NULL, NULL);
        return 1;
    }

    // -----------------------------------------------------------------------
    // 4. Signal Ibex and wait for snooper-armed acknowledgement.
    // -----------------------------------------------------------------------
    if (no_ibex) {
        printf("[cfi] --no-ibex: skipping Ibex sync, releasing application now.\n");
    } else {
        // Clear both scratch registers before starting: stale values from a
        // previous run would cause Ibex to skip the table-ready handshake and
        // read a partially-written (corrupted) table.
        host_regs[CFI_SCRATCH_IBEX_OFF    / 4] = 0u;
        host_regs[CFI_SCRATCH_LAUNCHER_OFF / 4] = 0u;
        __sync_synchronize();
        host_regs[CFI_SCRATCH_LAUNCHER_OFF / 4] = SYNC_TABLE_PUBLISHED;
        __sync_synchronize();

        printf("[cfi] Notified Ibex (SYNC_TABLE_PUBLISHED). "
               "Waiting for snooper to arm...\n");

        while (host_regs[CFI_SCRATCH_IBEX_OFF / 4] != SYNC_IBEX_CFI_READY)
            ;

        printf("[cfi] Ibex armed. Releasing application.\n");
    }

    // -----------------------------------------------------------------------
    // 5. Release the child — it continues from _start.
    // -----------------------------------------------------------------------
    struct timespec ts_app_start, ts_app_end;
    if (ptrace(PTRACE_CONT, pid, NULL, NULL) < 0) {
        perror("[cfi] PTRACE_CONT");
        return 1;
    }
    clock_gettime(CLOCK_MONOTONIC, &ts_app_start);

    // -----------------------------------------------------------------------
    // 6. Wait for the application to finish.
    // -----------------------------------------------------------------------
    waitpid(pid, &status, 0);
    clock_gettime(CLOCK_MONOTONIC, &ts_app_end);
    int rc = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    long app_ns = (ts_app_end.tv_sec  - ts_app_start.tv_sec)  * 1000000000L
                + (ts_app_end.tv_nsec - ts_app_start.tv_nsec);
    printf("[cfi] Application exited with code %d. wall_time=%ld ms\n",
           rc, app_ns / 1000000L);

    // Signal Ibex that the run is over (it can stop draining the ring).
    if (!no_ibex) {
        host_regs[CFI_SCRATCH_LAUNCHER_OFF / 4] = SYNC_APP_DONE;
        __sync_synchronize();
    }

    return rc;
}
