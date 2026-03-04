#!/usr/bin/env bash

echo "Start CVE generate process"

CURR_PATH="$PWD"
ROOT_DIR="${PLATFORM_PREFIX}_${TARGET_BOARD}_${RELEASE_VERSION}_${DATE}"
OUTPUT_DIR="${CURR_PATH}/${STORED}/${DATE}"
LINUX_TEGRA="Linux_for_Tegra"
#IMAGE_VER="${PROJECT}_${OS_VERSION}${RELEASE_VERSION}_${KERNEL_VERSION}_${SOC_MEM}_${STORAGE}_${DATE}"
IMAGE_VER="${PROJECT}_${OS_VERSION}_v${RELEASE_VERSION}_${KERNEL_VERSION}_${TARGET_BOARD}_${SOC_MEM}_${STORAGE}_${DATE}"


set -euo pipefail

# =========================
# Config (edit if needed)
# =========================
BASE_IMAGE="nvcr.io/nvidia/l4t-jetpack:r36.4.0"
QEMU_IMAGE="multiarch/qemu-user-static:latest"
TAG_NAME="nv_cve_docker_image"
PLATFORM="linux/arm64"
DOCKERFILE_PATH="./Dockerfile"
ROOTFS_DIR="./Linux_for_Tegra/rootfs"

# If you want a specific buildx builder name, set it here:
BUILDER_NAME="nv-buildx"

# =========================
# Helpers
# =========================
log() { echo -e "\n[INFO] $*\n"; }
err() { echo -e "\n[ERROR] $*\n" >&2; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing command: $1"; exit 1; }
}

# =========================
# Preflight
# =========================
need_cmd sudo
need_cmd apt
need_cmd docker

if [ ! -f "${CURR_PATH}/${IMAGE_VER}.tgz" ]; then
    log "[ERROR] Image not found: ${CURR_PATH}/${IMAGE_VER}.tgz"
    exit 1
fi

sudo tar -zxvf ${CURR_PATH}/${IMAGE_VER}.tgz


if [[ ! -d "${ROOTFS_DIR}" ]]; then
  err "Rootfs directory not found: ${ROOTFS_DIR}"
  err "Expected: ${ROOTFS_DIR} (used by Dockerfile: COPY Linux_for_Tegra/rootfs/ /)"
  exit 1
fi

# =========================
# 1) Pull base image
# =========================
log "Pull base image: ${BASE_IMAGE}"
sudo docker pull "${BASE_IMAGE}"

# =========================
# 2) Install qemu-user-static + binfmt-support
# =========================
log "Install qemu-user-static and binfmt-support"
sudo apt update
sudo apt install -y qemu-user-static binfmt-support

# =========================
# 3) Register binfmt for multiarch (QEMU)
# =========================
log "Register binfmt via ${QEMU_IMAGE}"
sudo docker run --rm --privileged "${QEMU_IMAGE}" --reset -p yes

# =========================
# 4) Create Dockerfile in current folder
# =========================
log "Generate Dockerfile: ${DOCKERFILE_PATH}"
cat > "${DOCKERFILE_PATH}" <<'EOF'
# Dockerfile

# 1) First start from nvcr.io/nvidia/l4t-jetpack:r36.4.0
FROM nvcr.io/nvidia/l4t-jetpack:r36.4.0

# 2) Copy QEMU static files from qemu-static docker image
COPY --from=multiarch/qemu-user-static:latest /usr/bin/qemu-aarch64-static /usr/bin

# 3) Copy target rootfs, to override original rootfs
COPY Linux_for_Tegra/rootfs/ /

# 4) Set default command system
CMD ["/bin/bash"]
EOF

# =========================
# 5) Ensure buildx builder exists and is selected
# =========================
log "Setup docker buildx builder: ${BUILDER_NAME}"
if ! sudo docker buildx inspect "${BUILDER_NAME}" >/dev/null 2>&1; then
  sudo docker buildx create --name "${BUILDER_NAME}" --use
else
  sudo docker buildx use "${BUILDER_NAME}"
fi

# (Optional but often helpful)
sudo docker buildx inspect --bootstrap >/dev/null

# =========================
# 6) Build image for linux/arm64 and --load into local docker
# =========================
log "Build image: ${TAG_NAME} (platform=${PLATFORM})"
sudo docker buildx build \
  --platform "${PLATFORM}" \
  -t "${TAG_NAME}" \
  --load \
  .

log "Done."
log "Result image: ${TAG_NAME}"

