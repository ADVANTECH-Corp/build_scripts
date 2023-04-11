#!/bin/bash

MACHINE_LIST=""

#rk3399_projects
if [ "$RSB4710A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb4710a2_2G_defconfig
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rsb4710-a2.img
	ANDROID_PRODUCT=rk3399_rsb4710-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_4710"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3399_android_N7_officialbuild.sh
fi

if [ "$RSB4710A2LITE" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb4710a2_2G_defconfig
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rsb4710-a2-lite.img
	ANDROID_PRODUCT=rk3399_rsb4710li-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_4710li"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3399_android_N7_officialbuild.sh
fi

if [ "$RSB3710A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb3710a2_2G_defconfig
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rsb3710-a2.img
	ANDROID_PRODUCT=rk3399_rsb3710-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_3710"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3399_android_N7_officialbuild.sh
fi

if [ "$ROM5780A3" == "true" ]; then
        UBOOT_DEFCONFIG=rk3399_rom5780a3_2G_defconfig
        KERNEL_DEFCONFIG=rk3399_adv_defconfig
        KERNEL_DTB=rk3399-rom5780-a3.img
        ANDROID_PRODUCT=rk3399_rom5780-userdebug
        MACHINE_LIST="$MACHINE_LIST rom_5780"

        export UBOOT_DEFCONFIG
        export KERNEL_DEFCONFIG
        export KERNEL_DTB
        export ANDROID_PRODUCT
        export MACHINE_LIST
        ./rk3399_android_N7_officialbuild.sh
fi

if [ "$RK3399DEMO" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_defconfig
	KERNEL_DEFCONFIG=rockchip_defconfig
	KERNEL_DTB=rk3399-sapphire-excavator-edp.img
	ANDROID_PRODUCT=rk3399_all-userdebug
	MACHINE_LIST="$MACHINE_LIST rk3399demo"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3399_android_N7_officialbuild.sh
fi
