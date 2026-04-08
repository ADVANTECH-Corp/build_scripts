#!/bin/bash

#
# FILE: aw_t536_linux_risc_officialbuild.sh
# PURPOSE: Auto build on azure pipeline
# AUTHOR: kuihong.xin
#Reference from : rk_all_linux_risc_officialbuild.sh 
#


# ===========
#  Strict Error Handling
# ===========
set -euo pipefail

# ===========
#  Global Variables
# ===========
declare -g SCRIPT_VERSION="1.0.2"

declare -g REPO="repo"
declare -g VERSION_K="" VERSION_M="" VERSION_P=""
declare -g VERSION_K_LAST="" VERSION_M_LAST="" VERSION_P_LAST=""
declare -g KERNEL_VERSION="" ADV_VERSION=""
declare -g RAM_SIZE="all" STORAGE="all"
declare -g FIRST_PROJECT="true"
declare -g CURR_PATH="$PWD"
declare -g ROOT_DIR="${OS_DISTRO}_${DATE}"
declare -g ROOTFS_AW="${ROOTFS_AW:-buildroot}"  # Default value is debian

# Read-only arrays
readonly SPECIAL_GIT_REPOSITORY=(".repo/manifests")
#readonly BUILD_COMPONENTS=("bootloader" "kernel" "rootfs" "all"  "pack")
readonly BUILD_COMPONENTS=("bootloader"  "all"  "pack")
readonly REQUIRED_VARS=(
    "BSP_URL" "BSP_BRANCH" "BSP_XML"
    "DATE" "STORED"
    "SDK_VERSION" "OS_DISTRO" "CHIP_NAME"
    "VERSION_TYPE" "VERSION_FIXED"
    "PROJECT" "PROJECT_LIST" "BOARD_CONFIG_AW"
)

# ===========
#  Functions
# ===========

# Logging functions
function Get_Timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

function Log_Info() {
    echo "[ADV][$(Get_Timestamp)] INFO: $1"
}

function Log_Warning() {
    echo "⚠️ [ADV][$(Get_Timestamp)] WARNING: $1"
}

function Log_Error() {
    echo "❌ [ADV][$(Get_Timestamp)] ERROR: $1"
}

function Log_Success() {
    echo "✅ [ADV][$(Get_Timestamp)] SUCCESS: $1"
}

# Error handling function
function Handle_Error() {
    local EXIT_CODE=$?
    local LINE_NU=$1
    local COMMAND=$2
    Log_Error "Command failed at line $LINE_NU: $COMMAND (exit code: $EXIT_CODE)"
    exit $EXIT_CODE
}

trap 'Handle_Error ${LINENO} "$BASH_COMMAND"' ERR

# Safe directory change function
function Safe_cd() {
    local target_dir="$1"
    if ! cd "$target_dir"; then
        Log_Error "Failed to enter directory: $target_dir"
        return 1
    fi
    return 0
}

# Validate and set ROOTFS
function Validate_And_Set_Rootfs() {
    Log_Info "Validating ROOTFS configuration..."
    
    # If ROOTFS is empty, set to buildroot
    if [[ -z "${ROOTFS_AW}" ]]; then
        ROOTFS_AW="buildroot"
        Log_Info "ROOTFS not set, using default: $ROOTFS_AW"
        return 0
    fi
    
    # Check if ROOTFS is a supported value
    case "${ROOTFS_AW}" in
        "debian"|"ubuntu"|"yocoto"|"buildroot")
            Log_Info "Using specified ROOTFS: $ROOTFS_AW"
            ;;
        *)
            Log_Warning "Unsupported ROOTFS '$ROOTFS_AW', falling back to 'buildroot'"
            ROOTFS_AW="buildroot"
            ;;
    esac
    
    Log_Info "Final ROOTFS configuration: $ROOTFS_AW"
    return 0
}

# Validate required environment variables
function Validate_Environment() {
    local MISSING_VARS=()
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            MISSING_VARS+=("$var")
        fi
    done
    
    if [[ ${#MISSING_VARS[@]} -gt 0 ]]; then
        Log_Error "Required variables not set: ${MISSING_VARS[*]}"
        return 1
    fi

    # Validate VERSION_TYPE
    local version_type_lower="${VERSION_TYPE,,}"
    case "$version_type_lower" in
        "ga"|"beta"|"alpha")
            Log_Info "Valid VERSION_TYPE: $VERSION_TYPE"
            ;;
        *)
            Log_Error "Invalid VERSION_TYPE '$VERSION_TYPE'. Must be 'GA', 'Beta' or 'Alpha'"
            return 1
            ;;
    esac
    # Convert VERSION_TYPE to lowercase
    VERSION_TYPE="$version_type_lower"
    
    # Validate VERSION_FIXED
    local version_fixed_lower="${VERSION_FIXED,,}"
    case "$version_fixed_lower" in
        "true"|"false")
            Log_Info "Valid VERSION_FIXED: $VERSION_FIXED"
            ;;
        *)
            Log_Error "Invalid VERSION_FIXED '$VERSION_FIXED'. Must be 'true' or 'false'"
            return 1
            ;;
    esac
    # Convert VERSION_FIXED to lowercase
    VERSION_FIXED="$version_fixed_lower"

    Validate_And_Set_Rootfs
    Log_Success "All required environment variables are set"
}

