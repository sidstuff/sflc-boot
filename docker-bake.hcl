variable "DISTRO" {
  default = "ubuntu"
}
variable "RELEASE" {}
variable "FIRMWARE" {}
variable "KERNEL" {}
variable "CMDLINE" {}
variable "SHUFFLECAKE" {}
variable "SFLC_URL" {
  default = equal(SHUFFLECAKE,"") ? "https://codeberg.org/shufflecake/shufflecake-c/archive/main.tar.gz" : "https://codeberg.org/shufflecake/shufflecake-c/archive/v${SHUFFLECAKE}.tar.gz"
}

target "_common" {
  args = {
    distro = "${DISTRO}"
  }
  output = ["type=local,dest=images/"]
}

target "default" {
  inherits = ["_common"]
  args = {
    release = "${RELEASE}"
    firmware = "${FIRMWARE}"
  }
  entitlements = ["security.insecure"]
}

target "uki" {
  inherits = ["_common"]
  context = "uki/"
  args = {
    kernel = "${KERNEL}"
    cmdline = "${CMDLINE}"
    sflc_url = "${SFLC_URL}"
  }
}

target "ubuntu_all" {
  inherits = ["uki"]
  args = {
    distro = "ubuntu"
  }
  platforms = ["linux/amd64", "linux/arm64"]
}

target "gentoo_all" {
  inherits = ["uki"]
  args = {
    distro = "gentoo"
  }
  platforms = ["linux/amd64", "linux/arm64"]
}

target "archlinux_all" {
  inherits = ["uki"]
  args = {
    distro = "archlinux"
  }
  platforms = ["linux/amd64"]
}

group "all" {
  targets = ["ubuntu_all", "gentoo_all", "archlinux_all"]
}
