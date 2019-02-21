#!/bin/bash
NUM1=`expr $VERSION : 'V\([0-9]*\)'`
NUM2=`expr $VERSION : '.*[.]\([0-9A-Z]*\)'`
RELEASE_VERSION="V$NUM1$NUM2"
MACHINE_LIST=""

#Projects
if [ $WISE_3200 == true ]; then
	MACHINE_LIST="$MACHINE_LIST wise-3200"
fi

export RELEASE_VERSION
export MACHINE_LIST

./4531_officialbuild.sh
