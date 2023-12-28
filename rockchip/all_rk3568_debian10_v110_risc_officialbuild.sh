#!/bin/bash

# NUM1=`expr $VERSION : 'V\([0-9]*\)'`
# NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# VERSION_NUM=$NUM1$NUM2

VERSION_NUM=${RELEASE_VERSION}

MACHINE_LIST=""

#rk3568_projects

if [ "$RSB4810A2" == "true" ]; then
	UBOOT_DEFCONFIG=rk3568_rsb4810a2
	KERNEL_DEFCONFIG=rk3568_adv_defconfig
	KERNEL_DTB=rk3568-rsb4810-a2.img
	MACHINE_LIST="$MACHINE_LIST RSB4810"
	MODEL_NAME="RSB4810"
	HW_VER="A2"
	BOARD_CONFIG="BoardConfig-rk3568-rsb4810a2.mk"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3568_debian10_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$ROM5880A1" == "true" ]; then
	UBOOT_DEFCONFIG=rk3568_rom5880a1
	KERNEL_DEFCONFIG=rk3568_adv_defconfig
	KERNEL_DTB=rk3568-rom5880-a1.img
	MACHINE_LIST="$MACHINE_LIST ROM5880"
	MODEL_NAME="ROM5880"
	HW_VER="A1"
	BOARD_CONFIG="BoardConfig-rk3568-rom5880a1.mk"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3568_debian10_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$KEDGE350A1" == "true" ]; then
	UBOOT_DEFCONFIG=rk3568_kedge350a1
	KERNEL_DEFCONFIG=rk3568_adv_defconfig
	KERNEL_DTB=rk3568-kedge350-a1.img
	MACHINE_LIST="$MACHINE_LIST KEDGE350"
	MODEL_NAME="KEDGE350"
	HW_VER="A1"
	BOARD_CONFIG="BoardConfig-rk3568-kedge350a1.mk"

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3568_debian10_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$EBCRB07A1" == "true" ]; then
	UBOOT_DEFCONFIG=rk3568_ebcrb07a1
	KERNEL_DEFCONFIG=rk3568_adv_defconfig
	KERNEL_DTB=rk3568-ebcrb07-a1.img
	MACHINE_LIST="$MACHINE_LIST EBCRB07"
	MODEL_NAME="EBCRB07"
	HW_VER="A1"
	BOARD_CONFIG="BoardConfig-rk3568-ebcrb07a1.mk"
	DISPLAY_DIRECTION=vertical

	export UBOOT_DEFCONFIG
	export KERNEL_DEFCONFIG
	export KERNEL_DTB
	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	export DISPLAY_DIRECTION
	./rk3568_debian10_v110_risc_officialbuild.sh $VERSION_NUM
fi
