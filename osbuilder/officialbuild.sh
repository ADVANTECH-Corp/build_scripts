#!/bin/bash

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] BSP_URL = ${BSP_URL}"
echo "[ADV] BSP_BRANCH = ${BSP_BRANCH}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"
VER_TAG=${RELEASE_VERSION}
CURR_PATH="$PWD"
ROOT_DIR="${VER_TAG}"_"$DATE"
SUB_DIR="OSBuilder"
OUTPUT_DIR="$CURR_PATH/$STORED/$DATE/"${RELEASE_VERSION}


# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
    echo "[ADV] $OUTPUT_DIR had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR"
    mkdir -p $OUTPUT_DIR
fi

if [ -e $OUTPUT_DIR/package ] ; then
    echo "[ADV] $OUTPUT_DIR/package  had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR/package"
    mkdir -p $OUTPUT_DIR/package
fi

if [ -e $OUTPUT_DIR/others ] ; then
    echo "[ADV] $OUTPUT_DIR/others  had already been created"
else
    echo "[ADV] mkdir $OUTPUT_DIR/others"
    mkdir -p $OUTPUT_DIR/others
fi

# ===========
#  Functions
# ===========

function get_source_code()
{
    echo "[ADV] get android source code"
    cd $CURR_PATH

    mkdir $ROOT_DIR
    cd $ROOT_DIR

    git clone "$BSP_URL"
    cd "$SUB_DIR"
    git fetch --all --tags
    REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
    git checkout -b local --track $REMOTE_SERVER/$BSP_BRANCH
    
    cd $CURR_PATH
}

function check_existing_tags()
{
    cd $CURR_PATH/$ROOT_DIR/$SUB_DIR
    echo "[CHECK] Checking tags..."
    git ls-remote --tags "$BSP_URL" | grep -q "refs/tags/${RELEASE_VERSION}$" && {
        echo "[ERROR] Tag ${RELEASE_VERSION} already exists!"
        exit 1
    }

    echo "[CHECK] No existing tags found. Proceeding ..."
    echo "=================================================="
    
    cd $CURR_PATH
}

function building()
{
    echo "[ADV] building ..."
    LOG_FILE=OSBuilder_"$RELEASE_VERSION"_Build.log
    
    echo "$RELEASE_VERSION" > version.conf
    ./package.sh 2>> $CURR_PATH/$ROOT_DIR/$LOG_FILE_ANDROID

    [ "$?" -ne 0 ] && echo "[ADV] Build failure! Check log file '$LOG_FILE'" && exit 1
}

function tag_version_commit()
{
    cd $CURR_PATH
    cd $ROOT_DIR/$SUB_DIR

    # push
    REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
    git add version.conf -f
    git commit -m "[Official Release] ${VER_TAG}"
    git push $REMOTE_SERVER local:$BSP_BRANCH
    
    cd $CURR_PATH
}

function auto_add_tag()
{
    cd $CURR_PATH/$ROOT_DIR/$SUB_DIR

    HEAD_HASH_ID=`git rev-parse HEAD`
    TAG_HASH_ID=`git tag -v $VER_TAG | grep object | cut -d ' ' -f 2`
    REMOTE_SERVER=`git remote -v | grep push | cut -d $'\t' -f 1`
    git tag -a $VER_TAG -m "[Official Release] $VER_TAG"
    git push $REMOTE_SERVER $VER_TAG

    cd $CURR_PATH
}

function generate_md5()
{
    FILENAME=$1

    if [ -e $FILENAME ]; then
        MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
        echo $MD5_SUM > $FILENAME.md5
    fi
}

function generate_csv()
{
    FILENAME=$1
    MD5_SUM=

    if [ -e $FILENAME ]; then
        MD5_SUM=`cat ${FILENAME}.md5`
    fi

    cd $CURR_PATH

    cat > ${FILENAME%.*}.csv << END_OF_CSV
RISC Software/OSBuilder Update News
Date, ${DATE}
TAG, ${VER_TAG}
MD5 Checksum,TGZ: ${MD5_SUM}
Issue description, N/A

END_OF_CSV
    
    cd $CURR_PATH
}

function save_temp_log()
{
    LOG_PATH="$CURR_PATH/$ROOT_DIR/$SUB_DIR"
    cd $LOG_PATH

    LOG_DIR="${VER_TAG}"_"$DATE"_log
    echo "[ADV] mkdir $LOG_DIR"
    mkdir $LOG_DIR

    # Backup conf, run script & log file
    cp -a OSBuilder_"${RELEASE_VERSION}"_Build*.log $LOG_DIR

    echo "[ADV] creating ${LOG_DIR}.tgz ..."
    tar czf $LOG_DIR.tgz $LOG_DIR
    generate_md5 $LOG_DIR.tgz

    mv -f $LOG_DIR.tgz $OUTPUT_DIR/others
    mv -f $LOG_DIR.tgz.md5 $OUTPUT_DIR/others

    # Remove all temp logs
    rm -rf $LOG_DIR
}

function copy_package_to_storage()
{
    echo "[ADV] copy package to $OUTPUT_DIR"

    generate_csv osbuilder_"${RELEASE_VERSION}"_install.run
    mv *.csv $OUTPUT_DIR/others

    mv -f osbuilder_"${RELEASE_VERSION}"_install.run $OUTPUT_DIR/package
    mv -f osbuilder_"${RELEASE_VERSION}"_install.run.md5 $OUTPUT_DIR/package

}

# ================
#  Main procedure 
# ================

get_source_code
check_existing_tags
building
save_temp_log
copy_image_to_storage
tag_version_commit
auto_add_tag

echo "[ADV] build script done!"

