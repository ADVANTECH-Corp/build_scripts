#!/bin/bash

# NUM1=`expr $VERSION : 'V\([0-9]*\)'`
# NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# VERSION_NUM=$NUM1$NUM2

VERSION_NUM=${RELEASE_VERSION}

MACHINE_LIST=""

#rk3288_projects
if [ "$RSB4680A3" == "true" ]; then
	UBOOT_DEFCONFIG=rsb4680a3-2G-rk3288
	KERNEL_DEFCONFIG=rk3288_adv_defconfig
	KERNEL_DTB=rk3288-rsb4680-a3.img
	MACHINE_LIST="$MACHINE_LIST rsb_4680"
	MODEL_NAME="4680"
	HW_VER="A3"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	./rk3288_debian9_v22_officialbuild.sh $VERSION_NUM
fi

if [ "$USM110A2" == "true" ]; then
	UBOOT_DEFCONFIG=usm110a2-2G-rk3288
	KERNEL_DEFCONFIG=rk3288_adv_defconfig
	KERNEL_DTB=rk3288-usm110-a2.img
	MACHINE_LIST="$MACHINE_LIST usm_110"
	MODEL_NAME="USM110"
	HW_VER="A2"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	./rk3288_debian9_v22_officialbuild.sh $VERSION_NUM
fi

if [ "$EBCRB03A2" == "true" ]; then
	UBOOT_DEFCONFIG=ebcrb03a2-2G-rk3288
	KERNEL_DEFCONFIG=rk3288_adv_defconfig
	KERNEL_DTB=rk3288-ebcrb03-a2.img
	MACHINE_LIST="$MACHINE_LIST ebc_rb03"
	MODEL_NAME="RB03"
	HW_VER="A2"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	./rk3288_debian9_v22_officialbuild.sh $VERSION_NUM
fi

