#!/bin/bash

# NUM1=`expr $VERSION : 'V\([0-9]*\)'`
# NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# VERSION_NUM=$NUM1$NUM2

VERSION_NUM=${RELEASE_VERSION}

MACHINE_LIST=""

#rk3568_projects
if [ "$RSB4810A2" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST RSB4810"
	MODEL_NAME="RSB4810"
	HW_VER="A2"
	BOARD_CONFIG="adv_rk3568_rsb4810a2_defconfig"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3568_debian11_v130_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$ROM5880A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST ROM5880"
	MODEL_NAME="ROM5880"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3568_rom5880a1_defconfig"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3568_debian11_v130_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$KEDGE350A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST KEDGE350"
	MODEL_NAME="KEDGE350"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3568_kedge350a1_defconfig"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3568_debian11_v130_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$EBCRB07A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST EBCRB07"
	MODEL_NAME="EBCRB07"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3568_ebcrb07a1_defconfig"
	DISPLAY_DIRECTION=vertical

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	export DISPLAY_DIRECTION
	./rk3568_debian11_v130_risc_officialbuild.sh $VERSION_NUM
fi