function Create_Root_Dir() {
    local target_dir="$CURR_PATH/$ROOT_DIR"
    
    if [[ -e "$target_dir" ]]; then
        Log_Info "Directory already exists: $target_dir"
    else
        Log_Info "Creating root directory: $target_dir"
        if ! mkdir -p "$target_dir"; then
            Log_Error "Failed to create directory: $target_dir"
            return 1
        fi
    fi
    
    Safe_cd "$target_dir" || return 1
}

function Create_Output_Dir() {
    Safe_cd "$CURR_PATH" || return 1
    
    local output_subdirs=("bsp" "image" "others")
    
    for subdir in "${output_subdirs[@]}"; do
        local full_path="$OUTPUT_DIR/${PROJECT}/$subdir"
        if [[ -e "$full_path" ]]; then
            Log_Info "Directory exists: $full_path"
        else
            Log_Info "Creating directory: $full_path"
            if ! mkdir -p "$full_path"; then
                Log_Error "Failed to create directory: $full_path"
                return 1
            fi
        fi
    done

    return 0
}

function Get_First_Project() {
    local idx=0

    for _ in $PROJECT_LIST; do
        ((idx++)) || true
    done
    
    if [[ $idx -gt 1 ]]; then
        FIRST_PROJECT="false"
    else
        FIRST_PROJECT="true"
    fi
    
    Log_Info "First project flag: $FIRST_PROJECT"

    return 0
}

function Get_Adv_Version() {
    if [[ "$ROOTFS_AW" == "ubuntu" ]]; then
        local version_file="$CURR_PATH/$ROOT_DIR/.repo/manifests/version/${PROJECT}_ubuntu"
    else
        local version_file="$CURR_PATH/$ROOT_DIR/.repo/manifests/version/${PROJECT}"
    fi
    
    if [[ ! -f "$version_file" ]]; then
        VERSION_K_LAST="0"
        VERSION_M_LAST="0"
        VERSION_P_LAST="0"
        Log_Info "No previous version file found, starting from 0.0.0"
    else
        VERSION_K_LAST=$(grep -E '^VERSION_K\s*=' "$version_file" | sed -E 's/.*=\s*([0-9]+).*/\1/' | head -1)
        VERSION_M_LAST=$(grep -E '^VERSION_M\s*=' "$version_file" | sed -E 's/.*=\s*([0-9]+).*/\1/' | head -1)
        VERSION_P_LAST=$(grep -E '^VERSION_P\s*=' "$version_file" | sed -E 's/.*=\s*([0-9]+).*/\1/' | head -1)

        Log_Info "Previous version: $VERSION_K_LAST.$VERSION_M_LAST.$VERSION_P_LAST"
    fi
    
    # Validate version numbers are numeric
    if ! [[ "$VERSION_K_LAST" =~ ^[0-9]+$ ]] || ! [[ "$VERSION_M_LAST" =~ ^[0-9]+$ ]] || ! [[ "$VERSION_P_LAST" =~ ^[0-9]+$ ]]; then
        Log_Error "Invalid version format detected: VERSION_K_LAST='$VERSION_K_LAST', VERSION_M_LAST='$VERSION_M_LAST', VERSION_P_LAST='$VERSION_P_LAST'"
        if [[ "$ROOTFS_AW" == "ubuntu" ]]; then
            Log_Error "Please check the version file: '.repo/manifests/version/${PROJECT}_ubuntu'"
        else
            Log_Error "Please check the version file: '.repo/manifests/version/${PROJECT}'"
        fi
        return 1
    fi

    # Version calculation logic
    case $VERSION_TYPE in
        "ga")
            if [[ "${VERSION_FIXED}" == "true" ]]; then
                VERSION_K="${VERSION_K_LAST}"
            else
                VERSION_K=$((VERSION_K_LAST + 1))
            fi
            if [[ "${VERSION_K}" == "0" ]]; then
                VERSION_K="1"
            fi
            VERSION_M="0"
            VERSION_P="0"
            ;;
        "beta")
            VERSION_K="${VERSION_K_LAST}"
            if [[ "${VERSION_FIXED}" == "true" ]]; then
                VERSION_M="${VERSION_M_LAST}"
            else
                VERSION_M=$((VERSION_M_LAST + 1))
            fi
            if [[ "${VERSION_M}" == "0" ]]; then
                VERSION_M="1"
            fi
            VERSION_P="0"
            ;;
        "alpha")
            VERSION_K="${VERSION_K_LAST}"
            VERSION_M="${VERSION_M_LAST}"
            if [[ "${VERSION_FIXED}" == "true" ]]; then
                VERSION_P="${VERSION_P_LAST}"
            else
                VERSION_P=$((VERSION_P_LAST + 1))
            fi
            if [[ "${VERSION_P}" == "0" ]]; then
                VERSION_P="1"
            fi
            ;;
        *)
            Log_Error "Invalid VERSION_TYPE '$VERSION_TYPE'. Must be 'ga', 'beta' or 'alpha'"
            return 1
            ;;
    esac

    ADV_VERSION="${VERSION_K}.${VERSION_M}.${VERSION_P}"
    Log_Info "New version: $ADV_VERSION"

    return 0
}

