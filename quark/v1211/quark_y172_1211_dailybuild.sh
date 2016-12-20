#!/bin/bash
# vim: set ts=4 sw=4 ai noet:

SCRIPT=${0##*/}
SCRIPT_DIR=${0%/*}
SCRIPT_ID=${SCRIPT%_*build*}
CPU_TYPE=${SCRIPT_ID%%_*}
BSP_ID=${SCRIPT_ID#${CPU_TYPE}_*}
YOCTO_VER=`sed 's/^y//; s/./&./g; s/.$//' <<< ${BSP_ID%_*}`
VENDOR_VER=`sed 's/./&./g; s/.$//' <<< ${BSP_ID#*_}`

CALLEE=${SCRIPT_ID}_build.sh

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

  ${0##*/}
    using environment variable instead of specifying parameter
        SRC_REV : linux kernel source revision
        HASH_ADV: meta-advantech commit hash (full or short)
        VERSION : BSP version string
        STORED  : the stored directory of the built image
        DATE    : date mark

END_OF_HELP
	if [ "$2" != "" ]; then exit $2; fi
}

[[ $# > 0 ]] && USAGE "no parameter allowed" 1
[ ! -e ${SCRIPT_DIR}/${CALLEE} ] && ERROR "no script, ${CALLEE}" 1

GIT_BASE="git://github.com/ADVANTECH-Corp"

SRC_REV=${SRC_REV:-$(git ls-remote ${GIT_BASE}/linux-quark -b linux-3.14.28 | cut -c1-40)}
HASH_ADV=${HASH_ADV:-$(git ls-remote ${GIT_BASE}/meta-advantech -b master | cut -c1-40)}
STORED_BASE=${STORED_BASE:-"/media/share/RISC_SW/dailybuild"}
STORED=${STORED:-${STORED_BASE}/${SCRIPT_ID}}
VERSION=${VERSION:-"LBV0001"}
DATE=${DATE:-$(date +%F)}

W SRC_REV HASH_ADV STORED VERSION DATE

if [ "${BREAK}" != "" ]; then BREAK=" ${BREAK} "; fi
if [ "${SKIP}" != "" ]; then SKIP=" ${SKIP} "; fi

if [ ${VERSION} != LBV${VERSION/LBV/} ]; then
	echo "VERSION($VERSION) is invalid (must be LBV????)"
	exit 1
fi
LBVER=${VERSION}
LIVER=${VERSION/B/I}

echo ""
[ -z "${NO_WAITING_KEY_C+x}" ] && if read -t5 -n1 -p "Waiting 5 seconds...('c'ontinue or others to stop)"; then
	if [ "$REPLY" != "c" ]; then echo -e "\ninterrupted"; exit 1; fi
fi
echo ""

function SKIP()
{
	( [ "${SKIP}" == "" ] || [ "$1" == "" ] ) && return 1
	[ "${SKIP/ $1 /}" == "${SKIP}" ] && return 1
	echo "skip point $1"
	return 0
}

function EXIT_IF()
{
	( [ "${BREAK}" == "" ] || [ "$1" == "" ] ) && return
	[ "${BREAK/ $1 /}" == "${BREAK}" ] && return
	echo "break point $1"
	[ "$2" == "" ] && exit 0
	exit $2
}

W SCRIPT SCRIPT_DIR SCRIPT_ID BSP_ID YOCTO_VER VENDOR_VER
W VERSION LBVER LIVER STORED SRC_REV HASH_ADV DATE

echo calling ${CALLEE}

#Quark_BSP
if ( ! SKIP bsp ); then
	! ./${CALLEE} bsp ${LBVER} 512M $STORED $DATE ${SRC_REV} ${HASH_ADV} && echo "Failed on packing BSP" && exit 0
	EXIT_IF bsp
fi

#UBC-222
if ( ! SKIP 222 ); then
	! ./${CALLEE} ubc222 ${LIVER} 512M $STORED $DATE ${SRC_REV} ${HASH_ADV} && echo "Failed on building ubc222" && exit 0
	EXIT_IF 222
fi

#UBC-221
if ( ! SKIP 221 ); then
	! ./${CALLEE} ubc221 ${LIVER} 512M $STORED $DATE ${SRC_REV} ${HASH_ADV} && echo "Failed on building ubc221" && exit 0
	EXIT_IF 221
fi

#cp *.log $STORED/$DATE/
#rm *.log
#rm -rf LBV0001*
#rm -rf quarkLBV0001*

