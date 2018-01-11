#!/bin/bash
# vim: set ts=4 sw=4 ai noet:

SCRIPT=${0##*/}
SCRIPT_DIR=${0%/*}
SCRIPT_ID=${SCRIPT%_*build*}
CPU_TYPE=${SCRIPT_ID%%_*}
BSP_ID=${SCRIPT_ID#${CPU_TYPE}_*}
YOCTO_VER=`sed 's/^y//; s/./&./g; s/.$//' <<< ${BSP_ID%_*}`
VENDOR_VER=`sed 's/./&./g; s/.$//' <<< ${BSP_ID#*_}`

CALLEE=${SCRIPT_ID}_dailybuild.sh

#===== backup ================================================================
while [ -d ~/bin_old ]; do
	if diff ${SCRIPT} `ls -1 ~/bin_old/${SCRIPT}* | tail -1` ; then break ; fi
	cp -a $0 ~/bin_old/${SCRIPT}.`date +%Y%m%d_%H%M%S`
	break;
done &> /dev/null 
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#===== debug used ============================================================
[[ $DEBUG > 0 ]] && echo "===== ${SCRIPT}: debug mode enabled, level $DEBUG ====="

W_HEADER="\\\n===== $(date +'%F %R:%S') =====\\\n"
W_PFX="[ADV] "
# display value of variable (also works on array's element)
# e.g. W PATH CPU_ID[0] CPU_ID[1] 
function W()  { [[ $DEBUG < 2 ]] && return; eval echo -en $W_HEADER; for P in $@; do eval echo -e $W_PFX$P=\$\{$P\}$W_SFX; done; eval echo -en $W_FOOTER; }
# display array's all element
# e.g. WA CPU_ID
function WA() { [[ $DEBUG < 2 ]] && return; eval echo -en $W_HEADER; for P in $@; do for I in $(eval echo $(echo \$\{!$P[@]\})); do echo $P[$I]=`eval echo \$\{$P[$I]\}`; done; done; eval echo -en $W_FOOTER; }
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

function ERROR()
{
	if [ "$1" != "" ]; then echo -e "\nERROR:\t$1\n\n"; fi
	if [ "$2" != "" ]; then exit $2; else exit 255; fi
}

function USAGE()
{
	if [ "$1" != "" ]; then echo -e "\n$1"; fi
cat << END_OF_HELP

Syntax:

  ${0##*/} {version} {SRV_REV} {HASH_ADV} [date]

    version : {"LIV"|"LBV"}{MAJOR}{MINOR}
              MAJOR : 1 digit (greater than 0)
              MINOR : 3 digits 
    SRC_REV : linux kernel source revision
    HASH_ADV: meta-advantech commit hash (full or short)
    date    : YYYY-MM-DD (\`date +%F\`)

END_OF_HELP
	if [ "$2" != "" ]; then exit $2; fi
}

[[ $# < 3 || $# > 4 ]] && USAGE "invalid parameters" 1
[ ! -e ${SCRIPT_DIR}/${CALLEE} ] && ERROR "missing \"${CALLEE}\"" 1

[[ ! $1 =~ ^([lL][iIbB])?[vV]([0-9][.]?){3}[0-9A-Za-z]$ ]] && USAGE "!!! invalid version !!!" 1

VERSION=${1^^}
VERSION=${VERSION//./}
VERSION=${VERSION/LIV/LBV}
[ ${VERSION:0:1} == "V" ] && VERSION="LB${VERSION}"
[ ${VERSION:3:1} == 0 ] && USAGE "!!! The 1st version digit must be greater than 0. !!!" 1

SRC_REV=$2
[ ${#SRC_REV} != 40 ] && USAGE "!!! Invalid linux kernel source revision !!!" 1

HASH_ADV=$3
[[ ${#HASH_ADV} != 7 && ${#HASH_ADV} != 40 ]] && USAGE "!!! Invalid meta-advantech commit hash !!!" 1

DATE=${4:-$(date +%F)}
if ! [[ ${DATE} =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || ! date -d "${DATE}" >/dev/null ; then
	USAGE "!!! Invalid date format !!!" 1
fi

STORED=${STORED:-"/media/share/RISC_SW/officialbuild/"${SCRIPT_ID}}

export VERSION STORED SRC_REV HASH_ADV DATE

echo ""
echo "Starting the official build $VERSION, stored to $STORED"

W SCRIPT SCRIPT_DIR SCRIPT_ID BSP_ID YOCTO_VER VENDOR_VER
W VERSION STORED SRC_REV HASH_ADV DATE

echo calling ${CALLEE}
./${CALLEE}
