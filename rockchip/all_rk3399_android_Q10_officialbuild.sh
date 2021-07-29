#!/bin/bash
NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2

MACHINE_LIST=""

#rk3399_projects
if [ "$RSB4710A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb4710a2_2G
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rsb4710-a2.img
	ANDROID_PRODUCT=rsb4710_Android10-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_4710"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3399_android_Q10_officialbuild.sh $VERSION_NUM
fi

if [ "$ROM5780A3" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rom5780a3_2G
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rom5780-a3.img
	ANDROID_PRODUCT=rom5780_Android10-userdebug
	MACHINE_LIST="$MACHINE_LIST rom_5780"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT
	export MACHINE_LIST
	./rk3399_android_Q10_officialbuild.sh $VERSION_NUM
fi

if [ "$PPC115W" == "true" ]; then
        UBOOT_DEFCONFIG=rk3399_rsb4710a2_2G
        KERNEL_DEFCONFIG=rk3399_adv_defconfig
        KERNEL_DTB=rk3399-ppc115w-a2.img
        ANDROID_PRODUCT=ppc115w_Android10-userdebug
        MACHINE_LIST="$MACHINE_LIST ppc115w"

        export UBOOT_DEFCONFIG
        export KERNEL_DEFCONFIG
        export KERNEL_DTB
        export ANDROID_PRODUCT
        export MACHINE_LIST
        ./rk3399_android_Q10_officialbuild.sh $VERSION_NUM
fi

