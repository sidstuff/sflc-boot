# 🍰 sflc-boot

A custom unified kernel image to boot into a hidden OS on a Shufflecake-formatted partition.

* [📸 Screenshots](#-screenshots)
* [💻 Usage](#-usage)
  * [Unified Kernel Image](#unified-kernel-image)
  * [Hidden OS](#hidden-os)
  * [Testing](#testing)
* [💭 Prerequisites](#-prerequisites)
  * [Wait, what is Shufflecake?](#wait-what-is-shufflecake)
  * [Okay, what is plausible deniability in encryption?](#okay-what-is-plausible-deniability-in-encryption)
  * [But why should the OS itself be run from a hidden volume?](#but-why-should-the-os-itself-be-run-from-a-hidden-volume)

## 📸 Screenshots

```
Shufflecake v0.5.6 - Press Ctrl+C to drop to a rescue shell.

Name of the device to unlock: sda2
Password:

Here are the detected partitions:

major minor  #blocks  name
8           0   15232000 sda
8           1     524288 sda1
8           2    6291456 sda2
```
```
Shufflecake v0.5.6 - Device unlocked successfully.

Name of the device to mount as root: dm-1


Here are the detected partitions:

major minor  #blocks  name
8           0   15232000 sda
8           1     524288 sda1
8           2    6291456 sda2
253         0    6290432 dm-0
253         1    6290432 dm-1
```

## 💻 Usage

Check if a satisfactory build is available on the [Releases](https://github.com/sidstuff/sflc-boot/releases) page. Otherwise, to create one yourself, ensure you have Docker available within an existing Linux installation, as well as QEMU if trying to build for a different CPU architecture.
```sh
# Use your package manager to install Docker - package names may vary
apt install docker.io docker-buildx # on Ubuntu 25.04 𝘱𝘭𝘶𝘤𝘬𝘺
docker run --privileged --rm tonistiigi/binfmt --install all # to install QEMU
docker buildx create --bootstrap --use --buildkitd-flags '--allow-insecure-entitlement security.insecure'
docker buildx inspect | grep "Platforms" # check the platforms supprted by Docker
# Platforms: linux/amd64, linux/amd64/v2, linux/amd64/v3, linux/386, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/mips64le, linux/mips64, linux/loong64, linux/arm/v7, linux/arm/v6
```
Only use platforms that your target distro (supported values are `ubuntu`, `gentoo`, and `archlinux`) also has a prebuilt kernel of the desired version for. Check its repo to confirm:

| [Ubuntu](https://kernel.ubuntu.com/mainline) | [Gentoo](https://dev.gentoo.org/~mgorny/binpkg) | [Arch Linux](https://archive.archlinux.org/packages/l/linux) |
|--|--|--|

> [!NOTE]
> You may need Linux modules and/or headers, in which case you can boot or `arch-chroot` into your [hidden OS](#hidden-os) once created, and install the required version from the above repositories. For example, on Arch Linux:
> ```sh
> wget https://archive.archlinux.org/packages/l/linux/linux-6.18.1.arch1-2-x86_64.pkg.tar.zst \
>      https://archive.archlinux.org/packages/l/linux-headers/linux-headers-6.18.1.arch1-2-x86_64.pkg.tar.zst
> # Use -dd to avoid installing the initramfs as a dependency
> pacman -Udd linux-6.18.1.arch1-1-x86_64.pkg.tar.zst
> pacman -U linux-headers-6.18.1.arch1-1-x86_64.pkg.tar.zst
> ```

To run Docker commands as a regular user, log in once again after adding the user to the `docker` group.
```sh
sudo usermod -aG docker $USER
logout
```
Before moving on to the next section, also create the partitions that are to be set up as the EFI system partition (ESP) or with hidden OSes.

> [!TIP]
> To create a simple GPT layout on some disk `/dev/sdX`, where the first 512MiB is the ESP and the remaining space is occupied by the partition to be formatted with Shufflecake, run
> ```sh
> sfdisk /dev/sdX << EOF
> label: gpt
> start=, size=512MiB, type="efi system"
> start=, size=, type="linux reserved"
> EOF
> ```

Now, clone the repo and `cd` into it.
```sh
git clone https://github.com/sidstuff/sflc-boot
cd sflc-boot
```

### Unified Kernel Image

Download any of the prebuilt UKIs available on the [Releases](https://github.com/sidstuff/sflc-boot/releases) page
```sh
wget -P images/ https://github.com/sidstuff/sflc-boot/releases/latest/download/0.5.6-shufflecake-6.14.10-ubuntu-linux-amd64.efi
```
or use Docker Bake to build one with your chosen kernel and Shufflecake versions (the latest if unspecified).
```sh
DISTRO="ubuntu" KERNEL="6.14.10" SHUFFLECAKE="0.5.6" docker buildx bake --set *.platform=amd64 uki
```
Then setup any partition `/dev/sdX𝘠` as an ESP, writing the UKI to it.
```
sudo ./write-uki.sh images/0.5.6-shufflecake-6.14.10-ubuntu-linux-amd64.efi /dev/sdX𝘠
```
It will be placed at the standard path `/efi/boot/bootx64.efi` within, so it can be booted directly from the UEFI menu (or any bootloader of your choice).

> [!NOTE]
> For use with Secure Boot, you can boot or `arch-chroot` into your [hidden OS](#hidden-os) once created, mount the ESP, and sign the UKI using `sbctl`.
> ```sh
> # Make sure you booted with Secure Boot in Setup Mode
> sbctl status
> # Installed:	✘ Sbctl is not installed
> # Setup Mode:	✘ Enabled
> # Secure Boot:	✘ Disabled
> sbctl create-keys
> sbctl enroll-keys -m -f
> sbctl sign -s 𝘦𝘴𝘱/efi/boot/bootx64.efi
> ```

### Hidden OS

Before proceeding, use Shufflecake to create and open the hidden volumes that are to contain OSes. Expand the collapsed section for instructions.

<details>

<summary>&nbsp;<b>Volume Creation</b></summary><br>

First, build Shufflecake.
```sh
# Use your package manager to install deps - exact names may vary
sudo apt install git gcc make libgcrypt-dev libdevmapper-dev linux-headers-$(uname -r)
git clone --depth 1 https://codeberg.org/shufflecake/shufflecake-c
cd shufflecake-c && make
```
Stay in the same directory and (after ensuring its dependency `dm_mod` is loaded), insert the module `dm-sflc.ko` into the running kernel.
```sh
sudo modprobe dm_mod
sudo insmod dm-sflc.ko
```
Now you can `init`, `open`, and finally `close`, some Shufflecake volumes `/dev/mapper/sflc_𝘔_𝘕`  on a partition `/dev/sdX𝘠` via
```sh
sudo ./shufflecake 𝘢𝘤𝘵𝘪𝘰𝘯 /dev/sdX𝘠
```

</details>

**OS Install**

To output the latest rootfs tarball image of your target OS to `images/`, run a command within the cloned directory like
```sh
DISTRO="ubuntu" RELEASE="noble" docker buildx bake --allow security.insecure --set *.platform=amd64
```
or download one from the [Releases](https://github.com/sidstuff/sflc-boot/releases) page if a recent build exists.
```
wget -P images/ https://github.com/sidstuff/sflc-boot/releases/latest/download/ubuntu-noble-rootfs-amd64.tar.xz
```
Then setup any of the Shufflecake volumes `/dev/mapper/sflc_𝘔_𝘕` as root devices with your desired filesystem, unpacking the earlier tarball into them.
```sh
sudo ./write-rootfs.sh --fs=ext4 images/ubuntu-noble-rootfs-amd64.tar.xz /dev/mapper/sflc_{𝘮..𝘔}_{𝘯..𝘕}
```
The created OS will be relatively barebones, but you can install more programs once you boot into it.

### Testing

Use QEMU to test `sflc-boot` without actually writing to and booting off a pen drive. Within the cloned directory:
```sh
CMDLINE="console=ttyS0" DISTRO="ubuntu" KERNEL="6.14.10" SHUFFLECAKE="0.5.6" \
docker buildx bake --set *.platform=amd64 uki
mkdir -p esp/efi/boot disk
cp images/0.5.6-shufflecake-6.14.10-ubuntu-linux-amd64.efi esp/efi/boot/bootx64.efi

FIRMWARE="no" DISTRO="ubuntu" RELEASE="24.04.3" \
docker buildx bake --allow security.insecure --set *.platform=amd64
dd if=/dev/zero of=disk.img bs=1M count=4000 conv=fsync
sudo ./write-rootfs.sh --fs=ext4 images/ubuntu-24.04.3-rootfs-amd64.tar.xz disk.img

# Use your package manager to install QEMU - package name may vary
sudo apt install qemu-system
qemu-img create root.img 4G
qemu-system-x86_64 -m 2G -cpu base -nodefaults -nographic -serial mon:stdio \
                   -bios /usr/share/ovmf/OVMF.fd \
                   -drive format=raw,file=fat:rw:esp/ \
                   -drive format=raw,file=disk.img,if=none,cache=writeback,id=stick1 \
                   -drive format=raw,file=root.img,if=none,cache=writeback,id=stick2 \
                   -device qemu-xhci \
                   -device usb-storage,drive=stick1 \
                   -device usb-storage,drive=stick2 # Press Ctrl+a x to quit
```
Within the new environment, press Ctrl+C to enter the busybox shell, then create the hidden OS on the virtual USB drive using the following commands.
```sh
cat /proc/partitions
# major minor  #blocks  name
#    8        0    4194304 sda
#    8       16    4096000 sdb
printf "o\nn\np\n1\n\n\nw\n" | fdisk /dev/sda
shufflecake init /dev/sda1
shufflecake open /dev/sda1
dd if=/dev/sdb of=/dev/dm-0 bs=1M conv=fsync
shufflecake close /dev/sda1
```
Then quit QEMU by pressing `Ctrl+a` `x` and (after optionally deleting the no longer necessary files) rerun QEMU.
```sh
rm -rf images/ disk*
qemu-system-x86_64 -m 2G -cpu base -nodefaults -nographic -serial mon:stdio \
                   -bios /usr/share/ovmf/OVMF.fd \
                   -drive format=raw,file=fat:rw:esp/ \
                   -drive format=raw,file=root.img,if=none,cache=writeback,id=stick \
                   -device qemu-xhci \
                   -device usb-storage,drive=stick # Press Ctrl+a x to quit
```

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

To facilitate this, we create a custom unified kernel image containing Shufflecake that can ask for a password and boot into such a hidden OS on start-up.

> [!IMPORTANT]
> For plausibility, the decoy OS(es) need to be kept up-to-date by regularly performing system updates, downloading emails, etc.
