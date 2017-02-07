#!/bin/bash
MACHINE_LIST=""

#410c_projects
if [ $RSB_4760 == true ]; then
	MACHINE_LIST="$MACHINE_LIST rsb-4760"
fi
if [ $EPC_R4761 == true ]; then
	MACHINE_LIST="$MACHINE_LIST epc-r4761"
fi

export MACHINE_LIST
./410c_oe_dailybuild.sh
