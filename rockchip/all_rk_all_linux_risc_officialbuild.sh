#!/bin/bash

PROJECT_LIST=""

#rk3588_projects
if [ "$AOM3821A1" == "true" ]; then
	PROJECT_LIST="$PROJECT_LIST AOM3821"
	PROJECT="aom3821a1"
	BOARD_CONFIG="adv_rk3588_aom3821a1_defconfig"
	RT_PATCH="false"

	export PROJECT_LIST
	export PROJECT
	export BOARD_CONFIG
	export RT_PATCH
	./rk_all_linux_risc_officialbuild.sh
fi

if [ "$ROM6881A1" == "true" ]; then
	PROJECT_LIST="$PROJECT_LIST ROM6881"
	PROJECT="rom6881a1"
	BOARD_CONFIG="adv_rk3588_rom6881a1_defconfig"
	RT_PATCH="false"

	export PROJECT_LIST
	export PROJECT
	export HW_VER
	export BOARD_CONFIG
	export RT_PATCH
	./rk_all_linux_risc_officialbuild.sh
fi

if [ "$ASRA501A2" == "true" ]; then
	PROJECT_LIST="$PROJECT_LIST ASRA501"
	PROJECT="asra501a2"
	BOARD_CONFIG="adv_rk3588_asra501a2_defconfig"
	RT_PATCH="true"

	export PROJECT_LIST
	export PROJECT
	export HW_VER
	export BOARD_CONFIG
	export RT_PATCH
	./rk_all_linux_risc_officialbuild.sh
fi

#rk3576_projects
if [ "$AOM3841A1" == "true" ]; then
	PROJECT_LIST="$PROJECT_LIST AOM3841"
	PROJECT="aom3841a1"
	BOARD_CONFIG="rk3576_aom3841a1_defconfig"
	RT_PATCH="false"

	export PROJECT_LIST
	export PROJECT
	export BOARD_CONFIG
	export RT_PATCH
	./rk_all_linux_risc_officialbuild.sh
fi

if [ "$AOM5841A1" == "true" ]; then
	PROJECT_LIST="$PROJECT_LIST AOM5841"
	PROJECT="aom5841a1"
	BOARD_CONFIG="rk3576_aom5841a1_defconfig"
	RT_PATCH="false"

	export PROJECT_LIST
	export PROJECT
	export BOARD_CONFIG
	export RT_PATCH
	./rk_all_linux_risc_officialbuild.sh
fi

