#!/bin/bash
MACHINE_LIST=""

#Projects
if [ $WISE_3200 == true ]; then
	MACHINE_LIST="$MACHINE_LIST wise-3200"
fi

export MACHINE_LIST
./4531_dailybuild.sh
