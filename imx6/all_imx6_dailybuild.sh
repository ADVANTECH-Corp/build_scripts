#!/bin/bash
MACHINE_LIST=""
#imx6_projects
if [ $UBC220A1_SOLO == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6dlubc220a1"
fi
if [ $UBC220A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qubc220a1"
fi
if [ $UBCDS31A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qubcds31a1"
fi
if [ $ROM5420A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrom5420a1"
fi
if [ $ROM5420B1_SOLO == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6dlrom5420b1"
fi
if [ $ROM5420B1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrom5420b1"
fi
if [ $RSB4410A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrsb4410a1"
fi
if [ $RSB4410A2 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrsb4410a2"
fi
if [ $RSB4411A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrsb4411a1"
fi
if [ $EPCRS200A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qepcrs200a1"
fi
if [ $EBCJF02A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qebcjf02a1"
fi
if [ $ROM7420A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrom7420a1"
fi
if [ $ROM3420A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrom3420a1"
fi
if [ $ROM7421A1_PLUS == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qprom7421a1"
fi
if [ $ROM7421A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrom7421a1"
fi
if [ $ROM7421A1_SOLO == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6dlrom7421a1"
fi
if [ $EBCRB01A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qebcrb01a1"
fi
if [ $EBCRS03A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qebcrs03a1"
fi
if [ $EBCRS03A1_SOLO == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6dlebcrs03a1"
fi
if [ $RSB6410A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrsb6410a1"
fi
if [ $RSB6410A2 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrsb6410a2"
fi
if [ $RSB3430A1 == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6qrsb3430a1"
fi
if [ $RSB3430A1_SOLO == true ]; then
	MACHINE_LIST="$MACHINE_LIST imx6dlrsb3430a1"
fi
export MACHINE_LIST
./imx6_dailybuild.sh
