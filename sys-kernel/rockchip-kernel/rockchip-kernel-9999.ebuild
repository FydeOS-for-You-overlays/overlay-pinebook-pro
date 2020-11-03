# Copyright 2019 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_PROJECT="chromiumos/third_party/kernel"
CROS_WORKON_LOCALNAME="kernel/rockchip-kernel"
CROS_WORKON_EGIT_BRANCH="release-4.4.190-cros"

# This must be inherited *after* EGIT/CROS_WORKON variables defined
inherit cros-workon cros-kernel2

HOMEPAGE="https://www.chromium.org/chromium-os/chromiumos-design-docs/chromium-os-kernel"
DESCRIPTION="Chrome OS Linux Kernel 5.4"
KEYWORDS="~*"

# Change the following (commented out) number to the next prime number
# when you change "cros-kernel2.eclass" to work around http://crbug.com/220902
#
# NOTE: There's nothing magic keeping this number prime but you just need to
# make _any_ change to this file.  ...so why not keep it prime?
#
# Don't forget to update the comment in _all_ chromeos-kernel-x_x-9999.ebuild
# files (!!!)
#
# The coolest prime number is: 149

src_install() {
  cros-kernel2_src_install
  local kernel_dir=$(cros-workon_get_build_dir)
  local kernel_arch=${CHROMEOS_KERNEL_ARCH:-$(tc-arch-kernel)}
  local kernel_release=$(kernelrelease)
  local kernel_version=$(kmake -s kernelversion)

  info "Install /boot/dtbs/"
  kmake INSTALL_DTBS_PATH="${D}/boot/dtbs/$(kernelrelease)" dtbs_install

  info "Install ${D}/boot/extlinux.conf"
  cat > "${kernel_dir}/extlinux.conf" <<EOF
menu title Boot Menu
timeout 20
#default rockchip-${kernel_release}-debug

label rockchip-${kernel_release}-debug
    kernel /boot/Image-${kernel_release}
    devicetreedir /boot/dtbs/${kernel_release}
    append earlyprintk console=ttyS2,1500000n8 ro root=/dev/\${bootdevice}p\${bootdevice_part} rootfstype=ext4 init=/sbin/init rootwait cros_debug loglevel=7 dm_verity.error_behavior=3 dm_verity.max_bios=-1 dm_verity.dev_wait=0 dm="1 vroot none ro 1,0 2539520 verity payload=/dev/\${bootdevice}p\${bootdevice_part} hashtree=HASH_DEV hashstart=2539520 alg=sha1 root_hexdigest=a1910fbe4a24a30d19a49b85d2889776251e54e3 salt=c520b38f1057e5bef0aa64c00cd0d2e50662e22bf19771278921f90a35fd616d" vt.global_cursor_default=0 ethaddr=\${ethaddr} serial=\${serial#} cgroup.memory=nokmem

label rockchip-${kernel_release}
    kernel /boot/Image-${kernel_release}
    devicetreedir /boot/dtbs/${kernel_release}
    append earlyprintk console=ttyS2,1500000n8 ro root=/dev/\${bootdevice}p\${bootdevice_part} rootfstype=ext4 init=/sbin/init rootwait loglevel=7 dm_verity.error_behavior=3 dm_verity.max_bios=-1 dm_verity.dev_wait=0 dm="1 vroot none ro 1,0 2539520 verity payload=/dev/\${bootdevice}p\${bootdevice_part} hashtree=HASH_DEV hashstart=2539520 alg=sha1 root_hexdigest=a1910fbe4a24a30d19a49b85d2889776251e54e3 salt=c520b38f1057e5bef0aa64c00cd0d2e50662e22bf19771278921f90a35fd616d" vt.global_cursor_default=0 ethaddr=\${ethaddr} serial=\${serial#} cgroup.memory=nokmem
EOF

  insinto "/boot/extlinux"
  doins "${kernel_dir}/extlinux.conf"
}
