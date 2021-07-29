#!/bin/bash

# NUM1=`expr $VERSION : 'V\([0-9]*\)'`
# NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# VERSION_NUM=$NUM1$NUM2

VERSION_NUM=${RELEASE_VERSION}

MACHINE_LIST=""

#rk3399_projects
if [ "$RSB3710A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb3710a2_2G
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rsb3710-a2.img
	MACHINE_LIST="$MACHINE_LIST RSB3710"
	MODEL_NAME="RSB3710"
	HW_VER="A2"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	./rk3399_debian9_v231_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$RSB4710A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rsb4710a2_2G
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rsb4710-a2.img
	MACHINE_LIST="$MACHINE_LIST RSB4710"
	MODEL_NAME="RSB4710"
	HW_VER="A2"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	./rk3399_debian9_v231_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$ROM5780A3" == "true" ]; then
	UBOOT_DEFCONFIG=rk3399_rom5780a3_2G
	KERNEL_DEFCONFIG=rk3399_adv_defconfig
	KERNEL_DTB=rk3399-rom5780-a3.img
	MACHINE_LIST="$MACHINE_LIST ROM5780"
	MODEL_NAME="ROM5780"
	HW_VER="A3"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	./rk3399_debian9_v231_risc_officialbuild.sh $VERSION_NUM
fi
