#!/usr/bin/env bash
# Publish debug .debs to hadobedo/repo's development feed
# (hadobedo.github.io/repo/dev), which acts as the staging channel: install from
# there to test on a device before anything reaches the stable feeds.
#
# Any package may be staged. When EXPECTED_VERSION is set it is asserted against
# the dotto++ package only, so the CI job that builds dotto++ still verifies the
# version it just produced.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PAGES_REPO="${PAGES_REPO:-hadobedo/repo}"
# Overridable so the script can be exercised against a local scratch repository.
PAGES_REPO_URL="${PAGES_REPO_URL:-git@github.com:${PAGES_REPO}.git}"
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
VALID_ARCHES=(iphoneos-arm64 iphoneos-arm64e)
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

# Validates a set of debs: every architecture must be one we serve, and no two
# debs may claim the same package+architecture. When EXPECTED_VERSION is set, the
# dotto++ package must match it; other packages are staged at whatever version
# they carry.
validate_debs() {
    local expected_version=$1
    shift
    local -A seen=()
    local deb package version architecture
    for deb in "$@"; do
        package=$(dpkg-deb -f "$deb" Package)
        version=$(dpkg-deb -f "$deb" Version)
        architecture=$(dpkg-deb -f "$deb" Architecture)
        if [[ -z $package || -z $version || -z $architecture ]]; then
            printf 'incomplete control fields in %s\n' "$deb" >&2
            return 1
        fi
        case " ${VALID_ARCHES[*]} " in
            *" $architecture "*) ;;
            *)
                printf 'unexpected architecture %s in %s\n' "$architecture" "$deb" >&2
                return 1
                ;;
        esac
        if [[ -n $expected_version && $package == "$PACKAGE_NAME" && $version != "$expected_version" ]]; then
            printf 'expected %s Version %s, found %s in %s\n' \
                "$package" "$expected_version" "$version" "$deb" >&2
            return 1
        fi
        if [[ -n ${seen["$package:$architecture"]:-} ]]; then
            printf 'duplicate candidate %s %s\n' "$package" "$architecture" >&2
            return 1
        fi
        seen["$package:$architecture"]=1
    done
}

validate_debs "$EXPECTED_VERSION" "${DEBS_ABS[@]}"

mkdir -p "$HOME/.ssh"
printf '%s\n' "$REPO_DEPLOY_KEY" > "$HOME/.ssh/id_ed25519"
chmod 600 "$HOME/.ssh/id_ed25519"
ssh-keyscan -H github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

git clone --depth 1 -b "$BRANCH" "$PAGES_REPO_URL" "$WORK/repo"
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
# Structural checks only: the feed may legitimately hold other versions and
# packages. The strict version assertion above already covered what we staged.
validate_debs "" "${published_debs[@]}"

python3 "$SCRIPT_DIR/make_repo_metadata.py" dev development dev
cat > dev/index.html <<'EOF'
<html><head><meta http-equiv="refresh" content="0; url=Packages"></head><body>Nicks Works development feed</body></html>
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
{
    printf 'Source-Commit: %s\n' "${GITHUB_SHA:-local}"
    printf 'Published-At: %s\n' "$PUBLISHED_AT"
    for deb in "${published_debs[@]}"; do
        printf 'Package: %s %s %s\n' \
            "$(dpkg-deb -f "$deb" Package)" \
            "$(dpkg-deb -f "$deb" Version)" \
            "$(dpkg-deb -f "$deb" Architecture)"
    done
} > dev/BUILD

# Assert every package+architecture we just staged is present in the generated
# index, at the version on disk.
assert_packages_stanza() {
    local expected_package=$1 expected_version=$2 expected_architecture=$3
    awk -v expected_package="$expected_package" \
        -v expected_version="$expected_version" \
        -v expected_architecture="$expected_architecture" '
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

for deb in "${published_debs[@]}"; do
    package=$(dpkg-deb -f "$deb" Package)
    version=$(dpkg-deb -f "$deb" Version)
    architecture=$(dpkg-deb -f "$deb" Architecture)
    assert_packages_stanza "$package" "$version" "$architecture" || {
        printf 'generated dev/Packages is missing %s %s %s\n' \
            "$package" "$version" "$architecture" >&2
        exit 1
    }
done

# BUILD makes every successful CI publication observable even if the same
# package version was already present in the feed.
git add -A
git -c user.name="dotto++ CI" -c user.email="ci@hadobedo.invalid" \
    commit -m "dev: publish ${#published_debs[@]} package(s)"
git push origin "$BRANCH"

published_commit=$(git rev-parse HEAD)
echo "published $published_commit to https://hadobedo.github.io/repo/dev/"
