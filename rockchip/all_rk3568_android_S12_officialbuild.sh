#!/bin/bash

MACHINE_LIST=""

#rk3568_projects
if [ "$RSB4810A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3568_rsb4810a2
	KERNEL_DEFCONFIG=rk3568_adv_defconfig
	KERNEL_DTB=rk3568-rsb4810-a2.img
	ANDROID_PRODUCT=rsb4810_s-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_4810"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3568_android_S12_officialbuild.sh
fi

if [ "$ROM5880A1" == "true" ]; then
	UBOOT_DEFCONFIG=rk3568_rom5880a1
	KERNEL_DEFCONFIG=rk3568_adv_defconfig
	KERNEL_DTB=rk3568-rom5880-a1.img
	ANDROID_PRODUCT=rom5880_s-userdebug
	MACHINE_LIST="$MACHINE_LIST rom_5880"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3568_android_S12_officialbuild.sh
fi
