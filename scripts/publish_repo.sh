#!/usr/bin/env bash
# Publish the two debug .debs produced by the development CI matrix to
# hadobedo/repo's development feed (hadobedo.github.io/repo/dev).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAGES_REPO="${PAGES_REPO:-hadobedo/repo}"
BRANCH="${PAGES_REPO_BRANCH:-main}"
read_control_version() {
    local control_file=$1
    local version_count
    local version
    version_count=$(awk '$1 == "Version:" { count++ } END { print count + 0 }' "$control_file")
    version=$(awk '$1 == "Version:" && NF == 2 { print $2 }' "$control_file")
    if [[ $version_count -ne 1 || -z $version ]]; then
        printf 'expected exactly one valid Version field in %s\n' "$control_file" >&2
        return 1
    fi
    printf '%s\n' "$version"
}

EXPECTED_VERSION="${EXPECTED_VERSION:-$(read_control_version "$SCRIPT_DIR/../control")}"
PACKAGE_NAME="com.nicksworks.dottoplusplus"
EXPECTED_ARCHES=(iphoneos-arm64 iphoneos-arm64e)
: "${DEBS:?DEBS (space-separated .deb paths) is required}"

if [[ -z "${REPO_DEPLOY_KEY:-}" ]]; then
    echo "REPO_DEPLOY_KEY is required; refusing to skip development publication" >&2
    exit 1
fi

DEBS_ABS=()
for deb in $DEBS; do
    DEBS_ABS+=("$(cd "$(dirname "$deb")" && pwd)/$(basename "$deb")")
