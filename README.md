# 🍰 sflc-boot

A custom initramfs to boot into a hidden OS on a Shufflecake-formatted partition.

* [📸 Screenshots](#-screenshots)
* [💻 Setup](#-setup)
  * [Initramfs](#initramfs)
  * [Hidden OS](#hidden-os)
* [💭 Prerequisites](#-prerequisites)
  * [Wait, what is Shufflecake?](#wait-what-is-shufflecake)
  * [Okay, what is plausible deniability in encryption?](#okay-what-is-plausible-deniability-in-encryption)
  * [But why should the OS itself be run from a hidden volume?](#but-why-should-the-os-itself-be-run-from-a-hidden-volume)

## 📸 Screenshots

```
Shufflecake v0.5.5 - Press Ctrl+C to drop to a rescue shell.

Name of the device to unlock: sda2
Password:

Here are the detected partitions:

major minor  #blocks  name
8           0   15232000 sda
8           1     524288 sda1
8           2    6291456 sda2
```
```
Shufflecake v0.5.5 - Device unlocked successfully.

Name of the device to mount as root: dm-1


Here are the detected partitions:

major minor  #blocks  name
8           0   15232000 sda
8           1     524288 sda1
8           2    6291456 sda2
253         0    6290432 dm-0
253         1    6290432 dm-1
```

## 💻 Setup

The setup scripts are designed to be run from an official live image of Arch Linux [[ISO]](https://geo.mirror.pkgbuild.com/iso/latest/archlinux-x86_64.iso) while connected to the internet. Like Arch Linux, the scripts currently only support the `x86_64` architecture.

Before proceeding, create the partitions that are to be set up as the EFI system partition (ESP) or with hidden OSes.

> [!NOTE]
> To create a simple GPT disk layout on some `/dev/sdX`, where the first 512MiB is the ESP and the remaining space is occupied by the partition to be formatted with Shufflecake, run
> ```sh
> sfdisk /dev/sdX << EOF
> label: gpt
> start=, size=512MiB, type="efi system"
> start=, size=, type="linux reserved"
> EOF
> ```

### Initramfs

Run [`esp-setup.sh`](https://raw.githubusercontent.com/sidstuff/sflc-boot/master/esp-setup.sh) as root with its first argument being the partition you want to setup as the ESP containing the Unified Kernel Image with the custom initramfs.
```sh
curl -fLO https://github.com/sidstuff/sflc-boot/raw/master/esp-setup.sh
sh esp-setup.sh /dev/sdXY
```
The UKI will be located at the standard path `𝘦𝘴𝘱/efi/boot/bootx64.efi`, so it can be booted directly from the UEFI menu. You can also use any bootloader of your choice.

> [!TIP]
> For use with Secure Boot, you can boot or `arch-chroot` into your [hidden OS](#hidden-os) once created, mount the ESP, and sign the UKI using `sbctl` (or use one of the other methods listed [here](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)).
> ```sh
> pacman -S sbctl
> # Make sure you booted with Secure Boot in Setup Mode
> sbctl status
> # Installed:	✘ Sbctl is not installed
> # Setup Mode:	✘ Enabled
> # Secure Boot:	✘ Disabled
> sbctl create-keys
> sbctl enroll-keys -m -f
> sbctl sign -s 𝘦𝘴𝘱/efi/boot/bootx64.efi
> ```

For those wanting a different setup, run `esp-setup.sh` without any arguments to simply output the `initramfs.cpio.gz` and `bootx64.efi` files in the current directory for further use. This can also be useful to test the generated initramfs with something like QEMU if modifying the script.
```sh
pacman -S qemu-base
qemu-system-x86_64 -enable-kvm -kernel /lib/modules/$(uname -r)/vmlinuz -initrd initramfs.cpio.gz -append "console=ttyS0" -cpu max -m 128M -nographic -serial mon:stdio -nodefaults # Press Ctrl+a x to quit
```

> [!NOTE]
> If you need a UKI with custom kernel `cmdline` parameters and a(n uncompressed) CPU microcode CPIO archive included, you can build one from the initramfs image using a command like
> ```sh
> ukify build --linux=/lib/modules/$(uname -r)/vmlinuz \
>             --initrd=cpu-ucode.img \
>             --initrd=initramfs.cpio.gz \
>             --cmdline="quiet rw"
> ```

### Hidden OS

If you already ran `esp-setup.sh`, it will also have created in the working directory the `shufflecake` binary and `dm-sflc.ko` module that you need to use Shufflecake (as well as the `busybox` binary, so it doesn't need to be rebuilt if re-running `esp-setup.sh` for any reason).

Otherwise, build Shufflecake:
```sh
mount -o remount,size=2G /run/archiso/cowspace
pacman -Sy git make gcc device-mapper libgcrypt
pacman -U https://archive.archlinux.org/packages/l/linux-headers/linux-headers-$(uname -r | sed 's/-/\./')-x86_64.pkg.tar.zst
git clone --depth 1 https://codeberg.org/shufflecake/shufflecake-c
cd shufflecake-c
make
```
Stay in the same directory and load the kernel module `dm-sflc.ko`.
```sh
insmod dm-sflc.ko
```
Now the commands to initialize and open Shufflecake volumes on a partition `/dev/sdXY` are simply
```sh
./shufflecake init /dev/sdXY
./shufflecake open /dev/sdXY
```
The volumes will be opened as some `/dev/mapper/sflc_M_N`.

Run [`root-setup.sh`](https://raw.githubusercontent.com/sidstuff/sflc-boot/master/root-setup.sh) as root with its first argument being whichever of these volumes you wish to setup an installation of Arch Linux in.
```sh
curl -fLO https://github.com/sidstuff/sflc-boot/raw/master/root-setup.sh
sh root-setup.sh /dev/mapper/sflc_M_N
```
It will be relatively barebones, but you can install more programs later.

Close all the Shufflecake volumes on the partition with
```sh
./shufflecake close /dev/sdXY
```

> [!TIP]
> If you later want to run `esp-setup.sh`, you can do so within the `shufflecake-c/` directory containing the `shufflecake` and `dm-sflc.ko` files to avoid rebuilding them.

## 💭 Prerequisites

### Wait, what is Shufflecake?

Shufflecake ([website](https://shufflecake.net/), [repo](https://codeberg.org/shufflecake/shufflecake-c)) is a disk encryption program for Linux — developed in 2022 as an EPFL master's thesis [[DOI]](https://doi.org/10.1145/3576915.3623126) project — that aims to provide plausible deniability.

### Okay, what is plausible deniability in encryption?

[Deniable encryption](https://en.wikipedia.org/wiki/Deniable_encryption) is similar to steganography — as long as the encrypted header and partition look like random bytes, you can claim that it's simply space that's been erased by overwriting it with random `0`s and `1`s. Even given that there exists some encrypted data, you can deny your ability to decrypt it by claiming to have lost or forgotten the key.

But when the partition in question is large and can be shown to have been used recently, neither of these defenses may be very convincing and could get you accused of destroying/hiding data. In jurisdictions that [mandate key disclosure](https://en.wikipedia.org/wiki/Key_disclosure_law), or in certain illegal cases of coercion ([xkcd](https://xkcd.com/538)), not providing any key at all can result in being labelled uncooperative and facing the legal or illegal consequences of that label.

Shufflecake tries to make the denial plausible by hiding, in the unused space of other volumes, further volumes that are encrypted and look like discarded random bytes. This allows the user to surrender a password that decrypts some (decoy) volumes, but not all — thus avoiding being seen as uncooperative while weakening the prosecution's claim to the arbitrary-sounding `"He provided a password that decrypted M volumes but maybe there are N volumes!!1!1!" 😠`

### But why should the OS itself be run from a hidden volume?

From the original paper [[PDF]](https://eprint.iacr.org/2023/1529.pdf):
> [...] the OS itelf (or other applications installed therein) can unintentionally leak to an adversary the presence of hidden data when a hidden volume is unlocked. This can happen for example through the OS logging disk events, search agents indexing files within the hidden volume when this is unlocked, even applications such as image galleries or document readers caching previews of opened documents. Customizing the OS’ behavior in such a way to avoid these pitfalls is an almost hopeless task.  A proposed solution to this problem is to have the OS itself inside a hidden volume.

To facilitate this, we create a custom initramfs image containing Shufflecake that can ask for a password and boot into such a hidden OS on start-up.

> [!IMPORTANT]
> For plausibility, the decoy OS(es) need to be kept up-to-date by regularly performing system updates, downloading emails, etc.
