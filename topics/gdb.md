# `gdb`

## Debug Python syscalls

- Install `libc6-dbg` to get the debug symbols in Ubuntu.
- Launch `gdb` for `python` as for any other program: `gdb python`.
- Set a breakpoint and confirm if asked to set a breakpoint on a future shared
  library load, e.g. `break __libc_sendmsg` or `break sendmsg`.
- Run a `python` program with `run my_python_program.py`
- Inspect variable content by dereferencing a pointer, e.g. `p *msg`.
- Extract memory from an address, e.g. with `x/24xb 0x7ffff7676710` where
  `24` is the number of units, `x` for hex formatting and `b` is bytes as unit.

Example session:

```gdb
gdb python
GNU gdb (Ubuntu 9.2-0ubuntu1~20.04.1) 9.2
Copyright (C) 2020 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Type "show copying" and "show warranty" for details.
This GDB was configured as "x86_64-linux-gnu".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
    <http://www.gnu.org/software/gdb/documentation/>.

For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from python...
(gdb) break __libc_sendmsg
Function "__libc_sendmsg" not defined.
Make breakpoint pending on future shared library load? (y or [n]) y
Breakpoint 1 (__libc_sendmsg) pending.
(gdb) run send_with_hop_limit.py
Starting program: /home/simon-gasse/miniconda3/bin/python send_with_hop_limit.py
[Thread debugging using libthread_db enabled]
Using host libthread_db library "/lib/x86_64-linux-gnu/libthread_db.so.1".

Breakpoint 1, __libc_sendmsg (fd=3, msg=0x7fffffffd028, flags=0) at ../sysdeps/unix/sysv/linux/sendmsg.c:26
26      ../sysdeps/unix/sysv/linux/sendmsg.c: No such file or directory.
(gdb) p *msg
$1 = {msg_name = 0x7fffffffd060, msg_namelen = 28, msg_iov = 0x7ffff76004f0, msg_iovlen = 1, msg_control = 0x7ffff7676710,
  msg_controllen = 24, msg_flags = 0}
(gdb) x/24xb 0x7ffff7676710
0x7ffff7676710: 0x14    0x00    0x00    0x00    0x00    0x00    0x00    0x00
0x7ffff7676718: 0x29    0x00    0x00    0x00    0x34    0x00    0x00    0x00
0x7ffff7676720: 0xff    0xff    0xff    0xff    0x00    0x00    0x00    0x00
```