done
if [[ ${#DEBS_ABS[@]} -eq 0 ]]; then
    echo "no .deb files supplied" >&2
    exit 1
fi

validate_debs() {
    local expected_version=$1
    shift
    local -A seen=()
    local deb package version architecture
    for deb in "$@"; do
        package=$(dpkg-deb -f "$deb" Package)
        version=$(dpkg-deb -f "$deb" Version)
        architecture=$(dpkg-deb -f "$deb" Architecture)
        if [[ $package != "$PACKAGE_NAME" ]]; then
            printf 'unexpected package %s in %s\n' "$package" "$deb" >&2
            return 1
        fi
        if [[ $version != "$expected_version" ]]; then
            printf 'expected Version %s, found %s in %s\n' "$expected_version" "$version" "$deb" >&2
            return 1
        fi
        case "$architecture" in
            iphoneos-arm64|iphoneos-arm64e) ;;
            *)
                printf 'unexpected architecture %s in %s\n' "$architecture" "$deb" >&2
                return 1
                ;;
        esac
        if [[ -n ${seen[$architecture]:-} ]]; then
            printf 'duplicate candidate architecture %s\n' "$architecture" >&2
            return 1
        fi
        seen[$architecture]=1
    done
    local architecture
    for architecture in "${EXPECTED_ARCHES[@]}"; do
        if [[ -z ${seen[$architecture]:-} ]]; then
            printf 'candidate is missing architecture %s\n' "$architecture" >&2
            return 1
        fi
    done
}

validate_debs "$EXPECTED_VERSION" "${DEBS_ABS[@]}"

mkdir -p "$HOME/.ssh"
printf '%s\n' "$REPO_DEPLOY_KEY" > "$HOME/.ssh/id_ed25519"
chmod 600 "$HOME/.ssh/id_ed25519"
ssh-keyscan -H github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone --depth 1 -b "$BRANCH" "git@github.com:${PAGES_REPO}.git" "$WORK/repo"
cd "$WORK/repo"

mkdir -p dev/debs
for deb in "${DEBS_ABS[@]}"; do
    cp "$deb" dev/debs/
done

# Keep the newest build per package+architecture so stale development builds do
# not remain installable from the feed.
python3 - <<'PY'
import glob
import os
import re

keep = {}
for path in glob.glob("dev/debs/*.deb"):
    name = os.path.basename(path)
    match = re.match(r"(.+?)_(.+?)_(.+)\.deb$", name)
    if not match:
        continue
    key = (match.group(1), match.group(3))
    version = tuple(int(x) for x in re.findall(r"\d+", match.group(2)))
    if key not in keep or version > keep[key][0]:
        keep[key] = (version, path)

for path in glob.glob("dev/debs/*.deb"):
    if not any(path == kept_path for _, kept_path in keep.values()):
        os.remove(path)
        print("pruned", os.path.basename(path))
PY

shopt -s nullglob
published_debs=(dev/debs/*.deb)
validate_debs "$EXPECTED_VERSION" "${published_debs[@]}"

python3 "$SCRIPT_DIR/make_repo_metadata.py" dev development dev
cat > dev/index.html <<'EOF'
<html><head><meta http-equiv="refresh" content="0; url=Packages"></head><body>dotto++ development feed</body></html>
EOF
mkdir -p assets depictions dev/assets dev/depictions
for asset_dir in assets dev/assets; do
    cp "$SCRIPT_DIR/../dottoPlusPlusPrefs/Resources/icon@3x.png" "$asset_dir/dottoplusplus.png"
done
for icon_name in RepoIcon.png CydiaIcon.png; do
    cp "$SCRIPT_DIR/../dottoPlusPlusPrefs/Resources/icon@3x.png" "$icon_name"
    cp "$SCRIPT_DIR/../dottoPlusPlusPrefs/Resources/icon@3x.png" "dev/$icon_name"
done
for depiction_dir in depictions dev/depictions; do
    python3 "$SCRIPT_DIR/render_repo_depiction.py" \
        --output-dir "$depiction_dir" \
        --version "$EXPECTED_VERSION" \
        --base-url "https://hadobedo.github.io/repo"
done
for required_page in \
    assets/dottoplusplus.png \
    RepoIcon.png \
    CydiaIcon.png \
    depictions/com.nicksworks.dottoplusplus.json \
    depictions/com.nicksworks.dottoplusplus.html \
    dev/assets/dottoplusplus.png \
    dev/RepoIcon.png \
    dev/CydiaIcon.png \
    dev/depictions/com.nicksworks.dottoplusplus.json \
    dev/depictions/com.nicksworks.dottoplusplus.html; do
    if [[ ! -s $required_page ]]; then
        printf 'required depiction asset is missing or empty: %s\n' "$required_page" >&2
        exit 1
    fi
done
PUBLISHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > dev/BUILD <<EOF
Package: $PACKAGE_NAME
Version: $EXPECTED_VERSION
Source-Commit: ${GITHUB_SHA:-local}
Published-At: $PUBLISHED_AT
EOF

assert_packages_stanza() {
    local architecture=$1
    awk -v expected_package="$PACKAGE_NAME" \
        -v expected_version="$EXPECTED_VERSION" \
        -v expected_architecture="$architecture" '
        function finish() {
            if (package == expected_package && version == expected_version && architecture == expected_architecture) {
                found = 1
            }
            package = version = architecture = ""
        }
        /^$/ { finish(); next }
        /^Package: / { package = substr($0, 10); next }
        /^Version: / { version = substr($0, 10); next }
        /^Architecture: / { architecture = substr($0, 15); next }
        END { finish(); exit(found ? 0 : 1) }
    ' dev/Packages
}

for architecture in "${EXPECTED_ARCHES[@]}"; do
    assert_packages_stanza "$architecture" || {
        printf 'generated dev/Packages is missing %s %s\n' "$PACKAGE_NAME" "$architecture" >&2
        exit 1
    }
done

# BUILD makes every successful CI publication observable even if the same
# package version was already present in the feed.
git add -A
git -c user.name="dotto++ CI" -c user.email="ci@hadobedo.invalid" \
    commit -m "dev: publish dotto++ $EXPECTED_VERSION"
git push origin "$BRANCH"

published_commit=$(git rev-parse HEAD)
echo "published $published_commit to https://hadobedo.github.io/repo/dev/"
