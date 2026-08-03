#!/usr/bin/env python3
"""Generate a Sileo-compatible flat repository (Packages + Release) for a
directory of .deb files. Usage: make_repo_metadata.py <repo_dir> [suite] [codename]

Filenames in the Packages stanzas are relative to repo_dir (e.g. debs/foo.deb)."""

import hashlib
import os
import subprocess
import sys
import tarfile
import tempfile

def control_of_deb(deb_path):
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(["ar", "x", deb_path], cwd=tmp, check=True, capture_output=True)
        control_tar = os.path.join(tmp, "control.tar.gz")
        if not os.path.exists(control_tar):
            raise RuntimeError(f"no control.tar.gz in {deb_path}")
        with tarfile.open(control_tar, "r:gz") as tf:
            for member in tf.getmembers():
                if member.name.rstrip("/").endswith("control"):
                    fh = tf.extractfile(member)
                    if fh is not None:
                        return fh.read().decode("utf-8", "replace")
            raise RuntimeError(f"no control stanza in {deb_path}")

def main():
    if len(sys.argv) not in (2, 4):
        sys.exit("usage: make_repo_metadata.py <repo_dir> [suite] [codename]")
    repo_dir = sys.argv[1]
    suite = sys.argv[2] if len(sys.argv) >= 3 else "development"
    codename = sys.argv[3] if len(sys.argv) >= 4 else "dev"

    debs = sorted(
        os.path.join(root, f)
        for root, _dirs, files in os.walk(repo_dir)
        for f in files
        if f.endswith(".deb")
    )
    if not debs:
        sys.exit(f"no .deb files in {repo_dir}")

    stanzas = []
    for deb in debs:
        path = os.path.abspath(deb)
        data = open(path, "rb").read()
        size = len(data)
        sha256 = hashlib.sha256(data).hexdigest()
        sha1 = hashlib.sha1(data).hexdigest()
        md5 = hashlib.md5(data).hexdigest()
        rel = os.path.relpath(path, repo_dir)
        control = control_of_deb(path).rstrip()
        stanzas.append(
            f"{control}\n"
            f"Filename: {rel}\n"
            f"Size: {size}\n"
            f"MD5sum: {md5}\n"
            f"SHA1: {sha1}\n"
            f"SHA256: {sha256}\n"
        )

    packages = "\n".join(stanzas)
    with open(os.path.join(repo_dir, "Packages"), "w") as f:
        f.write(packages)

    import bz2, gzip, lzma
    variants = {"Packages.gz": gzip.compress(packages.encode(), compresslevel=9),
                "Packages.bz2": bz2.compress(packages.encode(), compresslevel=9)}
    try:
        variants["Packages.xz"] = lzma.compress(packages.encode())
    except Exception:
        pass
    for name, data in variants.items():
        with open(os.path.join(repo_dir, name), "wb") as f:
            f.write(data)

    entries = ["Packages"] + [n for n in ("Packages.gz", "Packages.bz2", "Packages.xz") if n in variants]
    lines = [
        "Origin: Nicks Works",
        "Label: Nicks Works",
        "Suite: " + suite,
        "Version: 1.0",
        "Codename: " + codename,
        "Architectures: iphoneos-arm64 iphoneos-arm64e",
        "Components: main",
        "Description: dotto++ package feed",
    ]
    for hashtype in ("MD5Sum", "SHA1", "SHA256"):
        lines.append(hashtype + ":")
        for name in entries:
            data = open(os.path.join(repo_dir, name), "rb").read()
            digest = {"MD5Sum": hashlib.md5, "SHA1": hashlib.sha1, "SHA256": hashlib.sha256}[hashtype](data).hexdigest()
            lines.append(f" {digest} {len(data)} {name}")
    with open(os.path.join(repo_dir, "Release"), "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"repo metadata written for {len(debs)} package(s) in {repo_dir}")

if __name__ == "__main__":
    main()