function Get_Kernel_Version() {
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    local makefile="$CURR_PATH/$ROOT_DIR/kernel/${BOARD_CONFIG_AW}/Makefile"
    if [[ ! -f "$makefile" ]]; then
        Log_Error "Makefile not found in kernel directory"
        return 1
    fi
    
    local version patchlevel sublevel extraversion
    version=$(grep -E '^VERSION\s*=' "$makefile" | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/')
    patchlevel=$(grep -E '^PATCHLEVEL\s*=' "$makefile" | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/')
    sublevel=$(grep -E '^SUBLEVEL\s*=' "$makefile" | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/')
    extraversion=$(grep -E '^EXTRAVERSION\s*=' "$makefile" | head -1 | sed -E 's/.*=\s*([^#]*).*/\1/' | tr -d ' ')
    
    KERNEL_VERSION="${version}.${patchlevel}.${sublevel}${extraversion}"
    Log_Info "Kernel version: $KERNEL_VERSION"
    return 0
}

function Init_Global_Variable() {
    if [[ "$ROOTFS_AW" == "ubuntu" ]]; then
        OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}/uiv${SDK_VERSION}.${ADV_VERSION}"
    else
        OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}/v${SDK_VERSION}.${ADV_VERSION}"
    fi

    VER_TAG="${PROJECT}_${OS_DISTRO}_v${ADV_VERSION}_kernel-${KERNEL_VERSION}_${CHIP_NAME}"
    VER_MANIFEST="${VER_TAG}"
    VER_LOG="${VER_TAG}_${RAM_SIZE}_${STORAGE}_${DATE}.log"
    VER_IMAGE="${VER_TAG}_${RAM_SIZE}_${STORAGE}_${DATE}.img"
    VER_BSP="${VER_TAG}_${RAM_SIZE}_${STORAGE}_${DATE}.bsp"
    VER_OTHERS="${VER_TAG}_${RAM_SIZE}_${STORAGE}_${DATE}.others"
    
    Log_Success "Global variables initialized successfully"

    return 0
}

function print_config() {
    printf "%-18s: %s\n" "$1" "$2"
}

function Dump_Global_Variable() {
    Log_Info "Build Configuration"
    echo "================================="
    print_config "DATE" "$DATE"
    print_config "STORED" "$STORED"
    print_config "BSP_URL" "$BSP_URL"
    print_config "BSP_BRANCH" "$BSP_BRANCH"
    print_config "BSP_XML" "$BSP_XML"
    print_config "PROJECT" "$PROJECT"
    print_config "BOARD_CONFIG_AW" "$BOARD_CONFIG_AW"
    print_config "PLATFORM_AW" "$PLATFORM_AW"
    print_config "CHIP_NAME" "$CHIP_NAME"
    print_config "PROJECT_LIST" "$PROJECT_LIST"
    print_config "VERSION_TYPE" "$VERSION_TYPE"
    print_config "VERSION_FIXED" "$VERSION_FIXED"
    print_config "SDK_VERSION" "$SDK_VERSION"
    print_config "PREVIOUS_VERSION" "${VERSION_K_LAST}.${VERSION_M_LAST}.${VERSION_P_LAST}"
    print_config "ADV_VERSION" "$ADV_VERSION"
    print_config "KERNEL_VERSION" "$KERNEL_VERSION"
    print_config "ROOTFS_AW" "$ROOTFS_AW"
    print_config "VER_TAG" "$VER_TAG"
    print_config "OUTPUT_DIR" "$OUTPUT_DIR"
    echo "================================="

    return 0
}

function Get_Source_Code() {
    Log_Info "Fetching $CHIP_NAME $OS_DISTRO source code"
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    if [[ $FIRST_PROJECT != "true" ]]; then
        Log_Info "Reusing existing source code (FIRST_PROJECT=$FIRST_PROJECT)"
        return 0
    fi

    local repo_cmd=""
    if [[ -z "$BSP_BRANCH" ]]; then
        repo_cmd="$REPO init -u $BSP_URL"
    elif [[ -z "$BSP_XML" ]]; then
        repo_cmd="$REPO init -u $BSP_URL -b $BSP_BRANCH"
    else
        repo_cmd="$REPO init -u $BSP_URL -b $BSP_BRANCH -m $BSP_XML"
    fi
    
    Log_Info "Executing: $repo_cmd"
    if ! $repo_cmd; then
        Log_Error "repo init failed"
        return 1
    fi
    
    Log_Info "Syncing repositories..."
    if ! $REPO sync; then
        Log_Error "repo sync failed"
        return 1
    fi
    
    # Setup tracking branches
    local remote_server
    cd "brandy"
    remote_server=$(git remote -v | grep push | awk '{print $1}')
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    Log_Info "Creating local tracking branches..."
    if ! $REPO forall -c "git checkout -b local --track $remote_server/$BSP_BRANCH"; then
        Log_Warning "Failed to create tracking branches"
    fi

    Log_Info "Creating local tracking branches for manifests..."
    Safe_cd ".repo/manifests" || return 1
    git branch -D local
    remote_server=$(git remote -v | grep push | awk '{print $1}')
    if ! git checkout -b local --track $remote_server/$BSP_BRANCH; then
        Log_Warning "Failed to create tracking branches for .repo/manifests"
    fi
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    Safe_cd "$CURR_PATH" || return 1
    Log_Success "Source code preparation completed successfully"

    return 0
}

function generate_md5() {
    local filename="$1"
    
    if [[ -e "$filename" ]]; then
        Log_Info "Generating MD5 for: $filename"
        md5sum -b "$filename" | cut -d ' ' -f 1 > "${filename}.md5"
    else
        Log_Warning "File not found for MD5 generation: $filename"
        return 1
    fi
    return 0
}

function apply_kernel_patch() {
    Log_Info "Applying kernel patches..."
    if [[ ${RT_PATCH:-} == "true" ]]; then
        Log_Info "Applying real-time (RT) patch..."
        git apply patch/RT/*.patch
        Log_Success "RT patch applied successfully"
    fi
    
    if [[ ${ETHERCAT:-} == "true" ]]; then
        Log_Info "Applying EtherCAT driver patch..."
        local TARGET_LINE="obj-m += ethercat/"
        local TARGET_PATH="drivers/net/ethernet/stmicro"

        if [ -d "ethercat" ]; then
            Log_Info "Deleting old EtherCAT driver"
            rm -rf ethercat
        fi

        Log_Info "Cloning EtherCAT driver repository"
        git clone ${ETHERCAT_HUB} -b ${ETHERCAT_BRH} ethercat

        Log_Info "Integrating EtherCAT driver into kernel"
        cp -rf ethercat/ $TARGET_PATH
        rm -rf ethercat/
        sync

        Log_Info "Updating the Makefile"
        if ! grep -Fxq "$TARGET_LINE" "$TARGET_PATH/Makefile"; then
            echo "$TARGET_LINE" >> "$TARGET_PATH/Makefile"
            Log_Success "Makefile configuration updated"
        fi
        Log_Success "EtherCAT driver patch applied successfully"
    fi
    Log_Success "All kernel patches applied successfully"
}

function Build_Component() {
    local component="$1"
    
    # Validate component parameter
    if [[ -z "$component" ]]; then
        Log_Error "Component name is required"
        return 1
    fi
    
    # Check if component is in BUILD_COMPONENTS
    if [[ ! " ${BUILD_COMPONENTS[@]} " =~ " ${component} " ]]; then
        Log_Error "Invalid component: $component"
        return 1
    fi
    
    local log_file="${VER_TAG}_Build_${component}.log"
    local start_time end_time duration
    
    Log_Info "Building component: $component"
    start_time=$(date +%s)
    
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    # Define success pattern matching
    local -A success_patterns=(
        ["bootloader"]="build brandy OK."
        ["kernel"]="all(Kernel+modules+boot.img) successful"
        ["rootfs"]="build buildroot OK."
        ["all"]="build OK."
        ["pack"]="pack finish"
    )

    local build_status=0
    case $component in
        "bootloader")
            echo " V${SDK_VERSION}.${ADV_VERSION}" > brandy/brandy-2.0/u-boot-2023/.scmversion
            ;;
    esac

    # Unified build command execution
    local build_cmd="./build.sh $component"
    if [[ $component == "rootfs" ]]; then
        if [[ "$ROOTFS_AW" == "ubuntu" ]]; then
            build_cmd="./build.sh ubuntu"
        else
            build_cmd="./build.sh buildroot_rootfs"
        fi
    fi

    if [[ $component == "all" ]]; then
            build_cmd="./build.sh "
    fi
    
    Log_Info "Executing: $build_cmd"
    {
        Log_Info "Build started at: $(Get_Timestamp)"
        if ! $build_cmd; then
            build_status=1
        fi
        Log_Info "Build finished at: $(Get_Timestamp)"
    } > >(tee "$log_file") 2>&1

    # Check build success pattern
    local pattern="${success_patterns[$component]}"
    if [[ -n "$pattern" ]] && ! grep -q -E "$pattern" "$log_file"; then
        build_status=1
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [[ $build_status -ne 0 ]]; then
        Log_Error "$component build failed after $duration seconds. Check log: $log_file"
        return 1
    else
        Log_Success "$component build completed in $duration seconds"
    fi
    
    return 0
}

function Build_Linux_Images() {
    local start_time end_time duration
    start_time=$(date +%s)
    
    Log_Info "Starting Linux images build process..."
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    # Initial setup

set +u
    Log_Info "Building source build/envsetup.sh"
    if ! source build/envsetup.sh  ; then
        Log_Error "Building source build/envsetup.sh  failed"
        return 1
    fi
set -euo pipefail

    # Log_Info "Building distclean"
    # if ! echo -e "Y\n" |  ./build.sh distclean ; then
    #     Log_Error "Building distclean  failed"
    #     return 1
    # fi

    # Log_Info "Building rm sdk out files"
    # if [ -e "out/${CHIP_NAME}/${PROJECT}"  ]
    # then
    #     rm -rf out/${CHIP_NAME}/${PROJECT}
    #     sync
    # fi

    Log_Info "Building board configuration: $BOARD_CONFIG_AW"
#    if ! echo -e "Y\n" | ./build.sh autoconfig -a ${PLATFORM_AW} -o ${OS_BUILD_ROOTFS} -i ${CHIP_NAME} -b ${PROJECT} -n default -k ${BOARD_CONFIG_AW} ; then
    if ! echo -e "Y\n" | ./build.sh autoconfig  -o ${OS_BUILD_ROOTFS} -i ${CHIP_NAME} -b ${PROJECT} -n default -k ${BOARD_CONFIG_AW} ; then
        Log_Error "Initial build setup failed"
        return 1
    fi
    sync
    # Build components
    for component in "${BUILD_COMPONENTS[@]}"; do
        if ! Build_Component "$component"; then
            Log_Error "Failed to build $component"
            return 1
        fi
    done
        
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    Log_Success "Linux images build completed in $duration seconds"
    return 0
}

function Prepare_Image_Package() {
    Log_Info "Preparing image packages for distribution..."
    Safe_cd "$CURR_PATH" || return 1
    
    # Create image package
    if [[ -d "$VER_IMAGE" ]]; then
        rm -rf "$VER_IMAGE"
    fi
    mkdir -p "$VER_IMAGE"
    
    # Copy tools
    local tools_dirs=("tools/tools_win")
    local tools_copied=false
    for tools_dir in "${tools_dirs[@]}"; do
        if [[ -d "$CURR_PATH/$ROOT_DIR/$tools_dir" ]]; then
            cp -aRL "$CURR_PATH/$ROOT_DIR/$tools_dir"  "$VER_IMAGE/"
            tools_copied=true
            break
        fi
    done
    
    if [[ "$tools_copied" == "false" ]]; then
        Log_Warning "No tools directory found"
    fi

    sync

    # Copy OS
    mkdir -p "$VER_IMAGE/"
    if [ -e $CURR_PATH/$ROOT_DIR/out/*.img ]; then
        cp -aRL $CURR_PATH/$ROOT_DIR/out/*.img  "$VER_IMAGE/$VER_IMAGE"
    else
        Log_Error "out/xxxx.img directory not found"
        return 1
    fi

    sync

    # Create archive
    Log_Info "Creating archive: ${VER_IMAGE}.tgz"
    if ! tar czf "${VER_IMAGE}.tgz" "$VER_IMAGE"; then
        Log_Error "Failed to create image archive"
        return 1
    fi
    
    if ! generate_md5 "${VER_IMAGE}.tgz"; then
        Log_Error "Failed to generate MD5 for image"
        return 1
    fi

    sync
    return 0
}

function Prepare_BSP_Package() {
    Log_Info "Preparing BSP (Board Support Package)..."
    Safe_cd "$CURR_PATH" || return 1
    
    if [[ -d "$VER_BSP" ]]; then
        rm -rf "$VER_BSP"
    fi
    mkdir -p "$VER_BSP"
    
    # Clean and prepare source directories
    local source_dirs=("brandy" "kernel" "bsp" "build" "device" "buildroot" "platform" "prebuilt" "tools")
    
    Safe_cd "$CURR_PATH" || return 1
    
    # Copy BSP components
    for dir in "${source_dirs[@]}"; do
        if [[ -d "$CURR_PATH/$ROOT_DIR/$dir" ]]; then
            if [  "$dir" = "kernel" ];then
                mkdir -p  "$VER_BSP/kernel"
                cp -R "$CURR_PATH/$ROOT_DIR/$dir/$BOARD_CONFIG_AW" "$VER_BSP/kernel/"
            else
                cp -R "$CURR_PATH/$ROOT_DIR/$dir" "$VER_BSP/"
                rm -rf "$VER_BSP/$dir/.git" 2>/dev/null || true
            fi
        fi
    done

    sync
    # Copy build scripts
    local build_files=("build.sh")
    for file in "${build_files[@]}"; do
        if [[ -f "$CURR_PATH/$ROOT_DIR/$file" ]]; then
            cp -d "$CURR_PATH/$ROOT_DIR/$file" "$VER_BSP/"
        fi
    done

    sync
    # Create BSP archive
    Log_Info "Creating archive: ${VER_BSP}.tgz"
    if ! tar czf "${VER_BSP}.tgz" "$VER_BSP"; then
        Log_Error "Failed to create BSP archive"
        return 1
    fi
    
    if ! generate_md5 "${VER_BSP}.tgz"; then
        Log_Error "Failed to generate MD5 for BSP"
        return 1
    fi
    
    return 0
}


function Prepare_Others_Package() {
    Log_Info "Preparing other packages for distribution..."
    Safe_cd "$CURR_PATH" || return 1
    
    # Create image package
    if [[ -d "$VER_OTHERS" ]]; then
        rm -rf "$VER_OTHERS"
    fi
    mkdir -p "$VER_OTHERS"

    # Copy toolchain images
    mkdir -p "$VER_OTHERS/"
    if [[ -d "$CURR_PATH/$ROOT_DIR/out/toolchain" ]]; then

        cp -aRL "$CURR_PATH/$ROOT_DIR/out/toolchain"  "$VER_OTHERS/"
    else
        Log_Error "out/toolchain directory not found"
        return 1
    fi


    # Copy out
    mkdir -p "$VER_OTHERS/out"
    if [[ -d "$CURR_PATH/$ROOT_DIR/out/$CHIP_NAME/$PROJECT" ]]; then
        rsync -a \
                --exclude=buildroot/buildroot/build \
                $CURR_PATH/$ROOT_DIR/out/$CHIP_NAME/$PROJECT/ "$VER_OTHERS/out/"
        sync
    else
        Log_Error "out/  directory not found"
        return 1
    fi
    
    sync
    # Create archive
    Log_Info "Creating archive: ${VER_OTHERS}.tgz"
    if ! tar czf "${VER_OTHERS}.tgz" "$VER_OTHERS"; then
        Log_Error "Failed to create others archive"
        return 1
    fi
    
    if ! generate_md5 "${VER_OTHERS}.tgz"; then
        Log_Error "Failed to generate MD5 for others"
        return 1
    fi

    sync
    return 0
}

function Copy_Image_To_Storage() {
    Log_Info "Copying images to storage: $OUTPUT_DIR"
    Safe_cd "$CURR_PATH" || return 1
    
    # Image package
    if [[ -f "${VER_IMAGE}.tgz" ]]; then
        mv -f "${VER_IMAGE}.tgz" "$OUTPUT_DIR/${PROJECT}/image/"
        mv -f "${VER_IMAGE}.tgz.md5" "$OUTPUT_DIR/${PROJECT}/image/"
    else
        Log_Warning "Image package not found"
        return 1
    fi

    sync
    # BSP package
    if [[ -f "${VER_BSP}.tgz" ]]; then
        mv -f "${VER_BSP}.tgz" "$OUTPUT_DIR/${PROJECT}/bsp/"
        mv -f "${VER_BSP}.tgz.md5" "$OUTPUT_DIR/${PROJECT}/bsp/"
    else
        Log_Warning "BSP package not found"
        return 1
    fi

    sync
    # Others package
    if [[ -f "${VER_OTHERS}.tgz" ]]; then
        mv -f "${VER_OTHERS}.tgz" "$OUTPUT_DIR/${PROJECT}/others/"
        mv -f "${VER_OTHERS}.tgz.md5" "$OUTPUT_DIR/${PROJECT}/others/"
    else
        Log_Warning "Others package not found"
        return 1
    fi

    sync
    Log_Success "Images ,BSP and Others copied to storage successfully"
    return 0
}

function Copy_Log_To_Storage() {
    Log_Info "Collecting and archiving log files..."
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    if [[ -d "$VER_LOG" ]]; then
        rm -rf "$VER_LOG"
    fi
    mkdir -p "$VER_LOG"
    
    # Collect all log files
    for component in "${BUILD_COMPONENTS[@]}"; do
        local log_file="${VER_TAG}_Build_${component}.log"
        if [ -f "$log_file" ]; then
            cp -a "$log_file" "$VER_LOG/"
        fi
    done

    sync
    # Create log archive
    Log_Info "Creating archive: ${VER_LOG}.tgz"
    if ! tar czf "${VER_LOG}.tgz" "$VER_LOG"; then
        Log_Error "Failed to create log archive"
        return 1
    fi
    
    if ! generate_md5 "${VER_LOG}.tgz"; then
        Log_Error "Failed to generate MD5 for log"
        return 1
    fi
    
    # Move to storage
    mv -f "${VER_LOG}.tgz" "$OUTPUT_DIR/${PROJECT}/others/"
    mv -f "${VER_LOG}.tgz.md5" "$OUTPUT_DIR/${PROJECT}/others/"
    
    # Cleanup
    rm -rf "$VER_LOG"

    sync
    Log_Success "Log files archived successfully"
    return 0
}

function Copy_Manifest_To_Storage() {
    Log_Info "Generating and storing manifest..."
    local manifest_dir=".repo/manifests"
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    if ! $REPO manifest -o "${VER_MANIFEST}.xml" -r; then
        Log_Error "Failed to generate manifest"
        return 1
    fi

    sed -i '/name="advantech-azure-priv"/d' "${VER_MANIFEST}.xml"
    sed -i '/remote="advantech-azure-priv"/d' "${VER_MANIFEST}.xml"
    cp "${VER_MANIFEST}.xml" "$OUTPUT_DIR/${PROJECT}/"
    mv "${VER_MANIFEST}.xml" "$manifest_dir/"

    sync
    Log_Success "Manifest stored successfully"
    return 0
}

function Commit_Manifest_And_Version() {
    Log_Info "Committing manifest and version..."
    local manifest_dir=".repo/manifests"
    Safe_cd "$CURR_PATH/$ROOT_DIR/$manifest_dir" || return 1

    if [[ "${VERSION_FIXED}" == "false" ]]; then
        # Create version file
        mkdir -p version
        if [[ "$ROOTFS_AW" == "ubuntu" ]]; then
            cat > "version/${PROJECT}_ubuntu" << EOF
VERSION_K = ${VERSION_K}
VERSION_M = ${VERSION_M}
VERSION_P = ${VERSION_P}
EOF

            git add "version/${PROJECT}_ubuntu"
        else
            cat > "version/${PROJECT}" << EOF
VERSION_K = ${VERSION_K}
VERSION_M = ${VERSION_M}
VERSION_P = ${VERSION_P}
EOF

            git add "version/${PROJECT}"
        fi
    else
        Log_Info "Skip creating version file because VERSION_FIXED is true"
    fi
    
    # Commit changes
    local remote_server
    remote_server=$(git remote -v | grep push | awk '{print $1}')
    
    git add "${VER_MANIFEST}.xml"
    if ! git commit -m "[Official Release] ${VER_TAG}"; then
        Log_Info "INFO: No changes to commit"
    else
        Log_Info "Committing manifest and version to remote..."
        git push $remote_server local:$BSP_BRANCH
    fi
    
    Log_Success "Manifest and version committed successfully"
    return 0
}

function find_max_suffix_of_exist_tag() {
    local max_suffix=0
    local repos_with_tag=()

    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    Log_Info "Finding tag suffix..." >&2

    while IFS= read -r repo_dir; do
        if [[ -n "$repo_dir" ]]; then
            repos_with_tag+=("$repo_dir")
        fi
    done < <($REPO list -p)

    for dir in "${repos_with_tag[@]}"; do
        local full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            Safe_cd "$full_path" || continue
            local old_tag="${VER_TAG}_old"
            local current_suffix=0
            current_suffix=$(git tag -l | grep -c "${old_tag}" || true)
            if [ $current_suffix -gt $max_suffix ]; then
                max_suffix=$current_suffix
            fi
            Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            Log_Warning "Repository directory not found: $full_path" >&2
        fi
    done
    
    # Special repository tag handling
    for dir in "${SPECIAL_GIT_REPOSITORY[@]}"; do
        local full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            Safe_cd "$full_path" || continue
            local old_tag="${VER_TAG}_old"
            local current_suffix=0
            current_suffix=$(git tag -l | grep -c "${old_tag}" || true)
            if [ $current_suffix -gt $max_suffix ]; then
                max_suffix=$current_suffix
            fi
            Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            Log_Warning "Repository directory not found: $full_path" >&2
        fi
    done

    Log_Info "Tag suffix completed, max_suffix=$max_suffix" >&2
    echo $((max_suffix + 1))
}

function rename_exist_tag() {
    local new_tag="$1"
    local remote_server=$(git remote -v | grep push | awk '{print $1}')
    Log_Info "Renaming tag in repository: $(basename "$PWD")"

    # Create new tag pointing to the actual commit (avoid nested tag warning)
    local commit_id
    commit_id=$(git rev-parse "$VER_TAG^{}")
    git tag -a "$new_tag" "$commit_id" -m "[Renamed] Original tag: $VER_TAG"

    # Push new tag to remote
    git push "$remote_server" "$new_tag"

    # Delete local old tag
    git tag -d "$VER_TAG"

    # Try to delete remote old tag, but don't fail if it doesn't exist
    if git ls-remote --tags "$remote_server" | grep -q "refs/tags/$VER_TAG"; then
        git push "$remote_server" --delete "$VER_TAG" || Log_Warning "Failed to delete remote tag $VER_TAG, may already be deleted"
    else
        Log_Info "Remote tag $VER_TAG already deleted"
    fi
    
    Log_Success "Renamed tag: $VER_TAG -> $new_tag"
}

function Commit_Tag() {
    Log_Info "Creating and pushing tags..."
    
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    local suffix
    suffix=$(find_max_suffix_of_exist_tag)
    
    Log_Info "Suffix for old tag is $suffix"
    if [ "$suffix" -le 0 ] || [ "$suffix" -gt 999 ]; then
        Log_Error "Suffix must be 1-999, got $suffix"
        return 1
    fi
    local new_tag="${VER_TAG}_old_$(printf "%03d" "$suffix")"

    # Handle existing tags by renaming them with incrementing suffix
    Log_Info "Checking for existing tags..."
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    local repos_with_tag=()
    while IFS= read -r repo_dir; do
        if [[ -n "$repo_dir" ]]; then
            repos_with_tag+=("$repo_dir")
        fi
    done < <($REPO list -p)
    
    # Rename tags in each repository if the tag exists
    for dir in "${repos_with_tag[@]}"; do
        Log_Info "Processing repository: $dir"

        local full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            Safe_cd "$full_path" || continue
            if git rev-parse "$VER_TAG" >/dev/null 2>&1; then
                rename_exist_tag $new_tag
            fi
            Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            Log_Warning "Repository directory not found: $full_path"
        fi
    done
    
    # Special repository tag handling
    for dir in "${SPECIAL_GIT_REPOSITORY[@]}"; do
        Log_Info "Processing repository: $dir"

        local full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            Safe_cd "$full_path" || continue
            if git rev-parse "$VER_TAG" >/dev/null 2>&1; then
                rename_exist_tag $new_tag
            fi
            Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            Log_Warning "Repository directory not found: $full_path"
        fi
    done
    
    Log_Success "Existing tags checked successfully"
    
    # Create new tags
    Safe_cd "$CURR_PATH/$ROOT_DIR/kernel" || return 1
    local remote_server=$(git remote -v | grep push | awk '{print $1}')
    Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    Log_Info "Creating tag: $VER_TAG"
    if ! $REPO forall -c "git tag -a '$VER_TAG' -m '[Official Release] $VER_TAG'"; then
        Log_Error "Failed to create tags"
        return 1
    fi
    
    if ! $REPO forall -c "git push '$remote_server' '$VER_TAG'"; then
        Log_Error "Failed to push tags"
        return 1
    fi

    # Special repository tag pushing
    for dir in "${SPECIAL_GIT_REPOSITORY[@]}"; do
        local dir_full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$dir_full_path" ]]; then
            Safe_cd "$dir_full_path" || continue
            Log_Info "Creating tag for special repository: $dir"
            remote_server_special=$(git remote -v | grep push | awk '{print $1}')
            git tag -a "$VER_TAG" -m "[Official Release] $VER_TAG"
            git push "$remote_server_special" "$VER_TAG" || Log_Warning "Failed to push tag for $dir"
            Safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            Log_Warning "Special repository directory not found: $dir_full_path"
        fi
    done
    
    Log_Success "Tags created successfully"
    return 0
}

# ================
#  Main Procedure
# ================

function main() {
    local start_time=$(date +%s)

    Log_Info "Build script version: $SCRIPT_VERSION"
    Log_Info "Build process started at $(Get_Timestamp)"
    
    # Execute steps in order
    local steps=(
        "Validate_Environment"
        "Create_Root_Dir"
        "Get_First_Project"
        "Get_Source_Code"
        "Get_Adv_Version"
        "Get_Kernel_Version"
        "Init_Global_Variable"
        "Dump_Global_Variable"
        "Create_Output_Dir"
        "Build_Linux_Images"
        "Prepare_Image_Package"
        "Prepare_BSP_Package"
        "Prepare_Others_Package"
        "Copy_Image_To_Storage"
        "Copy_Log_To_Storage"
        "Copy_Manifest_To_Storage"
        "Commit_Manifest_And_Version"
        "Commit_Tag"
    )

    local total_steps=${#steps[@]}
    local current_step=0
    
    for step in "${steps[@]}"; do
        ((current_step++))
        echo "📋 [ADV] === Step $current_step/$total_steps: $step ==="
        if ! $step; then
            Log_Error "Step $current_step: $step failed at $(Get_Timestamp)"
            return 1
        fi
        echo "✅ [ADV] ✓ Step $current_step: $step completed successfully"
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    Log_Success "Build process completed in $duration seconds"
    return 0
}

# Execute main function
if main; then
    echo "🎉 [ADV] Build script completed successfully!"
    exit 0
else
    echo "💥 [ADV] Build script failed!"
    exit 1
fi
