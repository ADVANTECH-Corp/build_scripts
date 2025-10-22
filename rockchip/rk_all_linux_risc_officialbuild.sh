#!/bin/bash

#
# FILE: rk_all_linux_risc_officialbuild.sh
# PURPOSE: Auto build on azure pipeline
# AUTHOR: Yunjin Jiang <yunjin.jiang@advantech.com.cn>
# VERSION HISTORY:
#   1.0.0 2025-10-17 Initial release
#

## MODIFICATION DETAILS:
# Date       Version Author          Changes
# 2024-01-10 1.0.0   Yunjin Jiang    Initial implementation
# 



# ===========
#  Strict Error Handling
# ===========
set -euo pipefail

# ===========
#  Global Variables
# ===========
declare -g SCRIPT_VERSION="1.0.0"

declare -g REPO="repo"
declare -g VERSION_K="" VERSION_M="" VERSION_P=""
declare -g VERSION_K_LAST="" VERSION_M_LAST="" VERSION_P_LAST=""
declare -g KERNEL_VERSION="" ADV_VERSION=""
declare -g RAM_SIZE="all" STORAGE="all"
declare -g FIRST_PROJECT="true"
declare -g CURR_PATH="$PWD"
declare -g ROOT_DIR="${OS_DISTRO}_${DATE}"
declare -g ROOTFS="${ROOTFS:-debian}"  # Default value is debian

# Read-only arrays
readonly SPECIAL_GIT_REPOSITORY=(".repo/manifests" "u-boot_priv")
readonly BUILD_COMPONENTS=("uboot" "kernel" "rootfs" "recovery" "misc" "firmware")
readonly REQUIRED_VARS=(
    "BSP_URL" "BSP_BRANCH" "BSP_XML"
    "DATE" "STORED"
    "SDK_VERSION" "OS_DISTRO" "CHIP_NAME"
    "VERSION_TYPE" "VERSION_FIXED"
    "PROJECT" "PROJECT_LIST" "BOARD_CONFIG"
)

# ===========
#  Functions
# ===========

# Logging functions
function get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

function log_info() {
    echo "[ADV][$(get_timestamp)] INFO: $1"
}

function log_warning() {
    echo "⚠️ [ADV][$(get_timestamp)] WARNING: $1"
}

function log_error() {
    echo "❌ [ADV][$(get_timestamp)] ERROR: $1"
}

function log_success() {
    echo "✅ [ADV][$(get_timestamp)] SUCCESS: $1"
}

# Error handling function
function handle_error() {
    local exit_code=$?
    local line_no=$1
    local command=$2
    log_error "Command failed at line $line_no: $command (exit code: $exit_code)"
    exit $exit_code
}

trap 'handle_error ${LINENO} "$BASH_COMMAND"' ERR

# Safe directory change function
function safe_cd() {
    local target_dir="$1"
    if ! cd "$target_dir"; then
        log_error "Failed to enter directory: $target_dir"
        return 1
    fi
    return 0
}

# Validate and set ROOTFS
function validate_and_set_rootfs() {
    log_info "Validating ROOTFS configuration..."
    
    # If ROOTFS is empty, set to debian
    if [[ -z "${ROOTFS}" ]]; then
        ROOTFS="debian"
        log_info "ROOTFS not set, using default: $ROOTFS"
        return 0
    fi
    
    # Check if ROOTFS is a supported value
    case "${ROOTFS}" in
        "debian"|"ubuntu"|"yocoto"|"buildroot")
            log_info "Using specified ROOTFS: $ROOTFS"
            ;;
        *)
            log_warning "Unsupported ROOTFS '$ROOTFS', falling back to 'debian'"
            ROOTFS="debian"
            ;;
    esac
    
    log_info "Final ROOTFS configuration: $ROOTFS"
    return 0
}

