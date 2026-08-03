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

tar -xzf "$tmpdir/control.tar.gz" -C "$tmpdir"
package_control="$tmpdir/control"
package_version=$(read_control_version "$package_control")
if [[ $package_version != "$repository_version" ]]; then
    printf 'package Version mismatch: repository=%s package=%s\n' \
        "$repository_version" "$package_version" >&2
    exit 1
fi

grep -Fx 'Package: me.conorthedev.dotto+' "$package_control"
grep -Fx 'Architecture: iphoneos-arm64e' "$package_control"
grep -F 'Depends: firmware (>= 17.0), ellekit, preferenceloader' "$package_control"

printf 'package metadata verified: %s (Version: %s)\n' \
    "$package" "$package_version"
