# Encrypted setup of Ubuntu 22.10 with btrfs

## Backgrund

For a while now, I am a big fan of `btrfs` for its features such as instant
snapshots due to copy-on-write, incremental backups and the possibility to roll
back the whole system by moving a few snapshots.

So far, I never had a laptop stolen, but the thought of someone going through my
complete data is not a nice one. Therefore, I like to have my laptop encrypted.
I have used "real" full-disk-encryption for more than a year, which involves
even having `/boot` on the encrypted device and using `grub` to decrypt the
disk that holds it. However this has two drawbacks from my perspective:

- **The boot time increases significantly.** At least on the two machines where
  I set it up (and one of them was a beefed-up workhorse), the time from typing
  the password for the encryption until seeing the login prompt was too long.
  This made me never shut down my machine but always keeping it in sleep, which
  introduces unnecessary wear and makes the laptop susceptible to other attacks
  again.
- If you mistype the password, you need to force-restart the machine. This is
  OK in comparison. But the time from pressing enter until you know that you
  mistyped can be something like 10s.

While I know that it is somewhat less secure to have `/boot` not encrypted
(hello rootkits etc.), I deem it sufficient for my current situation. These
notes are loosely based on the
[excellent guide by Willi Mutschler][mutschler-guide] about
full-disk-encryption.

[mutschler-guide]: https://mutschler.dev/linux/ubuntu-btrfs-20-04/

## Partition Architecture

At the end, we need four partitions for this installation. Note that they can
be installed side-to-side with other OSes. I still have a Windows installation
that came with the laptop which I boot every 2 years for some Windows-only
stuff.

Here is my partitioning scheme:

- `/dev/nvme0n1p5`: 512 MiB EFI system partition (`fat32`)
- `/dev/nvme0n1p6`: 512 MiB `/boot` partition (`ext4`)
- `/dev/nvme0n1p7`: ~893 GiB encrypted LUKS drive (`LUKS` / `btrfs`)
- `/dev/nvme0n1p8`: 512 MiB swap (as alibi for the system)

As mentioned by Willi Mutschler, the Ubuntu installer does not handle the
creation of `btrfs` on the encrypted device well, so we should partition
everything by hand.

I personally like to edit/create partitions with `gparted` because it allows me
to revise my plan graphically before potentially causing data loss, but it works
equally well with CLI tools.

In Willi's guide, he mentions an optional part on editing some setup files to
have `NVMe`-friendly mount options. While this is useful, I prefer to edit
the `/etc/fstab` after the installation. Also, in Ubuntu 22.10, we have to use
the option `space_cache=v2` instead of `space_cache`. See also
[this issue][space_cache_issue]

[space_cache_issue]: https://github.com/btrfs/btrfs-todo/issues/29

Let's create the encrypted LUKS drive. Since we do **not** need `grub` to
decrypt it, we can use `luks2` (the default).

```bash
cryptsetup luksFormat /dev/nvme0n1p7

WARNING!
========
This will overwrite data on /dev/nvme0n1p7 irrevocably.

Are you sure? (Type 'yes' in capital letters): YES
Enter passphrase for /dev/nvme0n1p7:
Verify passphrase:
```

Open the encrypted device:

```bash
cryptsetup luksOpen /dev/nvme0n1p7 cryptdata
Enter passphrase for /dev/nvme0n1p7:
```

Manually format the decrypted volume as `btrfs`:

```bash
mkfs.btrfs /dev/mapper/cryptdata
btrfs-progs v5.19
See http://btrfs.wiki.kernel.org for more information.

NOTE: several default settings have changed in version 5.15, please make sure
      this does not affect your deployments:
      - DUP for metadata (-m dup)
      - enabled no-holes (-O no-holes)
      - enabled free-space-tree (-R free-space-tree)

Label:              (null)
UUID:               <...>
Node size:          16384
Sector size:        4096
Filesystem size:    893.71GiB
Block group profiles:
  Data:             single            8.00MiB
  Metadata:         DUP               1.00GiB
  System:           DUP               8.00MiB
SSD detected:       yes
Zoned device:       no
Incompat features:  extref, skinny-metadata, no-holes
Runtime features:   free-space-tree
Checksum:           crc32c
Number of devices:  1
Devices:
   ID        SIZE  PATH
    1   893.71GiB  /dev/mapper/cryptdata
```

Format the designated EFI system partition to avoid issues with the installer:

```bash
mkfs.fat -F32 /dev/nvme0n1p5
```

Launch the installer:

```bash
ubiquity
```

## Installation steps

- We choose "Something else" in the dialog where we are asked if the complete
  disk shall be erased to install Ubuntu.
- Select disks:
  - Select the decrypted volume inside the LUKS wrapper and choose "Use as
    btrfs", mount point `/`.
  - Select the designated EFI partition and choose "Use as EFI system
    partition".
  - Select the designated boot partition and choose "Use as ext4", mount point
    `/boot`.
  - Select the swap partition and choose "Use as swap".
- When the installation is done, click on "Continue testing" and do not reboot
  the machine.
  - Should you have rebooted, then you can still boot into the installation
    again with the live system and do the post-install steps - so not everything
    is lost. But it is annoying.