# Validate required environment variables
function validate_environment() {
    local missing_vars=()
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [[ -z "${!var}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Required variables not set: ${missing_vars[*]}"
        return 1
    fi

    # Validate VERSION_TYPE
    local version_type_lower="${VERSION_TYPE,,}"
    case "$version_type_lower" in
        "ga"|"beta"|"alpha")
            log_info "Valid VERSION_TYPE: $VERSION_TYPE"
            ;;
        *)
            log_error "Invalid VERSION_TYPE '$VERSION_TYPE'. Must be 'GA', 'Beta' or 'Alpha'"
            return 1
            ;;
    esac
    # Convert VERSION_TYPE to lowercase
    VERSION_TYPE="$version_type_lower"
    
    # Validate VERSION_FIXED
    local version_fixed_lower="${VERSION_FIXED,,}"
    case "$version_fixed_lower" in
        "true"|"false")
            log_info "Valid VERSION_FIXED: $VERSION_FIXED"
            ;;
        *)
            log_error "Invalid VERSION_FIXED '$VERSION_FIXED'. Must be 'true' or 'false'"
            return 1
            ;;
    esac
    # Convert VERSION_FIXED to lowercase
    VERSION_FIXED="$version_fixed_lower"

    validate_and_set_rootfs
    log_success "All required environment variables are set"
}

function create_root_dir() {
    local target_dir="$CURR_PATH/$ROOT_DIR"
    
    if [[ -e "$target_dir" ]]; then
        log_info "Directory already exists: $target_dir"
    else
        log_info "Creating root directory: $target_dir"
        if ! mkdir -p "$target_dir"; then
            log_error "Failed to create directory: $target_dir"
            return 1
        fi
    fi
    
    safe_cd "$target_dir" || return 1
}

function create_output_dir() {
    safe_cd "$CURR_PATH" || return 1
    
    local output_subdirs=("bsp" "image" "others")
    
    for subdir in "${output_subdirs[@]}"; do
        local full_path="$OUTPUT_DIR/${PROJECT}/$subdir"
        if [[ -e "$full_path" ]]; then
            log_info "Directory exists: $full_path"
        else
            log_info "Creating directory: $full_path"
            if ! mkdir -p "$full_path"; then
                log_error "Failed to create directory: $full_path"
                return 1
            fi
        fi
    done

    return 0
}

function get_first_project() {
    local idx=0

    for _ in $PROJECT_LIST; do
        ((idx++)) || true
    done
    
    if [[ $idx -gt 1 ]]; then
        FIRST_PROJECT="false"
    else
        FIRST_PROJECT="true"
    fi
    
    log_info "First project flag: $FIRST_PROJECT"

    return 0
}

function get_adv_version() {
    local version_file="$CURR_PATH/$ROOT_DIR/.repo/manifests/version/${PROJECT}"
    
    if [[ ! -f "$version_file" ]]; then
        VERSION_K_LAST="0"
        VERSION_M_LAST="0"
        VERSION_P_LAST="0"
        log_info "No previous version file found, starting from 0.0.0"
    else
        VERSION_K_LAST=$(grep -E '^VERSION_K\s*=' "$version_file" | sed -E 's/.*=\s*([0-9]+).*/\1/' | head -1)
        VERSION_M_LAST=$(grep -E '^VERSION_M\s*=' "$version_file" | sed -E 's/.*=\s*([0-9]+).*/\1/' | head -1)
        VERSION_P_LAST=$(grep -E '^VERSION_P\s*=' "$version_file" | sed -E 's/.*=\s*([0-9]+).*/\1/' | head -1)

        log_info "Previous version: $VERSION_K_LAST.$VERSION_M_LAST.$VERSION_P_LAST"
    fi
    
    # Validate version numbers are numeric
    if ! [[ "$VERSION_K_LAST" =~ ^[0-9]+$ ]] || ! [[ "$VERSION_M_LAST" =~ ^[0-9]+$ ]] || ! [[ "$VERSION_P_LAST" =~ ^[0-9]+$ ]]; then
        log_error "Invalid version format detected: VERSION_K_LAST='$VERSION_K_LAST', VERSION_M_LAST='$VERSION_M_LAST', VERSION_P_LAST='$VERSION_P_LAST'"
        log_error "Please check the version file: '.repo/manifests/version/${PROJECT}'"
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
            log_error "Invalid VERSION_TYPE '$VERSION_TYPE'. Must be 'ga', 'beta' or 'alpha'"
            return 1
            ;;
    esac

    ADV_VERSION="${VERSION_K}.${VERSION_M}.${VERSION_P}"
    log_info "New version: $ADV_VERSION"

    return 0
}

