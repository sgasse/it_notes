# Android Native Development

## Setup

For Android running on development boards, you can connect either via serial
ports or via USB. Connecting via USB is probably easier. Some packages may have
to be installed on your machine.

```sh
sudo apt install android-tools-adb libudev-dev picocom
```

To allow your user to make connections out of the machine, add it to the group
`dialout`:

```sh
# bash
sudo adduser $USER dialout

# nushell
sudo adduser $env.USER dialout
```

For some boards, you need a key (comparable to an SSH key) to connect to it. If
you are provided a key, place it at `~/.android/adbkey`.

## Connecting via USB and adb

`adb` allows us to open a shell on the target or just send commands to it. There
are some special commands (`remount`, `push`, `pull`, ...) which are subcommands
of `adb` and are not sent through the shell. Examples are given below.

```sh
# Open an interactive shell on the target
adb shell

# Send a command through the shell and return to the host shell prompt
adb shell ls -la /system/bin

# Remount file system in read/write mode (required after reboot on some devices)
adb remount

# Push data from the host to the target
adb push local/path/on/host /path/on/target/

# Pull data from the target to the host
adb pull /path/on/target ./

# See logstream of all buffers
adb logcat -b all

# See logstream from before the last reboot of all buffers
adb logcat -b all --last
```

A really useful program to filter the logstream and display the output with
color highlighting is [`rogcat`][rogcat]. If you have a Rust toolchain, installing is as
easy as `cargo install rogcat`.

## Connecting via serial port

This may be needed if you break something and can no longer connect through USB.
Note that you probably have to connect your USB cable to a different port on
your debugger board.

```sh
# Using device /dev/ttyUSB0 with baudrate 921600
picocom -b 921600 /dev/ttyUSB0

# Shell commands work as usual
ls -la /

# List commands with Ctrl+a followed by Ctrl+h
# Exit with Ctrl+a followed by Ctrl+x
```

## Cross-Compiling

For Rust code, the [`cross-rs`][cross-rs] binary can be used. This can be more
convenient than setting the target explicitly in the `Cargo.toml` and switching
back and forth. Install it with

```sh
cargo install cross
```

Then you can run cross builds, tests etc. with:

```sh
# Build
cross build --target aarch64-linux-android

# Test
cross test --target aarch64-linux-android
```

# Profiling on Android

- A good resource on profiling Rust code is the
  [Rust Performance Book][rust_perf_book].

When profiling on Linux, there are a few security settings that can prevent us
from recording proper traces. The following commands will set less secure but
more useful settings until the next reboot:

```sh
sudo sysctl -w kernel.perf_event_paranoid=-1
sudo sysctl -w kernel.kptr_restrict=0
```

## `perf`

