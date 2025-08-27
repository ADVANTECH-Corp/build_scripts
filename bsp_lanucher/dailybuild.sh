#!/bin/bash

echo "[ADV] DATE = ${DATE}"
echo "[ADV] STORED = ${STORED}"
echo "[ADV] RELEASE_VERSION = ${RELEASE_VERSION}"

CURR_PATH="${PWD}"
RELEASE_FOLDER="aim_linux_bsp_launcher_v${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"

# ===========
#  Functions
# ===========
function get_source_code()
{
    echo "[ADV] get bsp launcher source code"
    mkdir $RELEASE_FOLDER
    pushd $RELEASE_FOLDER 2>&1 > /dev/null
	
    # 多個 Azure DevOps Repo URL
    REPOS=(
        "https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/NXP"
        "https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/NVIDIA"
        "https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/Qualcomm"
        "https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/Rockchip"
        "https://AIM-Linux@dev.azure.com/AIM-Linux/AIM_Linux_BSP_Launcher/_git/AIM_Linux_BSP_Launcher"
    )  

    CSV_FILE="../$RELEASE_FOLDER.csv"

    # 產生 CSV header
    echo "Platform,Branch,Commit Hash,Author,Date,Message" > "$CSV_FILE"

    for REPO_URL in "${REPOS[@]}"; do
        echo "==============================================="
        echo "[INFO] Processing repo: $REPO_URL"

        # 取得 repo 簡名 (平台名稱: NXP, NVIDIA, Qualcomm, Rockchip, AIM_Linux_BSP_Launcher)
        PLATFORM=$(basename "$REPO_URL")

        # 建立平台資料夾
        mkdir -p "$PLATFORM"

        # 取得所有 branch 名稱（只要 _develop）
        branches=$(git ls-remote --heads "$REPO_URL" | awk '{print $2}' | sed 's|refs/heads/||' | grep "_develop")

        if [ -z "$branches" ]; then
            echo "[INFO] No branch found with '_develop' in $PLATFORM."
            continue
        fi

        # 逐一 clone
        for branch in $branches; do
            FOLDER="$PLATFORM/$branch"
            if [ ! -d "$FOLDER" ]; then
                echo "[INFO] Cloning $branch into folder $FOLDER ..."
                git clone --branch "$branch" --single-branch "$REPO_URL" "$FOLDER"
            else
                echo "[INFO] Updating existing branch $branch ..."
		(cd "$FOLDER" && git fetch origin "$branch" && git checkout "$branch" && git pull)
            fi

            # 取得最新 commit 資訊
            COMMIT_INFO=$(cd "$FOLDER" && git log -1 --pretty=format:"%H|%an|%ad|%s" --date=short)
            COMMIT_HASH=$(echo "$COMMIT_INFO" | cut -d"|" -f1)
            COMMIT_AUTHOR=$(echo "$COMMIT_INFO" | cut -d"|" -f2)
            COMMIT_DATE=$(echo "$COMMIT_INFO" | cut -d"|" -f3)
            COMMIT_MSG=$(echo "$COMMIT_INFO" | cut -d"|" -f4-)

            # 寫入 CSV
            echo "$PLATFORM,$branch,$COMMIT_HASH,$COMMIT_AUTHOR,$COMMIT_DATE,\"$COMMIT_MSG\"" >> "$CSV_FILE"
        done
    done

    echo "[INFO] All repos processed. CSV saved to $CSV_FILE"

    popd
}

function generate_md5()
{
	FILENAME=$1

	if [ -e $FILENAME ]; then
		MD5_SUM=`md5sum -b $FILENAME | cut -d ' ' -f 1`
		echo $MD5_SUM > $FILENAME.md5
	fi
}

function prepare_and_copy_files()
{
	echo "[ADV] creating $RELEASE_FOLDER.tgz"

	tar czf $RELEASE_FOLDER.tgz $RELEASE_FOLDER
	rm -rf $RELEASE_FOLDER
	generate_md5 $RELEASE_FOLDER.tgz
	generate_md5 $RELEASE_FOLDER.csv
	mv -f $RELEASE_FOLDER.tgz* $OUTPUT_DIR
	mv -f $RELEASE_FOLDER.csv* $OUTPUT_DIR
}

# ================
#  Main procedure
# ================

# Make storage folder
if [ -e $OUTPUT_DIR ] ; then
	echo "[ADV] $OUTPUT_DIR had already been created"
	echo "[ADV] remove $OUTPUT_DIR"
	rm -rf $OUTPUT_DIR
fi

echo "[ADV] mkdir $OUTPUT_DIR"
mkdir -p $OUTPUT_DIR

get_source_code
prepare_and_copy_files

cd $CURR_PATH
echo "[ADV] build script done!"
