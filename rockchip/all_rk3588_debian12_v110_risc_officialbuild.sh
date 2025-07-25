#!/bin/bash

# NUM1=`expr $VERSION : 'V\([0-9]*\)'`
# NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# VERSION_NUM=$NUM1$NUM2

VERSION_NUM=${RELEASE_VERSION}

MACHINE_LIST=""

#rk3588_projects
if [ "$AOM3821A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST AOM3821"
	MODEL_NAME="AOM3821"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3588_aom3821a1_defconfig"
	RT_PATCH="false"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	export RT_PATCH
	./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$AFER460A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST AFER460"
	MODEL_NAME="AFER460"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3588_afer460a1_defconfig"
	RT_PATCH="true"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	export RT_PATCH
	./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$AFER460A2" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST AFER460"
	MODEL_NAME="AFER460"
	HW_VER="A2"
	BOARD_CONFIG="adv_rk3588_afer460a2_defconfig"
	RT_PATCH="true"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	export RT_PATCH
	./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$ASRA501A2" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST ASRA501"
        MODEL_NAME="ASRA501"
        HW_VER="A2"
        BOARD_CONFIG="adv_rk3588_asra501a2_eg90_defconfig"
        RT_PATCH="true"

        export MACHINE_LIST
        export MODEL_NAME
        export HW_VER
        export BOARD_CONFIG
        export RT_PATCH
        ./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$ASRA501A2EG90" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST ASRA501EG90"
        MODEL_NAME="ASRA501"
        HW_VER="A2EG90"
        BOARD_CONFIG="adv_rk3588_asra501a2_eg90_defconfig"
        RT_PATCH="true"

        export MACHINE_LIST
        export MODEL_NAME
        export HW_VER
        export BOARD_CONFIG
        export RT_PATCH
        ./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$ASRA501A2EG90ECAT" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST ASRA501EG90ECAT"
        MODEL_NAME="ASRA501"
        HW_VER="A2EG90ECAT"
        BOARD_CONFIG="adv_rk3588_asra501a2_eg90_ethercat_defconfig"
        RT_PATCH="true"
        ETHERCAT="true"
        ETHERCAT_HUB="https://AIM-Linux@dev.azure.com/AIM-Linux/risc-private-bsp/_git/ethercat"
        ETHERCAT_BRH="rk3588_ethercat_linux6.1_risc"
        ROS2="true"

        export MACHINE_LIST
        export MODEL_NAME
        export HW_VER
        export BOARD_CONFIG
        export RT_PATCH
        export ETHERCAT
        export ETHERCAT_HUB
        export ETHERCAT_BRH
        export ROS2
        ./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$ASRA501A2RM01" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST ASRA501RM01"
        MODEL_NAME="ASRA501"
        HW_VER="A2RM01"
        BOARD_CONFIG="adv_rk3588_asra501a2_rm01_defconfig"
        RT_PATCH="true"

        export MACHINE_LIST
        export MODEL_NAME
        export HW_VER
        export BOARD_CONFIG
        export RT_PATCH
        ./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$ASRA501A2RM02" == "true" ]; then
        MACHINE_LIST="$MACHINE_LIST ASRA501RM02"
        MODEL_NAME="ASRA501"
        HW_VER="A2RM02"
        BOARD_CONFIG="adv_rk3588_asra501a2_rm02_defconfig"
        RT_PATCH="true"

        export MACHINE_LIST
        export MODEL_NAME
        export HW_VER
        export BOARD_CONFIG
        export RT_PATCH
        ./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$ROM6881A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST ROM6881"
	MODEL_NAME="ROM6881"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3588_rom6881a1_defconfig"
	RT_PATCH="false"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	export RT_PATCH
	./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi

if [ "$EBCRS11A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST EBCRS11"
	MODEL_NAME="EBCRS11"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3588_ebcrs11a1_defconfig"
	RT_PATCH="false"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	export RT_PATCH
	./rk3588_debian12_v110_risc_officialbuild.sh $VERSION_NUM
fi