The Linux kernel comes with the tool `perf` which can record a lot of kernel,
CPU and memory events. A great collection of commands can be found in
[Brendan Gregg's article][perf_commands].

Record and report all systemcalls which carry "open" in their name:

```sh
sudo perf record -e syscalls:*open* --call-graph=dwarf ./target/debug/syscall_profiling
sudo perf report --stdio
```

## [`simpleperf`][simpleperf]

This is a profiler specifically tailored to Android. It is open-source and ships
with the Android Native Development Kit (NDK).
The best way to install it is downloading a pre-built version and extracting it.
The bundle includes `simpleperf` binaries to record profiling data for Linux and
Android. While those binaries can be used directly, there are some convenience
scripts in python which bundle pushing the `simpleperf` binary to an Android
device, running the recording and pulling the recorded data back to the host.
The scripts require python >=3.9, `report_html.py` specifically throws an error
on python 3.8 which is default on Ubuntu 20.04. If you want to avoid messing up
your ststem python, it is a good idea to install `miniconda` or any other
userspace python installation.

### Install

Download [Android NDK][android_ndk] and extract

Install [miniconda][miniconda] (required on Ubuntu 20.04)

Update PATH variable to run the `simpleperf` scripts from different directories

```sh
# bash
export PATH="$HOME/miniconda3/bin:$PATH:~/android-ndk-r25c/simpleperf"

# nushell
let-env PATH = ($env.HOME + "/miniconda3/bin" | append $env.PATH | append ($env.HOME + "/android-ndk-r25c/simpleperf"))
```

### Recording and Analysis

Examples can be found [here][simpleperf_android_profiling]

Record native process using the python script

```sh
app_profiler.py -np <native_proc_name> -r "-g --duration 10"
```

Manually record data

```sh
# Push simpleperf build to android
adb push <ndk_home>/simpleperf/bin/android/arm64/simpleperf /data/local/tmp/

# Record data of process with ID 269 for 10s to `/data/local/tmp/perf.data`
adb shell ./data/local/tmp/simpleperf record -o /data/local/tmp/perf.data -g --duration 10 --log info -p 269

# Pull data file
adb pull /data/local/tmp/perf.data ./
```

Monitor and display default performance events

```sh
./simpleperf stat -p 252 --duration 10

# Output
Performance counter statistics:

#         count  event_name         # count / runtime
      8,164,350  cpu-cycles         # 0.516182 GHz
      1,724,878  instructions       # 109.054 M/sec
         47,766  branch-misses      # 3.020 M/sec
  14.512600(ms)  task-clock         # 0.001452 cpus used
            285  context-switches   # 19.638 K/sec
              0  page-faults        # 0.000 /sec

Total test time: 9.998047 seconds.
```

Monitor and display specific performance counter statistics

```sh
./simpleperf stat -p 252 -e \
  cache-references,cache-references:u,cache-references:k,cache-misses,cache-misses:u,cache-misses:k,instructions \
  --duration 1

# Output
Performance counter statistics:

#  count  event_name           # count / runtime
  57,276  cache-references     # 39.939 M/sec
  15,146  cache-references:u   # 9.692 M/sec
  42,864  cache-references:k   # 27.428 M/sec
   3,208  cache-misses         # 2.053 M/sec
   1,131  cache-misses:u       # 723.701 K/sec
   2,077  cache-misses:k       # 1.329 M/sec
  26,282  instructions         # 84.075 M/sec

Total test time: 1.001186 seconds.
```

Generate a report

```sh
report_html.py
```

## [Perfetto][perfetto]

Perfetto comes with both profilers and an [interactive UI][perfetto_ui] (served
only via Chrome).
With `perfetto`, we can visualize a rich timeline of CPU clocks & utilization,
systemcalls, scheduling events etc. interactively in the browser.

Profiling configurations and commands can be created in the
interactive UI. For modern Android versions, the remove devices can directly be
accessed from the UI, so you can run profiling right from Chrome. For older
Android devices though (e.g. 9), the commands have to be executed manually on
the device. Most Android devices have `perfetto` preinstalled.

To profile a desktop linux, you need to build `perfetto` following
[these instructions][perfetto_build_linux]. An example configuration is given
further down this file.

Record a trace for perfetto on Linux with a custom configuration:

```sh
sudo ./out/linux/tracebox -o linux_desktop.perfetto-trace --txt -c ./custom_linux.cfg
```

## [`inferno`][inferno]

`inferno` comes both as library and as binary. It provide functionality to
convert data collected with `perf` to beautiful flamegraphs. The
[`cargo flamegraph`][cargo_flamegraph] subcommand uses `inferno` under the hood.
Thanks to this subcommand, creating flamegraphs from Rust applications is really
convenient on the local system. For Android targets, `inferno` can still be used
to convert the data recorded with `perf` to flamegraphs.

For Ubuntu, install these dependencies:

```sh
# bash
sudo apt install linux-tools-common linux-tools-generic $"linux-tools-(uname -r)"

# nushell
sudo apt install linux-tools-common linux-tools-generic linux-tools-`uname -r`
```

To ensure that the complete call stack can be translated into function calls,
add this to your `Cargo.toml`:

```toml
[profile.release]
debug = true
```

Then you can run this command to profile `heavy_app`, and take a look at the
flamegraph:

```sh
# Profile in release mode
cargo flamegraph --bin heavy_app

# Profile in debug mode
cargo flamegraph --bin heavy_app --dev

# Pass `perf` options
cargo flamegraph -c "record -e branch-misses -c 100 -g"

# The interactive SVGs are best opened in a browser
firefox flamegraph.svg
```

---

# Appendix

### Perfetto Config for Linux Desktop

```
buffers: {
    size_kb: 522240
    fill_policy: DISCARD
}
buffers: {
    size_kb: 2048
    fill_policy: DISCARD
}
data_sources: {
    config {
        name: "linux.process_stats"
        target_buffer: 1
        process_stats_config {
            scan_all_processes_on_start: true
            proc_stats_poll_ms: 1000
        }
    }
}
data_sources: {
    config {
        name: "linux.sys_stats"
        sys_stats_config {
            meminfo_period_ms: 1000
            stat_period_ms: 500
            stat_counters: STAT_CPU_TIMES
            stat_counters: STAT_FORK_COUNT
            cpufreq_period_ms: 1000
        }
    }
}
data_sources: {
    config {
        name: "android.heapprofd"
        target_buffer: 0
        heapprofd_config {
            sampling_interval_bytes: 4096
            continuous_dump_config {
                dump_phase_ms: 1000
                dump_interval_ms: 10000
            }
            shmem_size_bytes: 8388608
            block_client: true
        }
    }
}
data_sources: {
    config {
        name: "linux.ftrace"
        ftrace_config {
            ftrace_events: "sched_switch"
            ftrace_events: "suspend_resume"
            ftrace_events: "sched_wakeup"
            ftrace_events: "sched_wakeup_new"
            ftrace_events: "sched_waking"
            ftrace_events: "cpu_frequency"
            ftrace_events: "cpu_idle"
            ftrace_events: "sys_enter"
            ftrace_events: "sys_exit"
            ftrace_events: "regulator_set_voltage"
            ftrace_events: "regulator_set_voltage_complete"
            ftrace_events: "clock_enable"
            ftrace_events: "clock_disable"
            ftrace_events: "clock_set_rate"
            ftrace_events: "sched_process_exit"
            ftrace_events: "sched_process_free"
            ftrace_events: "task_newtask"
            ftrace_events: "task_rename"
        }
    }
}
duration_ms: 10000
```

[android_ndk]: https://developer.android.com/ndk/downloads/index.html
[cargo_flamegraph]: https://github.com/flamegraph-rs/flamegraph
[cross-rs]: https://github.com/cross-rs/cross
[inferno]: https://github.com/jonhoo/inferno
[miniconda]: https://docs.conda.io/en/latest/miniconda.html
[perf_commands]: https://www.brendangregg.com/perf.html
[perfetto_build_linux]: https://perfetto.dev/docs/quickstart/linux-tracing
[perfetto_ui]: https://ui.perfetto.dev/
[perfetto]: https://ui.perfetto.dev/#!/record
[rogcat]: https://github.com/flxo/rogcat
[rust_perf_book]: https://nnethercote.github.io/perf-book/profiling.html
[simpleperf_android_profiling]: https://android.googlesource.com/platform/system/extras/+/master/simpleperf/doc/android_platform_profiling.md
[simpleperf]: https://android.googlesource.com/platform/system/extras/+/master/simpleperf/doc/README.md