## Post-install steps

Mount the Ubuntu system root (which is on a subvolume, **not** the btrfs root).
Note that we use the option `space_cache=v2`. Just using `space_cache` makes the
system fall back to `v1` and not being able to mount.

```bash
mount -o subvol=@,ssd,noatime,space_cache=v2,commit=120,compress=zstd /dev/mapper/cryptdata /mnt
```

Prepare a chroot environment and switch into it:

```bash
for i in /dev /dev/pts /proc /sys /run; do sudo mount -B $i /mnt$i; done
sudo cp /etc/resolv.conf /mnt/etc/
sudo chroot /mnt
```

Let's list what we have mounted:

```bash
mount -av

/                        : ignored
mount: (hint) your fstab has been modified, but systemd still uses
       the old version; use 'systemctl daemon-reload' to reload.
/boot                    : successfully mounted
/boot/efi                : successfully mounted
/home                    : successfully mounted
none                     : ignored
```

Now, we will write the `crypttab`. This is a crucial step to get a graphical
prompt for the encryption password later on. We also add the swap to the
crypttab with a random password.

```bash
export UUID3=$(blkid -s UUID -o value /dev/nvme0n1p7)
echo "cryptdata UUID=${UUID3} none luks" >> /etc/crypttab

export SWAPUUID=$(blkid -s UUID -o value /dev/nvme0n1p8)
echo "cryptswap UUID=${SWAPUUID} /dev/urandom swap,offset=1024,cipher=aes-xts-plain64,size=512" >> /etc/crypttab
```

This is how the crypttab should look like:

```bash
cat /etc/crypttab

cryptdata UUID=... none luks
cryptswap UUID=... /dev/urandom swap,offset=1024,cipher=aes-xts-plain64,size=512
```

Now, we need to adjust also the `/etc/fstab`:

```bash
sed -i "s|UUID=${SWAPUUID}|/dev/mapper/cryptswap|" /etc/fstab
```

This is how the `/etc/fstab` should look like after the edit:

```bash
cat /etc/fstab

# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/mapper/cryptdata /               btrfs   defaults,subvol=@ 0       1
# /boot was on /dev/nvme0n1p6 during installation
UUID=... /boot           ext4    defaults        0       2
# /boot/efi was on /dev/nvme0n1p1 during installation
UUID=...  /boot/efi       vfat    umask=0077      0       1
/dev/mapper/cryptdata /home           btrfs   defaults,subvol=@home 0       2
# swap was on /dev/nvme0n1p8 during installation
/dev/mapper/cryptswap none            swap    sw              0       0
```

Now we manually adjust the entries of the `btrfs` volumes. Basically, we add
options (remember `space_cache=v2`) and set the filesystem check to zero that
makes no sense for `btrfs`. After the edit, the `/etc/fstab` should look like
this:

```bash
cat /etc/fstab

# /etc/fstab: static file system information.
#
# Use 'blkid' to print the universally unique identifier for a
# device; this may be used with UUID= as a more robust way to name devices
# that works even if disks are added and removed. See fstab(5).
#
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
/dev/mapper/cryptdata /               btrfs   defaults,subvol=@,ssd,noatime,space_cache=v2,commit=120,compress=zstd 0       0
# /boot was on /dev/nvme0n1p6 during installation
UUID=... /boot           ext4    defaults        0       2
# /boot/efi was on /dev/nvme0n1p1 during installation
UUID=...  /boot/efi       vfat    umask=0077      0       1
/dev/mapper/cryptdata /home           btrfs   defaults,subvol=@home,ssd,noatime,space_cache=v2,commit=120,compress=zstd 0       0
# swap was on /dev/nvme0n1p8 during installation
/dev/mapper/cryptswap none            swap    sw              0       0
```

After adjusting the crypttab, we need to update the initramfs. Run the following
command for it:

```bash
update-initramfs -u -k all

update-initramfs: Generating /boot/initrd.img-5.19.0-23-generic
update-initramfs: Generating /boot/initrd.img-5.19.0-21-generic
```

Now we can reboot. If everything worked out, we should see a graphical prompt
for the encryption password.

## Appendix: After the reboot

This is a list of things to setup after reinstalling a system, more of a
reminder to myself.

- Audacity
- calibre
- docker
- docker-compose
- easytag
- FileZilla
- Firefox
- fzf
- GIMP
- KeepassXC
- Peek
- replaygain
- Rust
- Shotwell
- Signal
- Slack
- syncthing
- Terminator
- TexMaker
- Timeshift
- Transmission
- VLC
- VS Code
- Wireshark
- Xournal++
- ZSH

TODOs:

- Create subvolumes for `.cargo` and `.cargo_target_dir` to avoid having build
  artifacts in `btrfs` snapshots.
- Sync over configuration from `.config`
- Sync over SSH keys from `.ssh`
- Sync over the ZSH/BASH history
- Restore a recent snapshot of `/home` from a backup `btrfs` file system to the
  freshly installed laptop. Copy data with e.g.
  `cp -r --reflink=always Media ~/`
