{
    "name" : "mips1_pg",
    "hardware" : [
        "mips1_pg"
    ],
    "endian" : "EB",
    "toolchain" :
    {
        "envvars" : [
            "MIPSPATH",
            "PROCBENCHDIR"
        ],
        "as" : "$(MIPSPATH)/bin/mips-unknown-linux-uclibc-as",
        "gcc" : "$(MIPSPATH)/bin/mips-unknown-linux-uclibc-gcc",
        "ld" : "$(MIPSPATH)/bin/mips-unknown-linux-uclibc-ld",
        "ar" : "$(MIPSPATH)/bin/mips-unknown-linux-uclibc-ar",
        "nm" : "$(MIPSPATH)/bin/mips-unknown-linux-uclibc-nm",
        "objdump" : "$(MIPSPATH)/bin/mips-unknown-linux-uclibc-objdump",
        "objcopy" : "$(MIPSPATH)/bin/mips-unknown-linux-uclibc-objcopy",

        "cflags" : [
            "-static",
            "-march=mips1",
            "-mabi=32",
            "-msoft-float",
            "-mllsc",
            "-mplt",
            "-mips1",
            "-mno-shared",
            "-EB",
			"-g"
        ],
        "asflags" : [
            "-EB",
            "-mips1",
            "-O2",
            "-mabi=32",
            "-march=mips1",
            "-mno-shared",
            "-msoft-float"
        ],
        "ldflags" : [
            "--sysroot=$(MIPSPATH)/mips-unknown-linux-uclibc/sysroot",
            "-EB",
            "-mips1",
            "-static",
            "-melf32btsmip",
            "--start-group",
            "-lgcc",
            "-lgcc_eh",
            "-lc",
            "--end-group"
        ],
        "incpaths" : [
            "$(MIPSPATH)/lib/gcc/mips-unknown-linux-uclibc/6.2.0/include",
            "$(MIPSPATH)/lib/gcc/mips-unknown-linux-uclibc/6.2.0/include-fixed",
            "$(MIPSPATH)/mips-unknown-linux-uclibc/include",
            "$(MIPSPATH)/mips-unknown-linux-uclibc/sysroot/usr/include"
        ],
        "libpaths" : [
            "$(MIPSPATH)/lib/gcc/mips-unknown-linux-uclibc/6.2.0",
            "$(MIPSPATH)/mips-unknown-linux-uclibc/lib",
            "$(MIPSPATH)/mips-unknown-linux-uclibc/sysroot/lib",
            "$(MIPSPATH)/mips-unknown-linux-uclibc/sysroot/usr/lib"
        ],

        "bootasmsrc" : [
            "$(PROCBENCHDIR)/crt_mips_uclibc/boot.S"
        ],
        "bootcsrc" : [
            "$(PROCBENCHDIR)/crt_libc_common/syscall.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_exit.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_read.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_write.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_open.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_close.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_brk.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_lseek.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_ioctl.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_fstat.c",
            "$(PROCBENCHDIR)/crt_libc_common/sys_dup2.c"
        ],

        "crt" : "$(MIPSPATH)/mips-unknown-linux-uclibc/sysroot/usr/lib/crt1.o",
        "crti" : "$(MIPSPATH)/mips-unknown-linux-uclibc/sysroot/usr/lib/crti.o $(MIPSPATH)/lib/gcc/mips-unknown-linux-uclibc/6.2.0/crtbeginT.o",
        "crtn" : "$(MIPSPATH)/lib/gcc/mips-unknown-linux-uclibc/6.2.0/crtend.o $(MIPSPATH)/mips-unknown-linux-uclibc/sysroot/usr/lib/crtn.o",
        "lscript" : "$(PROCBENCHDIR)/crt_mips_uclibc/lscript.ld",

        "options" : [
            "PROCBENCH",
            "HEAP_BASE"
        ]
    }
}
