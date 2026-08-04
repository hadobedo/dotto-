#!/usr/bin/env bash
set -euo pipefail

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

extract_archive_member() {
    local archive=$1
    local member=$2
    local output=$3
    tar -tf "$archive" | awk -v wanted="$member" \
        '(!found && ($0 == wanted || $0 == "./" wanted || $0 ~ "/" wanted "$")) { print; found = 1 }' > "$output.member"
    local archive_member
    archive_member=$(cat "$output.member")
    rm -f "$output.member"
    if [[ -z $archive_member ]]; then
        printf 'member %s not found in %s\n' "$member" "$archive" >&2
        return 1
    fi
    tar -xOf "$archive" "$archive_member" > "$output"
}

repository_version=$(read_control_version control)

shopt -s nullglob
packages=(packages/*.deb)
if [[ ${#packages[@]} -ne 1 ]]; then
    printf 'expected exactly one package, found %d\n' "${#packages[@]}" >&2
    exit 1
fi

package=$(cd "$(dirname "${packages[0]}")" && pwd)/$(basename "${packages[0]}")
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

(
    cd "$tmpdir"
    ar x "$package"
)

control_archive=$(find "$tmpdir" -maxdepth 1 -name 'control.tar.*' -print -quit)
if [[ -z $control_archive ]]; then
    printf 'control archive not found in %s\n' "$package" >&2
    exit 1
fi
tar -xf "$control_archive" -C "$tmpdir"
package_control="$tmpdir/control"
package_version=$(read_control_version "$package_control")
if [[ $package_version != "$repository_version" ]]; then
    printf 'package Version mismatch: repository=%s package=%s\n' \
        "$repository_version" "$package_version" >&2
    exit 1
fi

grep -Fx 'Package: com.nicksworks.dottoplusplus' "$package_control" \
    || { echo "Package mismatch:" >&2; grep '^Package:' "$package_control" >&2; exit 1; }
EXPECTED_ARCH="${EXPECTED_ARCH:-iphoneos-arm64e}"
grep -Fx "Architecture: $EXPECTED_ARCH" "$package_control" \
    || { echo "Architecture mismatch (expected $EXPECTED_ARCH):" >&2; grep '^Architecture:' "$package_control" >&2; exit 1; }
grep -Fx 'Depends: firmware (>= 15.0), firmware (<< 18.0), ellekit, preferenceloader' "$package_control" \
    || { echo "Depends mismatch:" >&2; grep '^Depends:' "$package_control" >&2; exit 1; }
grep -Fx 'Homepage: https://github.com/hadobedo/dotto-' "$package_control" \
    || { echo "Homepage mismatch:" >&2; grep '^Homepage:' "$package_control" >&2; exit 1; }
grep -Fx 'Icon: https://hadobedo.github.io/repo/assets/dottoplusplus.png' "$package_control" \
    || { echo "Icon mismatch:" >&2; grep '^Icon:' "$package_control" >&2; exit 1; }
grep -Fx 'SileoDepiction: https://hadobedo.github.io/repo/depictions/com.nicksworks.dottoplusplus.json' "$package_control" \
    || { echo "SileoDepiction mismatch:" >&2; grep '^SileoDepiction:' "$package_control" >&2; exit 1; }
grep -Fx 'Depiction: https://hadobedo.github.io/repo/depictions/com.nicksworks.dottoplusplus.html' "$package_control" \
    || { echo "Depiction mismatch:" >&2; grep '^Depiction:' "$package_control" >&2; exit 1; }

data_archive=$(find "$tmpdir" -maxdepth 1 -name 'data.tar.*' -print -quit)
if [[ -z $data_archive ]]; then
    printf 'data archive not found in %s\n' "$package" >&2
    exit 1
fi
archive_members=$(tar -tf "$data_archive")
required_members=(
    'Library/MobileSubstrate/DynamicLibraries/dottoPlusPlus.dylib'
    'Library/MobileSubstrate/DynamicLibraries/dottoPlusPlus.plist'
    'Library/PreferenceBundles/dottoPlusPlusPrefs.bundle/Info.plist'
    'Library/PreferenceBundles/dottoPlusPlusPrefs.bundle/dottoPlusPlusPrefs'
    'Library/PreferenceLoader/Preferences/dottoPlusPlusPrefs.plist'
    'Library/Application Support/dottoplusplus/badges/normal/SBBadgeBG@3x.png'
    'Library/Application Support/dottoplusplus/badges/circle/SBBadgeBG@3x.png'
    'usr/local/lib/libdottoplus.dylib'
)
for required_member in "${required_members[@]}"; do
    if ! awk -v wanted="$required_member" \
        '$0 == wanted || $0 == "./" wanted || (length($0) > length(wanted) && substr($0, length($0) - length(wanted) + 1) == wanted)' \
        <<< "$archive_members" | grep -q .; then
        printf 'required package member %s not found in %s\n' \
            "$required_member" "$package" >&2
        exit 1
    fi
done

if [[ ${EXPECT_RELEASE:-0} == 1 ]]; then
    tweak_binary="$tmpdir/dottoPlusPlus.dylib"
    shared_binary="$tmpdir/libdottoplus.dylib"
    tweak_filter="$tmpdir/dottoPlusPlus.plist"
    extract_archive_member "$data_archive" \
        'Library/MobileSubstrate/DynamicLibraries/dottoPlusPlus.dylib' "$tweak_binary"
    extract_archive_member "$data_archive" \
        'usr/local/lib/libdottoplus.dylib' "$shared_binary"
    extract_archive_member "$data_archive" \
        'Library/MobileSubstrate/DynamicLibraries/dottoPlusPlus.plist' "$tweak_filter"
    if strings "$tweak_binary" "$shared_binary" | grep -Eiq \
        'DPP_BADGE_TRACE|DottoPlusPlusTraceBadgeView|dotto\+\+ badge phase=|next-runloop-(before|after)|after-root-geometry|SnowBoardLoaded'; then
        printf 'release package contains diagnostic tracing markers: %s\n' "$package" >&2
        exit 1
    fi
    python3 - "$tweak_filter" <<'PY'
import plistlib
import re
import sys

raw = open(sys.argv[1], "rb").read()
if raw.lstrip().startswith(b"bplist") or b"<?xml" in raw[:128]:
    value = plistlib.loads(raw)
    assert value.get("Filter", {}).get("Bundles") == ["com.apple.springboard"]
else:
    text = raw.decode("utf-8", "strict")
    assert re.search(r"Bundles\s*=\s*\(\s*\"com\.apple\.springboard\"\s*\)", text)
PY
fi

bundle_info="$tmpdir/DottoPlusPlusPrefs-Info.plist"
extract_archive_member "$data_archive" \
    'Library/PreferenceBundles/dottoPlusPlusPrefs.bundle/Info.plist' "$bundle_info"
short_version=$(python3 - "$bundle_info" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "rb") as handle:
    print(plistlib.load(handle)["CFBundleShortVersionString"])
PY
)
bundle_version=$(python3 - "$bundle_info" <<'PY'
import plistlib
import sys
with open(sys.argv[1], "rb") as handle:
    print(plistlib.load(handle)["CFBundleVersion"])
PY
)
if [[ $short_version != "$repository_version" || $bundle_version != "$repository_version" ]]; then
    printf 'bundle version mismatch: package=%s short=%s build=%s\n' \
        "$repository_version" "$short_version" "$bundle_version" >&2
    exit 1
fi

printf 'package metadata verified: %s (Version: %s, Bundle: %s)\n' \
    "$package" "$package_version" "$short_version"
