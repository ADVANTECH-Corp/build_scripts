#!/usr/bin/env python3
"""Generate BSP Launcher release notes: compare the previous official release with a daily snapshot.

With --version (officialbuild): release notes of that official release.
Without --version (dailybuild): preview of the unreleased changes since the latest official release.

Both BSP Images and Launcher Scripts are mapped to {key: fingerprint} and compared by the same diff:
  - BSP Images      : key = (platform, osDistro, product, version)
                      fingerprint = version content + lock/azureToken of each level (LATEST excluded)
  - Launcher Scripts: key = (platform, branch)
                      fingerprint = file contents excluding configuration.json
"""
import argparse
import csv
import datetime
import hashlib
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

CONFIG_REPO = "AIM_Linux_BSP_Launcher"
CONFIG_BRANCH = "main_develop"
CONFIG_FILE = "configuration.json"
STATUS_ORDER = {"+": 0, "~": 1, "-": 2}
SEPARATOR = "-" * 66


def git(repo, *args):
    return subprocess.run(["git", "-C", str(repo), *args],
                          check=True, capture_output=True, text=True).stdout


def version_key(v):
    return tuple(int(x) for x in re.findall(r"\d+", v))


def sha1(text):
    return hashlib.sha1(text.encode()).hexdigest()


# ========== Inputs ==========
def read_snapshot(csv_path):
    """daily CSV -> {(platform, develop_branch): commit}"""
    with open(csv_path, newline="") as f:
        return {(r[0], r[1]): r[2] for r in csv.reader(f)
                if len(r) >= 3 and r[1].endswith("_develop")}


def find_prev_version(repo, current=None):
    """Highest remote v*_main_develop tag version lower than the current version (any version if None)"""
    pattern = re.compile(rf"refs/tags/v([\d.]+)_{CONFIG_BRANCH}$")
    out = git(repo, "ls-remote", "--tags", "origin", f"v*_{CONFIG_BRANCH}")
    versions = [m.group(1) for line in out.splitlines() if (m := pattern.search(line))]
    limit = version_key(current) if current else (float("inf"),)
    older = [v for v in versions if version_key(v) < limit]
    return max(older, key=version_key, default=None)


def fetch_prev_tags(repo, prev):
    git(repo, "fetch", "--no-tags", "origin", f"refs/tags/v{prev}_*:refs/tags/v{prev}_*")


# ========== Map to {key: fingerprint} ==========
def config_map(cfg):
    fragments = defaultdict(list)
    for p in cfg["platform"]:
        for c in p["chipset"]:
            for pr in c["product"]:
                for o in pr["osDistro"]:
                    attrs = [[n.get("lock"), n.get("azureToken")] for n in (cfg, p, c, pr, o)]
                    for v in (v for v in o["version"] if v["name"] != "LATEST"):
                        # Same product under multiple chipsets shares one key; merge the fragments
                        fragments[(p["name"], o["name"], pr["name"], v["name"])].append(
                            json.dumps([c["name"], attrs, v], sort_keys=True))
    return {k: sha1("\n".join(sorted(f))) for k, f in fragments.items()}


def load_config(repo, ref):
    return json.loads(git(repo, "show", f"{ref}:{CONFIG_FILE}"))


def tree_fingerprint(repo, commit):
    lines = git(repo, "ls-tree", "-r", commit).splitlines()
    return sha1("\n".join(l for l in lines if l.split("\t", 1)[1] != CONFIG_FILE))


def scripts_map_new(workdir, snapshot):
    return {(p, b.removesuffix("_develop")): tree_fingerprint(workdir / p, c)
            for (p, b), c in snapshot.items()}


def scripts_map_old(workdir, platforms, prev):
    prefix = f"v{prev}_"
    return {(p, tag[len(prefix):].removesuffix("_develop")): tree_fingerprint(workdir / p, tag + "^{commit}")
            for p in platforms
            for tag in git(workdir / p, "for-each-ref", "--format=%(refname:short)",
                           f"refs/tags/{prefix}*_develop").split()}


# ========== Diff and output ==========
def diff(old, new):
    return {
        "+": new.keys() - old.keys(),
        "~": {k for k in old.keys() & new.keys() if old[k] != new[k]},
        "-": old.keys() - new.keys(),
    }


def render(changes, group_of, item_of, detail_of):
    groups = defaultdict(lambda: defaultdict(list))
    for status, keys in changes.items():
        for k in keys:
            groups[group_of(k)][(status, item_of(k))].append(detail_of(k))
    if not groups:
        return ["No changes."]

    lines = []
    for group in sorted(groups):
        lines.append(group)
        items = sorted(groups[group].items(), key=lambda e: (STATUS_ORDER[e[0][0]], e[0][1]))
        width = max(len(item) for (_, item), _ in items)
        for (status, item), details in items:
            detail = ", ".join(sorted(filter(None, details), key=version_key))
            lines.append(f"  [{status}] {item:<{width}}  {detail}".rstrip())
    return lines


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--workdir", default=".", help="directory containing the platform repo clones (default: .)")
    ap.add_argument("--csv", required=True, help="daily build CSV")
    ap.add_argument("--version", help="official version of this release, e.g. 1.0.12 "
                                      "(omit for a preview of unreleased changes)")
    ap.add_argument("--prev-version", help="previous official version "
                                           "(default: highest remote version lower than --version, or the latest one)")
    ap.add_argument("--daily-version", required=True, help="daily build version, e.g. 95")
    ap.add_argument("--daily-date", required=True, help="daily build date, e.g. 2026-10-11")
    ap.add_argument("--output", help="output file (default: stdout only)")
    args = ap.parse_args(argv)

    workdir = Path(args.workdir)
    snapshot = read_snapshot(args.csv)
    platforms = sorted({p for p, _ in snapshot})
    config_repo = workdir / CONFIG_REPO

    prev = args.prev_version or find_prev_version(config_repo, args.version)
    if prev:
        for p in platforms:
            fetch_prev_tags(workdir / p, prev)

    config_new = config_map(load_config(config_repo, snapshot[(CONFIG_REPO, CONFIG_BRANCH)]))
    config_old = config_map(load_config(config_repo, f"v{prev}_{CONFIG_BRANCH}")) if prev else {}
    scripts_new = scripts_map_new(workdir, snapshot)
    scripts_old = scripts_map_old(workdir, platforms, prev) if prev else {}

    lines = [
        SEPARATOR,
        f"Version               : {args.version or 'Unreleased'}",
        f"{'Release Date' if args.version else 'Generated Date':<22}: {datetime.date.today():%Y/%m/%d}",
        f"Previous Version      : {prev or '-'}",
        f"Daily Build           : v{args.daily_version} ({args.daily_date})",
        "",
        "Release Notes:  [+] added  [~] updated  [-] removed",
        "",
        "**BSP Images**",
        *render(diff(config_old, config_new),
                group_of=lambda k: f"{k[0]} / {k[1]}", item_of=lambda k: k[2], detail_of=lambda k: k[3]),
        "",
        "**Launcher Scripts**",
        *render(diff(scripts_old, scripts_new),
                group_of=lambda k: k[0], item_of=lambda k: k[1], detail_of=lambda k: ""),
        SEPARATOR,
    ]
    text = "\n".join(lines) + "\n"

    print(text, end="")
    if args.output:
        Path(args.output).write_text(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
