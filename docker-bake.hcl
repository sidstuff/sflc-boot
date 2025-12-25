# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright © 2025 Sidharth Sankar

variable "DISTRO" {
  default = "ubuntu"
}
variable "RELEASE" {}
variable "KERNEL" {}
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
  entitlements = ["security.insecure"]
  args = {
    release = "${RELEASE}"
  }
}

target "initrd" {
  inherits = ["_common"]
  dockerfile = "initrd.Dockerfile"
  args = {
    kernel = "${KERNEL}"
    sflc_url = "${SFLC_URL}"
  }
}

target "writer" {
  dockerfile = "writer.Dockerfile"
  output = ["type=docker"]
  tags = ["writer"]
}
