
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

# Profiling on Android

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

---

[rogcat]: https://github.com/flxo/rogcat
[android_ndk]: https://developer.android.com/ndk/downloads/index.html
[miniconda]: https://docs.conda.io/en/latest/miniconda.html
[simpleperf]: https://android.googlesource.com/platform/system/extras/+/master/simpleperf/doc/README.md
[simpleperf_android_profiling]: https://android.googlesource.com/platform/system/extras/+/master/simpleperf/doc/android_platform_profiling.md
[perfetto]: https://ui.perfetto.dev/#!/record
[inferno]: https://github.com/jonhoo/inferno