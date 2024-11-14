#!/bin/bash

MACHINE_LIST=""

#rk3588_projects
if [ "$ROM6881A1" == "true" ]; then
	UBOOT_DEFCONFIG=rk3588_rom6881a1
	KERNEL_DEFCONFIG=rk3588_adv_defconfig
	KERNEL_DTB=rk3588-rom6881-a1.img
	ANDROID_PRODUCT=rom6881_u-userdebug
	MACHINE_LIST="$MACHINE_LIST rom_6881"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk_android_U14_officialbuild.sh
fi
