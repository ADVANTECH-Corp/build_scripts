#!/bin/bash

# NUM1=`expr $VERSION : 'V\([0-9]*\)'`
# NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
# VERSION_NUM=$NUM1$NUM2

VERSION_NUM=${RELEASE_VERSION}

MACHINE_LIST=""

#rk3576_projects
if [ "$AOM3841A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST AOM3841"
	MODEL_NAME="AOM3841A1"
	HW_VER="A1"
	BOARD_CONFIG="adv_rk3576_aom3841a1_defconfig"

	export MACHINE_LIST
	export MODEL_NAME
	export HW_VER
	export BOARD_CONFIG
	./rk3576_debian12_v101_risc_officialbuild.sh $VERSION_NUM
fi