function get_kernel_version() {
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    local makefile="$CURR_PATH/$ROOT_DIR/kernel/Makefile"
    if [[ ! -f "$makefile" ]]; then
        log_error "Makefile not found in kernel directory"
        return 1
    fi
    
    local version patchlevel sublevel extraversion
    version=$(grep -E '^VERSION\s*=' "$makefile" | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/')
    patchlevel=$(grep -E '^PATCHLEVEL\s*=' "$makefile" | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/')
    sublevel=$(grep -E '^SUBLEVEL\s*=' "$makefile" | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/')
    extraversion=$(grep -E '^EXTRAVERSION\s*=' "$makefile" | head -1 | sed -E 's/.*=\s*([^#]*).*/\1/' | tr -d ' ')
    
    KERNEL_VERSION="${version}.${patchlevel}.${sublevel}${extraversion}"
    log_info "Kernel version: $KERNEL_VERSION"
    return 0
}

function init_global_variable() {
    OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}/v${SDK_VERSION}.${ADV_VERSION}"
    
    VER_TAG="${PROJECT}_${OS_DISTRO}_v${ADV_VERSION}_kernel-${KERNEL_VERSION}_${CHIP_NAME}"
    VER_MANIFEST="${VER_TAG}"
    VER_LOG="${VER_TAG}_${RAM_SIZE}_${STORAGE}_${DATE}.log"
    VER_IMAGE="${VER_TAG}_${RAM_SIZE}_${STORAGE}_${DATE}.img"
    VER_BSP="${VER_TAG}_${RAM_SIZE}_${STORAGE}_${DATE}.bsp"
    
    log_success "Global variables initialized successfully"

    return 0
}

function print_config() {
    printf "%-18s: %s\n" "$1" "$2"
}

function dump_global_variable() {
    log_info "Build Configuration"
    echo "================================="
    print_config "DATE" "$DATE"
    print_config "STORED" "$STORED"
    print_config "BSP_URL" "$BSP_URL"
    print_config "BSP_BRANCH" "$BSP_BRANCH"
    print_config "BSP_XML" "$BSP_XML"
    print_config "PROJECT" "$PROJECT"
    print_config "PROJECT_LIST" "$PROJECT_LIST"
    print_config "VERSION_TYPE" "$VERSION_TYPE"
    print_config "VERSION_FIXED" "$VERSION_FIXED"
    print_config "SDK_VERSION" "$SDK_VERSION"
    print_config "PREVIOUS_VERSION" "${VERSION_K_LAST}.${VERSION_M_LAST}.${VERSION_P_LAST}"
    print_config "ADV_VERSION" "$ADV_VERSION"
    print_config "KERNEL_VERSION" "$KERNEL_VERSION"
    print_config "ROOTFS" "$ROOTFS"
    print_config "VER_TAG" "$VER_TAG"
    print_config "OUTPUT_DIR" "$OUTPUT_DIR"
    echo "================================="

    return 0
}

function get_source_code() {
    log_info "Fetching $CHIP_NAME $OS_DISTRO source code"
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    if [[ $FIRST_PROJECT != "true" ]]; then
        log_info "Reusing existing source code (FIRST_PROJECT=$FIRST_PROJECT)"
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
    
    log_info "Executing: $repo_cmd"
    if ! $repo_cmd; then
        log_error "repo init failed"
        return 1
    fi
    
    log_info "Syncing repositories..."
    if ! $REPO sync; then
        log_error "repo sync failed"
        return 1
    fi
    
    # Setup tracking branches
    local remote_server
    cd "u-boot"
    remote_server=$(git remote -v | grep push | awk '{print $1}')
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    log_info "Creating local tracking branches..."
    if ! $REPO forall -c "git checkout -b local --track $remote_server/$BSP_BRANCH"; then
        log_warning "Failed to create tracking branches"
    fi

    log_info "Creating local tracking branches for manifests..."
    safe_cd ".repo/manifests" || return 1
    git branch -D local
    remote_server=$(git remote -v | grep push | awk '{print $1}')
    if ! git checkout -b local --track $remote_server/$BSP_BRANCH; then
        log_warning "Failed to create tracking branches for .repo/manifests"
    fi
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    safe_cd "$CURR_PATH" || return 1
    log_success "Source code preparation completed successfully"

    return 0
}

function generate_md5() {
    local filename="$1"
    
    if [[ -e "$filename" ]]; then
        log_info "Generating MD5 for: $filename"
        md5sum -b "$filename" | cut -d ' ' -f 1 > "${filename}.md5"
    else
        log_warning "File not found for MD5 generation: $filename"
        return 1
    fi
    return 0
}

function install_build_dependencies() {
    log_info "Installing/updating build dependencies..."

    if [[ $FIRST_PROJECT != "true" ]]; then
        log_info "Build dependencies already installed (FIRST_PROJECT=$FIRST_PROJECT)"
        return 0
    fi

    # install live-build
    log_info "Installing live-build..."
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    if [[ -d "live-build" ]]; then
        rm -rf live-build
    fi
    
    if ! git clone https://salsa.debian.org/live-team/live-build.git --depth 1 -b debian/1%20230131; then
        log_error "Failed to clone live-build"
        return 1
    fi
    
    safe_cd "live-build" || return 1
    rm -rf manpages/po/
    if ! sudo make install -j8; then
        log_error "Failed to install live-build"
        safe_cd "$CURR_PATH/$ROOT_DIR/" || return 1
        if [[ -d "live-build" ]]; then
            rm -rf live-build
        fi
        return 1
    fi
    
    safe_cd "$CURR_PATH/$ROOT_DIR/" || return 1
    if [[ -d "live-build" ]]; then
        rm -rf live-build
    fi
	log_success "live-build installed successfully"

    # install qemu
    sudo apt-get update
    sudo apt-get install binfmt-support qemu-user-static --reinstall
    sudo update-binfmts --enable qemu-aarch64

	log_success "All build dependencies installed successfully"
    return 0
}

function apply_kernel_patch() {
    log_info "Applying kernel patches..."
    if [[ ${RT_PATCH:-} == "true" ]]; then
        log_info "Applying real-time (RT) patch..."
        git apply patch/RT/*.patch
        log_success "RT patch applied successfully"
    fi
    
    if [[ ${ETHERCAT:-} == "true" ]]; then
        log_info "Applying EtherCAT driver patch..."
        local TARGET_LINE="obj-m += ethercat/"
        local TARGET_PATH="drivers/net/ethernet/stmicro"

        if [ -d "ethercat" ]; then
            log_info "Deleting old EtherCAT driver"
            rm -rf ethercat
        fi

        log_info "Cloning EtherCAT driver repository"
        git clone ${ETHERCAT_HUB} -b ${ETHERCAT_BRH} ethercat

        log_info "Integrating EtherCAT driver into kernel"
        cp -rf ethercat/ $TARGET_PATH
        rm -rf ethercat/
        sync

        log_info "Updating the Makefile"
        if ! grep -Fxq "$TARGET_LINE" "$TARGET_PATH/Makefile"; then
            echo "$TARGET_LINE" >> "$TARGET_PATH/Makefile"
            log_success "Makefile configuration updated"
        fi
        log_success "EtherCAT driver patch applied successfully"
    fi
    log_success "All kernel patches applied successfully"
}

function build_component() {
    local component="$1"
    
    # Validate component parameter
    if [[ -z "$component" ]]; then
        log_error "Component name is required"
        return 1
    fi
    
    # Check if component is in BUILD_COMPONENTS
    if [[ ! " ${BUILD_COMPONENTS[@]} " =~ " ${component} " ]]; then
        log_error "Invalid component: $component"
        return 1
    fi
    
    local log_file="${VER_TAG}_Build_${component}.log"
    local start_time end_time duration
    
    log_info "Building component: $component"
    start_time=$(date +%s)
    
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    # Define success pattern matching
    local -A success_patterns=(
        ["uboot"]="build_uboot succeeded"
        ["kernel"]="build_kernel succeeded"
        ["recovery"]="build_recovery succeeded"
        ["rootfs"]="build_rootfs (debian|ubuntu) succeeded"
        ["misc"]="build_misc succeeded"
        ["firmware"]="build_firmware succeeded"
    )

    local build_status=0
    case $component in
        "uboot")
            safe_cd "u-boot"
            make clean 2>/dev/null || true
            git add . -f 2>/dev/null || true
            git reset --hard 2>/dev/null || true
            echo " V${SDK_VERSION}.${ADV_VERSION}" > .scmversion
            safe_cd ".."
            ;;
        "kernel")
            safe_cd "kernel"
            make clean 2>/dev/null || true
            git add . -f 2>/dev/null || true
            git reset --hard 2>/dev/null || true
            apply_kernel_patch
            safe_cd ".."
            ;;
        "recovery")
            rm -rf buildroot/output/rockchip_rk*_recovery
            ;;
        "rootfs")
            if ! install_build_dependencies; then
                log_error "Failed to install build dependencies"
                return 1
            fi
            ;;
    esac
    
    # Unified build command execution
    local build_cmd="./build.sh $component"
    if [[ $component == "rootfs" ]]; then
        if [[ "$ROOTFS" == "ubuntu" ]]; then
            build_cmd="./build.sh ubuntu"
        else
            build_cmd="./build.sh debian"
        fi
    fi
    
    log_info "Executing: $build_cmd"
    {
        log_info "Build started at: $(get_timestamp)"
        if ! $build_cmd; then
            build_status=1
        fi
        log_info "Build finished at: $(get_timestamp)"
    } > >(tee "$log_file") 2>&1

    # Check build success pattern
    local pattern="${success_patterns[$component]}"
    if [[ -n "$pattern" ]] && ! grep -q -E "$pattern" "$log_file"; then
        build_status=1
    fi

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    
    if [[ $build_status -ne 0 ]]; then
        log_error "$component build failed after $duration seconds. Check log: $log_file"
        return 1
    else
        log_success "$component build completed in $duration seconds"
    fi
    
    return 0
}

function build_linux_images() {
    local start_time end_time duration
    start_time=$(date +%s)
    
    log_info "Starting Linux images build process..."
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    # Initial setup
    log_info "Building board configuration: $BOARD_CONFIG"
    if ! ./build.sh "$BOARD_CONFIG"; then
        log_error "Initial build setup failed"
        return 1
    fi
    
    # Build components
    for component in "${BUILD_COMPONENTS[@]}"; do
        if ! build_component "$component"; then
            log_error "Failed to build $component"
            return 1
        fi
    done
        
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    log_success "Linux images build completed in $duration seconds"
    return 0
}

function prepare_image_package() {
    log_info "Preparing image packages for distribution..."
    safe_cd "$CURR_PATH" || return 1
    
    # Create image package
    if [[ -d "$VER_IMAGE" ]]; then
        rm -rf "$VER_IMAGE"
    fi
    mkdir -p "$VER_IMAGE"
    
    # Copy tools
    local tools_dirs=("tools/windows/RKDevTool" "tools/windows/AndroidTool")
    local tools_copied=false
    for tools_dir in "${tools_dirs[@]}"; do
        if [[ -d "$CURR_PATH/$ROOT_DIR/$tools_dir" ]]; then
            cp -aRL "$CURR_PATH/$ROOT_DIR/$tools_dir"/* "$VER_IMAGE/"
            tools_copied=true
            break
        fi
    done
    
    if [[ "$tools_copied" == "false" ]]; then
        log_warning "No tools directory found"
    fi
    
    # Copy drivers and tools
    cp -aRL "$CURR_PATH/$ROOT_DIR"/tools/windows/DriverAssitant_*.zip "$VER_IMAGE/" 2>/dev/null || true
    cp -aRL "$CURR_PATH/$ROOT_DIR"/tools/windows/SDDiskTool_*.zip "$VER_IMAGE/" 2>/dev/null || true
    
    # Copy rockdev images
    mkdir -p "$VER_IMAGE/rockdev/image"
    if [[ -d "$CURR_PATH/$ROOT_DIR/rockdev" ]]; then
        if [[ -f "$CURR_PATH/$ROOT_DIR/rockdev/update.img" ]]; then
            rm "$CURR_PATH/$ROOT_DIR/rockdev/update.img"
        fi
        cp -aRL "$CURR_PATH/$ROOT_DIR/rockdev"/* "$VER_IMAGE/rockdev/image/"
    else
        log_error "rockdev directory not found"
        return 1
    fi
    
    # Create archive
    log_info "Creating archive: ${VER_IMAGE}.tgz"
    if ! tar czf "${VER_IMAGE}.tgz" "$VER_IMAGE"; then
        log_error "Failed to create image archive"
        return 1
    fi
    
    if ! generate_md5 "${VER_IMAGE}.tgz"; then
        log_error "Failed to generate MD5 for image"
        return 1
    fi
    
    return 0
}

function prepare_bsp_package() {
    log_info "Preparing BSP (Board Support Package)..."
    safe_cd "$CURR_PATH" || return 1
    
    if [[ -d "$VER_BSP" ]]; then
        rm -rf "$VER_BSP"
    fi
    mkdir -p "$VER_BSP"
    
    # Clean and prepare source directories
    local source_dirs=("u-boot" "kernel" "rkbin" "prebuilts" "device")
    for dir in "${source_dirs[@]}"; do
        if [[ -d "$CURR_PATH/$ROOT_DIR/$dir" ]]; then
            safe_cd "$CURR_PATH/$ROOT_DIR/$dir" || continue
            make clean 2>/dev/null || true
            git add . -f 2>/dev/null || true
            git reset --hard 2>/dev/null || true
            
            if [[ "$dir" == "u-boot" ]]; then
                echo " V${SDK_VERSION}.${ADV_VERSION}" > .scmversion
            fi
        fi
    done
    
    safe_cd "$CURR_PATH" || return 1
    
    # Copy BSP components
    for dir in "${source_dirs[@]}"; do
        if [[ -d "$CURR_PATH/$ROOT_DIR/$dir" ]]; then
            cp -R "$CURR_PATH/$ROOT_DIR/$dir" "$VER_BSP/"
            rm -rf "$VER_BSP/$dir/.git" 2>/dev/null || true
        fi
    done
    
    # Copy build scripts
    local build_files=("build.sh" "Makefile" "rkflash.sh")
    for file in "${build_files[@]}"; do
        if [[ -f "$CURR_PATH/$ROOT_DIR/$file" ]]; then
            cp -d "$CURR_PATH/$ROOT_DIR/$file" "$VER_BSP/"
        fi
    done
    
    # Create BSP archive
    log_info "Creating archive: ${VER_BSP}.tgz"
    if ! tar czf "${VER_BSP}.tgz" "$VER_BSP"; then
        log_error "Failed to create BSP archive"
        return 1
    fi
    
    if ! generate_md5 "${VER_BSP}.tgz"; then
        log_error "Failed to generate MD5 for BSP"
        return 1
    fi
    
    return 0
}

function copy_image_to_storage() {
    log_info "Copying images to storage: $OUTPUT_DIR"
    safe_cd "$CURR_PATH" || return 1
    
    # Image package
    if [[ -f "${VER_IMAGE}.tgz" ]]; then
        mv -f "${VER_IMAGE}.tgz" "$OUTPUT_DIR/${PROJECT}/image/"
        mv -f "${VER_IMAGE}.tgz.md5" "$OUTPUT_DIR/${PROJECT}/image/"
    else
        log_warning "Image package not found"
        return 1
    fi
    
    # BSP package
    if [[ -f "${VER_BSP}.tgz" ]]; then
        mv -f "${VER_BSP}.tgz" "$OUTPUT_DIR/${PROJECT}/bsp/"
        mv -f "${VER_BSP}.tgz.md5" "$OUTPUT_DIR/${PROJECT}/bsp/"
    else
        log_warning "BSP package not found"
        return 1
    fi
    
    log_success "Images and BSP copied to storage successfully"
    return 0
}

function copy_log_to_storage() {
    log_info "Collecting and archiving log files..."
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
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
    
    # Create log archive
    log_info "Creating archive: ${VER_LOG}.tgz"
    if ! tar czf "${VER_LOG}.tgz" "$VER_LOG"; then
        log_error "Failed to create log archive"
        return 1
    fi
    
    if ! generate_md5 "${VER_LOG}.tgz"; then
        log_error "Failed to generate MD5 for log"
        return 1
    fi
    
    # Move to storage
    mv -f "${VER_LOG}.tgz" "$OUTPUT_DIR/${PROJECT}/others/"
    mv -f "${VER_LOG}.tgz.md5" "$OUTPUT_DIR/${PROJECT}/others/"
    
    # Cleanup
    rm -rf "$VER_LOG"
    
    log_success "Log files archived successfully"
    return 0
}

function copy_manifest_to_storage() {
    log_info "Generating and storing manifest..."
    local manifest_dir=".repo/manifests"
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    if ! $REPO manifest -o "${VER_MANIFEST}.xml" -r; then
        log_error "Failed to generate manifest"
        return 1
    fi

    sed -i '/name="advantech-azure-priv"/d' "${VER_MANIFEST}.xml"
    sed -i '/remote="advantech-azure-priv"/d' "${VER_MANIFEST}.xml"
    cp "${VER_MANIFEST}.xml" "$OUTPUT_DIR/${PROJECT}/"
    mv "${VER_MANIFEST}.xml" "$manifest_dir/"
    
    log_success "Manifest stored successfully"
    return 0
}

function commit_manifest_and_version() {
    log_info "Committing manifest and version..."
    local manifest_dir=".repo/manifests"
    safe_cd "$CURR_PATH/$ROOT_DIR/$manifest_dir" || return 1

    if [[ "${VERSION_FIXED}" == "false" ]]; then
        # Create version file
        mkdir -p version
        cat > "version/${PROJECT}" << EOF
VERSION_K = ${VERSION_K}
VERSION_M = ${VERSION_M}
VERSION_P = ${VERSION_P}
EOF

        git add "version/${PROJECT}"
    else
        log_info "Skip creating version file because VERSION_FIXED is true"
    fi
    
    # Commit changes
    local remote_server
    remote_server=$(git remote -v | grep push | awk '{print $1}')
    
    git add "${VER_MANIFEST}.xml"
    if ! git commit -m "[Official Release] ${VER_TAG}"; then
        log_info "INFO: No changes to commit"
    else
        log_info "Committing manifest and version to remote..."
        git push $remote_server local:$BSP_BRANCH
    fi
    
    log_success "Manifest and version committed successfully"
    return 0
}

function find_max_suffix_of_exist_tag() {
    local max_suffix=0
    local repos_with_tag=()

    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1

    log_info "Finding tag suffix..." >&2

    while IFS= read -r repo_dir; do
        if [[ -n "$repo_dir" ]]; then
            repos_with_tag+=("$repo_dir")
        fi
    done < <($REPO list -p)

    for dir in "${repos_with_tag[@]}"; do
        local full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            safe_cd "$full_path" || continue
            local old_tag="${VER_TAG}_old"
            local current_suffix=0
            current_suffix=$(git tag -l | grep -c "${old_tag}" || true)
            if [ $current_suffix -gt $max_suffix ]; then
                max_suffix=$current_suffix
            fi
            safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            log_warning "Repository directory not found: $full_path" >&2
        fi
    done
    
    # Special repository tag handling
    for dir in "${SPECIAL_GIT_REPOSITORY[@]}"; do
        local full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            safe_cd "$full_path" || continue
            local old_tag="${VER_TAG}_old"
            local current_suffix=0
            current_suffix=$(git tag -l | grep -c "${old_tag}" || true)
            if [ $current_suffix -gt $max_suffix ]; then
                max_suffix=$current_suffix
            fi
            safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            log_warning "Repository directory not found: $full_path" >&2
        fi
    done

    log_info "Tag suffix completed, max_suffix=$max_suffix" >&2
    echo $((max_suffix + 1))
}

function rename_exist_tag() {
    local new_tag="$1"
    local remote_server=$(git remote -v | grep push | awk '{print $1}')
    log_info "Renaming tag in repository: $(basename "$PWD")"

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
        git push "$remote_server" --delete "$VER_TAG" || log_warning "Failed to delete remote tag $VER_TAG, may already be deleted"
    else
        log_info "Remote tag $VER_TAG already deleted"
    fi
    
    log_success "Renamed tag: $VER_TAG -> $new_tag"
}

function commit_tag() {
    log_info "Creating and pushing tags..."
    
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    
    local suffix
    suffix=$(find_max_suffix_of_exist_tag)
    
    log_info "Suffix for old tag is $suffix"
    if [ "$suffix" -le 0 ] || [ "$suffix" -gt 999 ]; then
        log_error "Suffix must be 1-999, got $suffix"
        return 1
    fi
    local new_tag="${VER_TAG}_old_$(printf "%03d" "$suffix")"

    # Handle existing tags by renaming them with incrementing suffix
    log_info "Checking for existing tags..."
    safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
    local repos_with_tag=()
    while IFS= read -r repo_dir; do
        if [[ -n "$repo_dir" ]]; then
            repos_with_tag+=("$repo_dir")
        fi
    done < <($REPO list -p)
    
    # Rename tags in each repository if the tag exists
    for dir in "${repos_with_tag[@]}"; do
        log_info "Processing repository: $dir"

        local full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            safe_cd "$full_path" || continue
            if git rev-parse "$VER_TAG" >/dev/null 2>&1; then
                rename_exist_tag $new_tag
            fi
            safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            log_warning "Repository directory not found: $full_path"
        fi
    done
    
    # Special repository tag handling
    for dir in "${SPECIAL_GIT_REPOSITORY[@]}"; do
        log_info "Processing repository: $dir"

        local full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$full_path" ]]; then
            safe_cd "$full_path" || continue
            if git rev-parse "$VER_TAG" >/dev/null 2>&1; then
                rename_exist_tag $new_tag
            fi
            safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            log_warning "Repository directory not found: $full_path"
        fi
    done
    
    log_success "Existing tags checked successfully"
    
    # Create new tags
    log_info "Creating tag: $VER_TAG"
    if ! $REPO forall -c "git tag -a '$VER_TAG' -m '[Official Release] $VER_TAG'"; then
        log_error "Failed to create tags"
        return 1
    fi
    
    if ! $REPO forall -c "git push '$remote_server' '$VER_TAG'"; then
        log_error "Failed to push tags"
        return 1
    fi
    
    # Special repository tag pushing
    for dir in "${SPECIAL_GIT_REPOSITORY[@]}"; do
        local dir_full_path="$CURR_PATH/$ROOT_DIR/$dir"
        if [[ -d "$dir_full_path" ]]; then
            safe_cd "$dir_full_path" || continue
            log_info "Creating tag for special repository: $dir"
            remote_server_special=$(git remote -v | grep push | awk '{print $1}')
            git tag -a "$VER_TAG" -m "[Official Release] $VER_TAG"
            git push "$remote_server_special" "$VER_TAG" || log_warning "Failed to push tag for $dir"
            safe_cd "$CURR_PATH/$ROOT_DIR" || return 1
        else
            log_warning "Special repository directory not found: $dir_full_path"
        fi
    done
    
    log_success "Tags created successfully"
    return 0
}

# ================
#  Main Procedure
# ================

function main() {
    local start_time=$(date +%s)

    log_info "Build script version: $SCRIPT_VERSION"
    log_info "Build process started at $(get_timestamp)"
    
    # Execute steps in order
    local steps=(
        "validate_environment"
        "create_root_dir"
        "get_first_project"
        "get_source_code"
        "get_adv_version"
        "get_kernel_version"
        "init_global_variable"
        "dump_global_variable"
        "create_output_dir"
        "build_linux_images"
        "prepare_image_package"
        "prepare_bsp_package"
        "copy_image_to_storage"
        "copy_log_to_storage"
        "copy_manifest_to_storage"
        "commit_manifest_and_version"
        "commit_tag"
    )
    
    local total_steps=${#steps[@]}
    local current_step=0
    
    for step in "${steps[@]}"; do
        ((current_step++))
        echo "📋 [ADV] === Step $current_step/$total_steps: $step ==="
        if ! $step; then
            log_error "Step $current_step: $step failed at $(get_timestamp)"
            return 1
        fi
        echo "✅ [ADV] ✓ Step $current_step: $step completed successfully"
    done
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_success "Build process completed in $duration seconds"
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
