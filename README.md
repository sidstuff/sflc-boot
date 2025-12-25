# 🍰 sflc-boot

A Dracut module to boot into hidden OSes on a Shufflecake-formatted partition, as well as Dockerfiles to install supporting OSes based on various distros.

<details>

<summary>&nbsp;<b>💭 About Shufflecake</b></summary><br>

* **What is Shufflecake?**

Shufflecake ([website](https://shufflecake.net/), [repo](https://codeberg.org/shufflecake/shufflecake-c)) is a disk encryption program for Linux — developed in 2022 as an EPFL master's thesis [[DOI]](https://doi.org/10.1145/3576915.3623126) project — that aims to provide plausible deniability.

* **What is plausible deniability in encryption?**

[Deniable encryption](https://en.wikipedia.org/wiki/Deniable_encryption) is similar to steganography — as long as the encrypted header and partition look like random bytes, you can claim that it's simply space that's been erased by overwriting it with random `0`s and `1`s. Even given that there exists some encrypted data, you can deny your ability to decrypt it by claiming to have lost or forgotten the key.

But when the partition in question is large and can be shown to have been used recently, neither of these defenses may be very convincing and could get you accused of destroying/hiding data. In jurisdictions that [mandate key disclosure](https://en.wikipedia.org/wiki/Key_disclosure_law), or in certain illegal cases of coercion ([xkcd](https://xkcd.com/538)), not providing any key at all can result in being labelled uncooperative and facing the legal or illegal consequences of that label.

Shufflecake tries to make the denial plausible by hiding, in the unused space of other volumes, further volumes that are encrypted and look like discarded random bytes. This allows the user to surrender a password that decrypts some (decoy) volumes, but not all — thus avoiding being seen as uncooperative while weakening the prosecution's claim to the arbitrary-sounding `"He provided a password that decrypted M volumes but maybe there are N volumes!!1!1!" 😠`

* **Why should the OS itself be run from a hidden volume?**

From the original paper [[PDF]](https://eprint.iacr.org/2023/1529.pdf):
> [...] the OS itelf (or other applications installed therein) can unintentionally leak to an adversary the presence of hidden data when a hidden volume is unlocked. This can happen for example through the OS logging disk events, search agents indexing files within the hidden volume when this is unlocked, even applications such as image galleries or document readers caching previews of opened documents. Customizing the OS’ behavior in such a way to avoid these pitfalls is an almost hopeless task.  A proposed solution to this problem is to have the OS itself inside a hidden volume.

To facilitate this, we create a custom initramfs containing Shufflecake that can ask for a password and boot into such a hidden OS on start-up.

</details>

> [!IMPORTANT]
> For plausibility, the decoy OSes need to be kept up-to-date by regularly performing system updates, downloading emails, etc.

## 💻 Usage

Within an existing Linux installation, ensure you have Docker available (with support for QEMU if trying to build for a different CPU architecture).
```sh
# Use your package manager to install Docker - package name(s) may vary
sudo apt install docker.io docker-buildx # on Debian 𝘧𝘰𝘳𝘬𝘺
sudo usermod -aG docker $USER # add user to the docker group
exec sudo -s -u $USER # refresh groups
docker run --privileged --rm tonistiigi/binfmt --install all # to install QEMU
docker buildx create --bootstrap --use --buildkitd-flags '--allow-insecure-entitlement security.insecure' # insecure flag needed for chroot and mount operations
docker buildx inspect | grep "Platforms" # check the platforms supprted by Docker
# Platforms: linux/amd64, linux/amd64/v2, linux/amd64/v3, linux/386, linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/mips64le, linux/mips64, linux/loong64, linux/arm/v7, linux/arm/v6
```

Create any of the partitions that are to be set up as the EFI system partition (ESP) or with hidden OSes, that don't already exist.
> [!TIP]
> To create a simple GPT layout on some disk `/dev/sd𝘟`, where the first 512MiB is the ESP and the remaining space is occupied by the partition to be formatted with Shufflecake, run
> ```sh
> sfdisk /dev/sd𝘟 << EOF
> label: gpt
> start=, size=512MiB, type="efi system"
> start=, size=, type="linux reserved"
> EOF
> ```

Now use Shufflecake to create and open the hidden volumes that are to contain OSes. Expand the collapsed section for instructions.

<details>

<summary>&nbsp;<b>💾 Volume Creation</b></summary><br>

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
Now you can `init`, `open`, and finally `close`, some Shufflecake volumes `/dev/mapper/sflc_𝘔_𝘕`  on a partition `/dev/sd𝘟𝘠` via
```sh
sudo ./shufflecake 𝘢𝘤𝘵𝘪𝘰𝘯 /dev/sd𝘟𝘠
```

</details>

Finally, build and install the OS.
```sh
git clone https://github.com/sidstuff/sflc-boot
cd sflc-boot
DISTRO="ubuntu" RELEASE="questing" \
docker buildx bake --set *.platform=amd64 --allow security.insecure
docker buildx bake writer
docker run --rm --privileged -v $PWD:$PWD writer $PWD/images/amd64-ubuntu-questing-esp.iso /dev/𝘌𝘚𝘗
docker run --rm --privileged -v $PWD:$PWD writer $PWD/images/amd64-ubuntu-questing-rootfs.tar.xz --fs=ext4 /dev/mapper/sflc_{𝘮..𝘔}_{𝘯..𝘕}
```
The created OSes will be relatively barebones, but you can install more programs once you boot into it.

<details>

<summary>&nbsp;<b>🧑‍💻 Testing</b></summary><br>

For testing during development, you can build just the initrd, as well as specify any kernel version that is prebuilt by your distro for the target architecture.
```sh
DISTRO="ubuntu" KERNEL="6.18.1" SHUFFLECAKE="0.5.6" \
docker buildx bake --set *.platform=amd64 initrd
```
Check the repos for available kernels:
| [Ubuntu](https://kernel.ubuntu.com/mainline) | [Gentoo](https://dev.gentoo.org/~mgorny/binpkg) | [Arch Linux](https://archive.archlinux.org/packages/l/linux) |
|--|--|--|

Also create a Linux disk image.
```
wget https://cdimage.ubuntu.com/ubuntu-base/daily/current/resolute-base-amd64.tar.gz
fallocate -l 100M disk.img
docker buildx bake writer
docker run --rm --privileged -v $PWD:$PWD writer $PWD/resolute-base-amd64.tar.gz $PWD/disk.img
```

Then use QEMU to test `sflc-boot` without actually writing to and booting off a pen drive.
```
# Use your package manager to install QEMU - package name may vary
sudo apt install qemu-system
qemu-img create root.img 128M
qemu-system-x86_64 -m 512M -cpu qemu64 \
                   -bios /usr/share/ovmf/OVMF.fd \
                   -kernel images/amd64-ubuntu-6.18.1-061801-generic-kernel.img \
                   -initrd images/amd64-ubuntu-6.18.1-061801-generic-initrd.img \
                   -append "rd.break=pre-mount" \
                   -drive format=raw,file=disk.img,if=none,cache=writeback,id=stick1 \
                   -drive format=raw,file=root.img,if=none,cache=writeback,id=stick2 \
                   -device qemu-xhci \
                   -device usb-storage,drive=stick1 \
                   -device usb-storage,drive=stick2
```
```
cat /proc/partitions
# major minor  #blocks  name
#    8        0     131072 sda
#    8       16     102400 sdb
shufflecake init /dev/sda
shufflecake open /dev/sda
cat /dev/sdb > /dev/dm-0
shufflecake close /dev/sda
```
Then quit QEMU and (after optionally deleting the no longer necessary files) rerun it.
```sh
rm resolute-base-amd64.tar.gz disk.img
qemu-system-x86_64 -m 512M -cpu qemu64 \
                   -bios /usr/share/ovmf/OVMF.fd \
                   -kernel images/amd64-ubuntu-6.18.1-061801-generic-kernel.img \
                   -initrd images/amd64-ubuntu-6.18.1-061801-generic-initrd.img \
                   -append "quiet splash" \
                   -drive format=raw,file=root.img,if=none,cache=writeback,id=stick \
                   -device qemu-xhci \
                   -device usb-storage,drive=stick
```

</details>
