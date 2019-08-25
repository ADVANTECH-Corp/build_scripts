#!/bin/bash

NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
VERSION_NUM=$NUM1$NUM2
MACHINE_LIST=""

#am57xx_projects
if [ "$AM57XX_EVM" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST am57xx-evm"
fi
if [ "$ROM7510A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST am57xxrom7510a1"
fi
if [ "$ROM7510A2" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST am57xxrom7510a2"
fi
if [ "$RSB4220A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST am335xrsb4220a1"
fi
if [ "$RSB4221A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST am335xrsb4221a1"
fi
if [ "$ROM3310A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST am335xrom3310a1"
fi
if [ "$EPCR3220A1" == "true" ]; then
	MACHINE_LIST="$MACHINE_LIST am335xepcr3220a1"
fi

export MACHINE_LIST
./amxxxx_officialbuild.sh $VERSION_NUM
