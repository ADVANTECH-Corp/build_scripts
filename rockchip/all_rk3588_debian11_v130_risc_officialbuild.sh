#!/bin/bash

# NUM1=`expr $VERSION : 'V\([0-9]*\)'`
# NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# VERSION_NUM=$NUM1$NUM2

VERSION_NUM=${RELEASE_VERSION}

MACHINE_LIST=""

#rk3588_projects
if [ "$ROM6881A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST ROM6881"
	MODEL_NAME="ROM6881"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3588_rom6881a1_defconfig"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3588_debian11_v130_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$EBCRS11A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST EBCRS11"
	MODEL_NAME="EBCRS11"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3588_ebcrs11a1_defconfig"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3588_debian11_v130_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$EBCRS11A1SZ" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST EBCRS11SZ"
	MODEL_NAME="EBCRS11SZ"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3588_ebcrs11a1_sz_defconfig"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3588_debian11_v130_risc_officialbuild.sh $VERSION_NUM
fi

