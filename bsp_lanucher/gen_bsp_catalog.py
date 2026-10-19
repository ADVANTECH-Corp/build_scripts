#!/usr/bin/env python3
"""Generate the BSP Launcher catalog (MDX partial) from configuration.json.

The whole catalog is regenerated from the given configuration on every run:
  - one tab per platform, one collapsible block per product
  - one table row per version; OS distros in descending order, newest version first
  - LATEST versions and anything locked at any level are left out
  - no download links; OS distros that need an Azure token are marked with a lock icon
"""
import argparse
import datetime
import json
import re
import sys
from collections import defaultdict
from pathlib import Path

LOCK_ICON = "🔒"
COLUMNS = ["OS Distro", "Version", "Stage", "Kernel", "Date", "Chipset / RAM", "Storage"]
DATE_RE = re.compile(r"_(\d{4}-\d{2}-\d{2})")
KERNEL_RE = re.compile(r"_kernel-([\d.]+)_")


def version_key(v):
    return tuple(int(x) for x in re.findall(r"\d+", v))


def natural_key(text):
    """'YOCTO6.0-LINUX6.18.37' -> ('YOCTO', 6, '.', 0, ...) so numbers compare by value."""
    return tuple(int(t) if t.isdigit() else t for t in re.findall(r"\d+|\D+", text))


def stage(version):
    """vK.0.0 = GA, vK.M.0 = Beta, vK.M.P = Alpha"""
    _, minor, patch = (version_key(version) + (0, 0, 0))[:3]
    return "Alpha" if patch else "Beta" if minor else "GA"


def chip_key(chip):
    """Numbers first (IQ9075 > QCS6490 > QCS5430), then natural order of the name."""
    return version_key(chip), natural_key(chip)


def nobr(text):
    """Keep short values such as dates on one line inside narrow table cells."""
    return f"<nobr>{text}</nobr>"


def iter_versions(cfg):
    """Yield (platform, chipset, product, osDistro, version) for every visible version."""
    for p in cfg["platform"]:
        for c in p["chipset"]:
            for pr in c["product"]:
                for o in pr["osDistro"]:
                    if any(n.get("lock") for n in (cfg, p, c, pr, o)):
                        continue
                    for v in (v for v in o["version"] if v["name"] != "LATEST"):
                        yield p, c, pr, o, v


def build_rows(cfg):
    """{(platform, product, osDistro, version): row}; one product on several chipsets is merged into one row."""
    rows = defaultdict(lambda: {"chipsets": defaultdict(set), "kernels": set(),
                                "storages": set(), "dates": set(), "token": False})
    for p, c, pr, o, v in iter_versions(cfg):
        row = rows[(p["name"], pr["name"], o["name"], v["name"])]
        row["chipsets"][c["name"]]  # a chipset is listed even if it has no image yet
        row["token"] |= bool(o.get("azureToken"))
        row["kernels"].update(m.group(1) for r in v["bsp"]["ramSize"]
                              if (m := KERNEL_RE.search(r.get("manifestXML", ""))))
        for r in v["image"]["ramSize"]:
            row["chipsets"][c["name"]].add(r["name"])  # RAM sizes are per chipset in configuration.json
            for s in r["storage"]:
                row["storages"].add(s["type"])
                row["dates"].update(DATE_RE.findall(s.get("image", "")))
    return rows


def os_order(os_distro, versions):
    """OS distro descending (natural order), newest kernel first as tie-breaker."""
    kernels = set().union(*(row["kernels"] for row in versions.values()))
    return natural_key(os_distro), max((version_key(k) for k in kernels), default=())


def render_row(os_distro, version, row):
    cells = [
        f"{os_distro} {LOCK_ICON}" if row["token"] else os_distro,
        nobr(version),
        stage(version),
        ", ".join(sorted(row["kernels"], key=version_key)) or "-",
        nobr(max(row["dates"], default="-")),
        # "16G-8G" means one image for both 16G and 8G; show it as "16G/8G"
        "<br/>".join(f"{chip} {', '.join(r.replace('-', '/') for r in sorted(rams, key=version_key))}".strip()
                     for chip, rams in sorted(row["chipsets"].items(), key=lambda i: chip_key(i[0]), reverse=True)),
        ", ".join(sorted(row["storages"])) or "-",
    ]
    return "| " + " | ".join(cells) + " |"


def product_chipsets(os_rows):
    """All chipsets of a product; os_rows: {osDistro: {version: row}}"""
    return sorted(set().union(*(row["chipsets"] for versions in os_rows.values()
                                for row in versions.values())), key=chip_key, reverse=True)


def render_product(product, os_rows, name_width):
    chipsets = product_chipsets(os_rows)
    lines = [
        "<details>",
        # fixed-width product name so the chipset lists line up across blocks
        f"<summary><b style={{{{display: 'inline-block', minWidth: '{name_width}'}}}}>{product}</b>"
        f"{', '.join(chipsets)}</summary>",
        "",
        "| " + " | ".join(COLUMNS) + " |",
        "| " + " | ".join("---" for _ in COLUMNS) + " |",
    ]
    for os_distro in sorted(os_rows, key=lambda o: os_order(o, os_rows[o]), reverse=True):
        versions = os_rows[os_distro]
        for version in sorted(versions, key=version_key, reverse=True):
            lines.append(render_row(os_distro, version, versions[version]))
    lines += ["", "</details>"]
    return lines


def render(rows, version, updated):
    tree = defaultdict(lambda: defaultdict(lambda: defaultdict(dict)))  # platform -> product -> osDistro -> version -> row
    for (platform, product, os_distro, image_version), row in rows.items():
        tree[platform][product][os_distro][image_version] = row

    # bold uppercase is roughly 0.75em per character; one extra character as the gap
    name_width = f"{0.75 * (max(len(k[1]) for k in rows) + 1):g}em"

    lines = [
        f"{{/* Auto-generated by build_scripts/bsp_lanucher/gen_bsp_catalog.py from configuration.json of "
        f"official release v{version}. Do not edit by hand. */}}",
        "import Tabs from '@theme/Tabs';",
        "import TabItem from '@theme/TabItem';",
        "",
        f"Last updated: {updated} · {LOCK_ICON} = Azure token required",
        "",
        '<Tabs groupId="bsp-catalog">',
    ]
    for platform in sorted(tree, key=str.lower):
        products = tree[platform]
        lines += [f'<TabItem value="{platform.lower()}" label="{platform} ({len(products)})">', ""]
        # chipsets descending (e.g. IMX95 before IMX8MP), product name ascending within a chipset
        by_name = sorted(products)
        for product in sorted(by_name, key=lambda pr: [chip_key(c) for c in product_chipsets(products[pr])],
                              reverse=True):
            lines += render_product(product, products[product], name_width) + [""]
        lines.append("</TabItem>")
    lines.append("</Tabs>")
    return "\n".join(lines) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", required=True, help="path to configuration.json")
    ap.add_argument("--version", required=True, help="official release version the config comes from, e.g. 1.0.12")
    ap.add_argument("--output", required=True, help="output MDX partial, e.g. docs/utility/bsplauncher/_bsp-catalog.mdx")
    args = ap.parse_args(argv)

    cfg = json.loads(Path(args.config).read_text(encoding="utf-8"))
    text = render(build_rows(cfg), args.version, datetime.date.today().isoformat())
    Path(args.output).write_text(text, encoding="utf-8")
    print(f"{args.output} written")
    return 0


if __name__ == "__main__":
    sys.exit(main())
