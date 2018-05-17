#!/bin/bash
MACHINE_LIST=""
#806x_projects
if [ $WISE3610A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST wise3610"
fi
export MACHINE_LIST
./806x_dailybuild.sh