IMAGE="nv_cve_docker_image"
PLATFORM="linux/arm64"

WORKDIR="$(pwd)"
PY_SCRIPT="${WORKDIR}/trivy_to_dashboard_html.py"

# =========================
# Create Dockerfile in current folder
# =========================
log "Generate Dockerfile: ${PY_SCRIPT}"
cat > "${PY_SCRIPT}" <<'EOF'
#!/usr/bin/env python3
import json
import sys
from collections import Counter
from datetime import datetime

SEV_ORDER = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "UNKNOWN"]


def load_trivy_vulns(path: str):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    vulns = []
    for result in data.get("Results", []):
        for v in result.get("Vulnerabilities", []) or []:
            vulns.append(
                {
                    "CVEID": v.get("VulnerabilityID", ""),
                    "Severity": (v.get("Severity") or "UNKNOWN").upper(),
                    "Package": v.get("PkgName", ""),
                    "Installed": v.get("InstalledVersion", ""),
                    "Fixed": v.get("FixedVersion") or "N/A",
                    "Ref": v.get("PrimaryURL") or "",
                }
            )
    return vulns


def esc(s: str) -> str:
    return (
        (s or "")
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 trivy_to_dashboard_html.py <trivy_json> [output_html]")
        sys.exit(2)

    in_json = sys.argv[1]
    out_html = sys.argv[2] if len(sys.argv) >= 3 else "cve_report.html"

    vulns = load_trivy_vulns(in_json)

    sev_counts = Counter(v["Severity"] for v in vulns)

    sev_rank = {s: i for i, s in enumerate(SEV_ORDER)}
    vulns = sorted(
        vulns,
        key=lambda v: (sev_rank.get(v["Severity"], 99), v["Package"], v["CVEID"]),
    )

    rows = []
    for v in vulns:
        rows.append(
            f"<tr>"
            f"<td>{esc(v['CVEID'])}</td>"
            f"<td><span class='sev sev-{v['Severity']}'>{v['Severity']}</span></td>"
            f"<td class='mono'>{esc(v['Package'])}</td>"
            f"<td class='mono'>{esc(v['Installed'])}</td>"
            f"<td class='mono'>{esc(v['Fixed'])}</td>"
            f"<td>"
            + (f"<a href='{esc(v['Ref'])}' target='_blank'>link</a>" if v["Ref"] else "")
            + "</td></tr>"
        )

    now = datetime.now().strftime("%Y-%m-%d %H:%M")

    html = f"""<!doctype html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>CVE Report</title>

<style>
body {{
  font-family: system-ui, Arial;
  background: #f3f5f7;
  margin: 0;
}}

header {{
  background: #2f343a;
  color: white;
  padding: 10px 16px;
  display: flex;
  justify-content: space-between;
}}

.container {{
  max-width: 1280px;
  margin: 0 auto;
  padding: 16px;
}}

.card {{
  background: white;
  border: 1px solid #e5e7eb;
  border-radius: 8px;
  padding: 12px;
  margin-bottom: 16px;
}}

table {{
  width: 100%;
  border-collapse: collapse;
  font-size: 12px;
}}

th, td {{
  padding: 8px;
  border-top: 1px solid #e5e7eb;
}}

th {{
  text-align: left;
  color: #6b7280;
}}

.sev {{
  padding: 2px 8px;
  border-radius: 999px;
  color: white;
  font-weight: 700;
  font-size: 11px;
}}

.sev-CRITICAL {{ background:#ef4444; }}
.sev-HIGH {{ background:#f59e0b; color:#111827; }}
.sev-MEDIUM {{ background:#3b82f6; }}
.sev-LOW {{ background:#10b981; }}
.sev-UNKNOWN {{ background:#9ca3af; color:#111827; }}

.mono {{
  font-family: ui-monospace, Menlo, Consolas, monospace;
  font-size: 11px;
}}

.table-wrap {{
  max-height: 600px;
  overflow: auto;
  border: 1px solid #e5e7eb;
  border-radius: 6px;
}}
</style>
</head>

<body>
<header>
  <strong>CVE Report</strong>
  <span>Generated: {now}</span>
</header>

<div class="container">

  <div class="card">
    <h3>CVE Summary</h3>
    <table>
      <thead><tr><th>Severity</th><th>Count</th></tr></thead>
      <tbody>
        {"".join(f"<tr><td><span class='sev sev-{s}'>{s}</span></td><td>{sev_counts.get(s,0)}</td></tr>" for s in SEV_ORDER)}
      </tbody>
    </table>
  </div>

  <div class="card">
    <h3>Vulnerabilities</h3>
    <div class="table-wrap">
      <table>
        <thead>
          <tr>
            <th>CVE</th>
            <th>Severity</th>
            <th>Package</th>
            <th>Installed</th>
            <th>Fixed</th>
            <th>Ref</th>
          </tr>
        </thead>
        <tbody>
          {"".join(rows)}
        </tbody>
      </table>
    </div>
  </div>

</div>
</body>
</html>
"""

    with open(out_html, "w", encoding="utf-8") as f:
        f.write(html)

    print(f"[OK] Generated {out_html}")


if __name__ == "__main__":
    main()

EOF

if [[ ! -f "${PY_SCRIPT}" ]]; then
  echo "[ERROR] Not found: ${PY_SCRIPT}"
  echo "        Please put trivy_to_dashboard_html.py in the same directory as this script."
  exit 1
fi

echo "[INFO] Workdir : ${WORKDIR}"
echo "[INFO] Image   : ${IMAGE}"
echo "[INFO] Platform: ${PLATFORM}"
echo

read -r -d '' CONTAINER_CMD <<'EOF' || true
set -euo pipefail

echo "[INFO] Container OS:"
cat /etc/os-release || true
echo

echo "[INFO] apt update (allow failure)"
sudo apt update || echo "[WARN] apt update failed, continue anyway"

echo "[INFO] install base tools (best effort)"
sudo apt install -y curl wget gnupg python3 ca-certificates || echo "[WARN] apt install base tools failed (maybe already installed)"

echo
echo "[INFO] Install syft"
if ! command -v syft >/dev/null 2>&1; then
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
fi
syft version || true
echo

echo "[INFO] Generate SBOM.json"
sudo syft / --output spdx-json > /work/SBOM.json
echo

echo "[INFO] Install trivy repo key + list (best effort)"
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null || echo "[WARN] add trivy key failed"

echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" \
  | sudo tee /etc/apt/sources.list.d/trivy.list > /dev/null || true

echo
echo "[INFO] apt-get update (allow failure)"
sudo apt-get update || echo "[WARN] apt-get update failed, continue anyway"

echo "[INFO] install trivy (best effort)"
sudo apt-get install -y trivy || echo "[WARN] trivy install failed, try existing trivy if any"
trivy --version || true
echo

echo "[INFO] Generate CVE.json from SBOM.json"
trivy sbom --format json /work/SBOM.json > /work/CVE.json
echo

echo "[INFO] Convert CVE.json -> CVE.html using /work/trivy_to_dashboard_html.py"
python3 /work/trivy_to_dashboard_html.py /work/CVE.json /work/${IMAGE_VER}_sbom.html
echo


echo "[INFO] Output files:"
ls -al /work | egrep 'trivy_to_dashboard_html\.py|SBOM\.json|CVE\.json|${IMAGE_VER}_sbom\.html' || true
echo

echo "[INFO] Done."
EOF

echo "[INFO] Starting container..."
sudo docker run --rm -it --platform="${PLATFORM}" \
  -v "${WORKDIR}":/work \
  -w /work \
  "${IMAGE}" \
  bash -lc "${CONTAINER_CMD}"

if [ ! -f "${WORKDIR}/${IMAGE_VER}.html" ]; then
    if [  -f "Linux_for_Tegra" ]; then
      sudo rm -rf Linux_for_Tegra
      sudo rm CVE.* SBOM.json  Dockerfile  trivy_to_dashboard_html.py
    fi
    log "[ERROR] File not found: ${WORKDIR}/${IMAGE_VER}_sbom.html"
    exit 1
fi

md5sum ${IMAGE_VER}_sbom.html | awk '{print $1}' > ${IMAGE_VER}_sbom.html.md5
echo "[INFO] Generated ${IMAGE_VER}_sbom.html.md5 "



echo
echo "[INFO] Back on host. Verify outputs:"
ls -al "${WORKDIR}" | egrep 'trivy_to_dashboard_html\.py|SBOM\.json|CVE\.json|${IMAGE_VER}\.html|${IMAGE_VER}.html.md5' || true
sudo rm CVE.* SBOM.json  Dockerfile  trivy_to_dashboard_html.py
if [  -f "Linux_for_Tegra" ]; then
    sudo rm -rf Linux_for_Tegra
fi


echo
echo "[INFO] Finished. ${IMAGE_VER}.html is in: ${WORKDIR}"

