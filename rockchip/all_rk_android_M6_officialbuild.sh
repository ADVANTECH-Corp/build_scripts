#!/bin/bash
NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2

#rk3288_projects
if [ "$RSB4680A3" == "true" ]; then
	UBOOT_DEFCONFIG=rk3288_rsb4680a3_2G_defconfig
	KERNEL_DTB=rk3288-rsb4680-a3.img
	ANDROID_CONFIG=rsb4680-userdebug
	MACHINE_LIST="$MACHINE_LIST rsb_4680"
elif [ "$EBCRB03A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3288_ebcrb03a2_2G_defconfig
        KERNEL_DTB=rk3288-ebcrb03-a2.img
        ANDROID_CONFIG=ebcRB03-userdebug
        MACHINE_LIST="$MACHINE_LIST ebc_rb03"
elif [ "$USM110A2" == "true" ]; then
        UBOOT_DEFCONFIG=rk3288_usm110a2_2G_defconfig
        KERNEL_DTB=rk3288-usm110-a2.img
        ANDROID_CONFIG=usm_110-userdebug
        MACHINE_LIST="$MACHINE_LIST usm_110"
fi

export UBOOT_DEFCONFIG
export KERNEL_DTB
export ANDROID_CONFIG
./rk_android_M6_officialbuild.sh $VERSION_NUM

