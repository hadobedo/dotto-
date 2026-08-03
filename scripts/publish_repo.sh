#!/usr/bin/env bash
# Publish built .debs to the dev/ feed of the GitHub Pages repo
# (hadobedo.github.io/repo/dev), matching the existing layout:
#   dev/debs/<package>.deb
#   dev/Packages{,gz,bz2,xz}
#   dev/Release
#
# Requirements:
#   - REPO_DEPLOY_KEY secret: an SSH deploy key with write access to
#     hadobedo/repo
#   - env: DEBS (space-separated paths to .deb files)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAGES_REPO="${PAGES_REPO:-hadobedo/repo}"
BRANCH="${PAGES_REPO_BRANCH:-main}"
: "${DEBS:?DEBS (space-separated .deb paths) is required}"

# Resolve to absolute paths: the script changes into the pages repo below.
DEBS_ABS=""
for deb in $DEBS; do
    DEBS_ABS="$DEBS_ABS $(cd "$(dirname "$deb")" && pwd)/$(basename "$deb")"
done
DEBS="$DEBS_ABS"

if [[ -z "${REPO_DEPLOY_KEY:-}" ]]; then
    echo "REPO_DEPLOY_KEY not set; skipping publish" >&2
    exit 0
fi

# Install the deploy key for this run.
mkdir -p ~/.ssh
printf '%s\n' "$REPO_DEPLOY_KEY" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone --depth 1 -b "$BRANCH" "git@github.com:${PAGES_REPO}.git" "$WORK/repo"
cd "$WORK/repo"

mkdir -p dev/debs
for deb in $DEBS; do
    cp "$deb" dev/debs/
done

# Prune: keep only the newest build per package+architecture.
python3 - <<'EOF'
import glob, os, re

keep = {}
for path in glob.glob("dev/debs/*.deb"):
    name = os.path.basename(path)
    m = re.match(r"(.+?)_(.+?)_(.+)\.deb$", name)
    if not m:
        continue
    key = (m.group(1), m.group(3))
    version = tuple(int(x) for x in re.findall(r"\d+", m.group(2)))
    if key not in keep or version > keep[key][0]:
        keep[key] = (version, path)

for key, (_, path) in keep.items():
    print("keep", os.path.basename(path))
for path in glob.glob("dev/debs/*.deb"):
    if not any(p == path for _, p in keep.values()):
        os.remove(path)
        print("pruned", os.path.basename(path))
EOF

python3 "$SCRIPT_DIR/make_repo_metadata.py" dev development dev

# Minimal landing page, mirroring the existing feeds.
cat > dev/index.html <<'EOF'
<html><head><meta http-equiv="refresh" content="0; url=Packages"></head><body>dotto++ development feed</body></html>
EOF

git add -A
git -c user.name="dotto++ CI" -c user.email="ci@hadobedo.invalid" \
    commit -m "dev: publish $(echo $DEBS | xargs -n1 basename | tr '\n' ' ')"
git push origin "$BRANCH"

echo "published to https://hadobedo.github.io/repo/dev/"
