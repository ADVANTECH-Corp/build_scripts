#!/bin/bash
NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2

MACHINE_LIST=""

#rk3288_projects
if [ "$RSB4680A3" == "true" ]; then
	UBOOT_DEFCONFIG=rk3288_rsb4680a3_2G_defconfig
	KERNEL_DEFCONFIG=rk3288_adv_defconfig
	KERNEL_DTB=rk3288-rsb4680-a3.img
	ANDROID_PRODUCT=rsb4680-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_4680"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT	
	export MACHINE_LIST
	./rk3288_android_O8_officialbuild.sh $VERSION_NUM
fi

if [ "$USM110A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3288_usm110a2_2G_defconfig
	KERNEL_DEFCONFIG=rk3288_adv_defconfig
	KERNEL_DTB=rk3288-usm110-a2.img
	ANDROID_PRODUCT=usm110-userdebug
	MACHINE_LIST="$MACHINE_LIST usm_110"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export ANDROID_PRODUCT	
	export MACHINE_LIST
	./rk3288_android_O8_officialbuild.sh $VERSION_NUM
fi

