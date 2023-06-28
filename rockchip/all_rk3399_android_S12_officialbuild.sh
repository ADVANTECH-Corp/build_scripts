#!/bin/bash

MACHINE_LIST=""

#rk3399_projects
if [ "$RSB4710A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb4710a2_2G
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rsb4710-a2-a2.img
	ANDROID_PRODUCT=rsb4710_Android12-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_4710"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3399_android_S12_officialbuild.sh
fi

if [ "$RSB3710A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb3710a2_2G
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rsb3710-a2.img
	ANDROID_PRODUCT=rsb3710_Android12-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_3710"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3399_android_S12_officialbuild.sh
fi

if [ "$PPC1XX" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb4710a2_2G
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-ppc1xx-a2.img
	ANDROID_PRODUCT=ppc1xx_Android12-userdebug
	MACHINE_LIST="$MACHINE_LIST ppc1xx"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3399_android_S12_officialbuild.sh
fi
