#!/bin/bash
NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2

MACHINE_LIST=""

#rk3399_projects
if [ "$RSB4710A1" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb4710a1_2G_defconfig
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rsb4710-a1.img
	ANDROID_PRODUCT=rsb4710-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_4710"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT	
	export MACHINE_LIST
	./rk3399_android_N7_officialbuild.sh $VERSION_NUM
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
	./rk3399_android_N7_officialbuild.sh $VERSION_NUM
fi
