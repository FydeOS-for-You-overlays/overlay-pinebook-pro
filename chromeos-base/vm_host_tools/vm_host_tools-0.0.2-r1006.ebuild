# Copyright 2017 The Chromium OS Authors. All rights reserved.
# Distributed under the terms of the GNU General Public License v2

EAPI=7

CROS_WORKON_COMMIT="cb11f42253db4dfbb9c556e16ff2ea2595646ca8"
CROS_WORKON_TREE=("fe8d35af30ff1c2484e01cd6235a5d45c627d10d" "2834854981f88e2b81fefd49c590185a31f2b1f1" "cb16d1cfaf9321e778b6c91115a333f0624be0aa" "e7dba8c91c1f3257c34d4a7ffff0ea2537aeb6bb")
CROS_WORKON_LOCALNAME="platform2"
CROS_WORKON_PROJECT="chromiumos/platform2"
CROS_WORKON_OUTOFTREE_BUILD=1
CROS_WORKON_INCREMENTAL_BUILD=1
CROS_WORKON_SUBTREE="common-mk metrics vm_tools .gn"

PLATFORM_SUBDIR="vm_tools"

inherit cros-workon platform udev user arc-build-constants

DESCRIPTION="VM host tools for Chrome OS"
HOMEPAGE="https://chromium.googlesource.com/chromiumos/platform2/+/master/vm_tools"

LICENSE="BSD-Google"
KEYWORDS="*"
# The crosvm-wl-dmabuf USE flag is used when preprocessing concierge source.
IUSE="+kvm_host +seccomp +crosvm-wl-dmabuf fuzzer wilco"
REQUIRED_USE="kvm_host"

COMMON_DEPEND="
	app-arch/libarchive:=
	!!chromeos-base/vm_tools
	chromeos-base/chunnel:=
	chromeos-base/crosvm:=
	>=chromeos-base/metrics-0.0.1-r3152:=
	chromeos-base/minijail:=
	chromeos-base/patchpanel:=
	net-libs/grpc:=
	dev-libs/protobuf:=
"

RDEPEND="
	${COMMON_DEPEND}
	dev-rust/9s
"
DEPEND="
	${COMMON_DEPEND}
	chromeos-base/shill-client:=
	chromeos-base/system_api:=[fuzzer?]
	chromeos-base/vm_protos:=
	fuzzer? ( dev-libs/libprotobuf-mutator:= )
"

get_vmlog_forwarder_start_services() {
	local start_services="starting vm_concierge"
	if use wilco; then
		start_services+=" or starting wilco_dtc_dispatcher"
	fi
	echo "${start_services}"
}

get_vmlog_forwarder_stop_services() {
	local stop_services="stopped vm_concierge"
	if use wilco; then
		stop_services+=" and stopped wilco_dtc_dispatcher"
	fi
	echo "${stop_services}"
}

pkg_setup() {
	# Duplicated from the crosvm ebuild. These are necessary here in order
	# to create the daemon-store folder for concierge in src_install().
	enewuser crosvm
	enewgroup crosvm
	enewuser pluginvm
	cros-workon_pkg_setup
}

src_install() {
	platform_install_compilation_database

	dobin "${OUT}"/cicerone_client
	dobin "${OUT}"/concierge_client
	dobin "${OUT}"/maitred_client
	dobin "${OUT}"/seneschal
	dobin "${OUT}"/seneschal_client
	dobin "${OUT}"/vm_cicerone
	dobin "${OUT}"/vm_concierge
	dobin "${OUT}"/vmlog_forwarder
	dobin "${OUT}"/vsh

	if use arcvm; then
		arc-build-constants-configure
		exeinto "${ARC_VM_VENDOR_DIR}/bin"
		doexe "${OUT}"/vshd
	fi

	platform_fuzzer_install "${S}"/OWNERS "${OUT}"/cicerone_container_listener_fuzzer
	platform_fuzzer_install "${S}"/OWNERS "${OUT}"/vsh_client_fuzzer

	# Install header for passing USB devices to plugin VMs.
	insinto /usr/include/vm_concierge
	doins concierge/plugin_vm_usb.h

	insinto /etc/init
	doins init/seneschal.conf
	doins init/vm_cicerone.conf
	doins init/vm_concierge.conf

	# Modify vmlog_forwarder starting and stopping conditions based on USE flags.
	sed \
		"-e s,@dependent_start_services@,$(get_vmlog_forwarder_start_services),"\
		"-e s,@dependent_stop_services@,$(get_vmlog_forwarder_stop_services)," \
		init/vmlog_forwarder.conf.in | newins - vmlog_forwarder.conf

	insinto /etc/dbus-1/system.d
	doins dbus/*.conf

	insinto /etc
	doins init/arcvm_dev.conf

	insinto /usr/share/policy
	if use seccomp; then
		newins "init/vm_cicerone-seccomp-${ARCH}.policy" vm_cicerone-seccomp.policy
	fi

	udev_dorules udev/99-vm.rules

	keepdir /opt/google/vms

	# Create daemon store folder for crosvm and pvm
	local crosvm_store="/etc/daemon-store/crosvm"
	dodir "${crosvm_store}"
	fperms 0700 "${crosvm_store}"
	fowners crosvm:crosvm "${crosvm_store}"

	local pvm_store="/etc/daemon-store/pvm"
	dodir "${pvm_store}"
	fperms 0770 "${pvm_store}"
	fowners pluginvm:crosvm "${pvm_store}"
}

platform_pkg_test() {
	local tests=(
		cicerone_test
		concierge_test
		syslog_forwarder_test
	)

	# Running a gRPC server under qemu-user causes flake, at least with the
	# combination of gRPC 1.16.1 and qemu 3.0.0. Disable TerminaVmTest.* while
	# running under qemu to avoid triggering this flake.
	# TODO(crbug.com/1066425): Reenable gRPC server tests under qemu-user.
	local qemu_gtest_filter="-TerminaVmTest.*"
	local test_bin
	for test_bin in "${tests[@]}"; do
		platform_test "run" "${OUT}/${test_bin}" "0" "" "${qemu_gtest_filter}"
	done
}

pkg_preinst() {
	# We need the syslog user and group for both host and guest builds.
	enewuser syslog
	enewgroup syslog

	enewuser vm_cicerone
	enewgroup vm_cicerone

	enewuser seneschal
	enewgroup seneschal
	enewuser seneschal-dbus
	enewgroup seneschal-dbus

	enewuser pluginvm
	enewgroup pluginvm

	enewgroup virtaccess
}

src_prepare() {
  default
  epatch ${FILESDIR}/reduce_vm_mem.patch  
}
