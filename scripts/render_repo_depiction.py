#!/usr/bin/env python3
"""Render the Sileo/Zebra package depiction for dotto++."""

from __future__ import annotations

import argparse
import html
import json
import re
from pathlib import Path

PACKAGE = "com.nicksworks.dottoplusplus"
LINKS = [
    ("Source on GitHub", "https://github.com/hadobedo/dotto-"),
    ("Support on Ko-fi", "https://ko-fi.com/nicksworks"),
    ("X / Twitter", "https://twitter.com/Nicks_Works"),
    ("Instagram", "https://instagram.com/Nicks_Works"),
    ("YouTube", "https://www.youtube.com/@NicksWorks"),
]


def read_sections(path: Path) -> list[tuple[str, list[str]]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    starts = []
    for index, line in enumerate(lines):
        match = re.match(r"^##\s+(?:\[([^]]+)\]|(.+))$", line)
        if match:
            starts.append((index, match.group(1) or match.group(2)))

    sections: list[tuple[str, list[str]]] = []
    for position, (start, version) in enumerate(starts):
        end = starts[position + 1][0] if position + 1 < len(starts) else len(lines)
        entries = [line[2:].strip() for line in lines[start + 1 : end] if line.startswith("- ")]
        if entries:
            sections.append((version, entries))
    return sections


def markdown_inline(value: str) -> str:
    rendered = html.escape(value, quote=False)
    rendered = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", rendered)
    rendered = re.sub(r"`([^`]+)`", r"<code>\1</code>", rendered)
    return rendered


def markdown_list(entries: list[str]) -> str:
    return "\n".join(f"- {entry}" for entry in entries)


def html_list(entries: list[str]) -> str:
    return "\n".join(f"          <li>{markdown_inline(entry)}</li>" for entry in entries)


def sileo_button(title: str, action: str) -> dict[str, str]:
    return {
        "class": "DepictionTableButtonView",
        "title": title,
        "action": action,
        "openExternal": True,
    }


def render_sileo(version: str, sections: list[tuple[str, list[str]]], base_url: str) -> dict:
    current_entries = sections[0][1]
    info_views: list[dict] = [
        {
            "class": "DepictionMarkdownView",
            "markdown": (
                "Minimalistic notification dots, rebuilt for iOS 15–17"
            ),
            "useSpacing": True,
        },
        {"class": "DepictionSeparatorView"},
        {"class": "DepictionHeaderView", "title": "Information"},
        {"class": "DepictionTableTextView", "title": "Version", "text": version},
        {
            "class": "DepictionTableTextView",
            "title": "Compatibility",
            "text": "iOS 15–17",
        },
        {
            "class": "DepictionTableTextView",
            "title": "Formats",
            "text": "Rootless · RootHide",
        },
        {
            "class": "DepictionTableTextView",
            "title": "Package ID",
            "text": PACKAGE,
        },
        {"class": "DepictionSeparatorView"},
        {"class": "DepictionHeaderView", "title": "Links"},
    ]
    info_views.extend(sileo_button(title, url) for title, url in LINKS)
    info_views.extend(
        [
            {"class": "DepictionSeparatorView"},
            {"class": "DepictionHeaderView", "title": "At a glance"},
            {
                "class": "DepictionMarkdownView",
                "markdown": markdown_list(current_entries[:5]),
                "useSpacing": True,
            },
        ]
    )

    changelog_views: list[dict] = []
    for section_version, entries in sections:
        changelog_views.extend(
            [
                {
                    "class": "DepictionSubheaderView",
                    "title": section_version,
                    "useBoldText": True,
                    "useBottomMargin": False,
                },
                {
                    "class": "DepictionMarkdownView",
                    "markdown": markdown_list(entries),
                    "useSpacing": True,
                },
            ]
        )

    return {
        "class": "DepictionTabView",
        "minVersion": "0.3",
        "tintColor": "#B96DFF",
        "tabs": [
            {
                "class": "DepictionStackView",
                "tabname": "Details",
                "views": info_views,
            },
            {
                "class": "DepictionStackView",
                "tabname": "Changelog",
                "views": changelog_views,
            },
        ],
    }


def render_html(version: str, sections: list[tuple[str, list[str]]], base_url: str) -> str:
    current_entries = sections[0][1]
    links = "\n".join(
        f'<a href="{html.escape(url, quote=True)}" target="_blank" rel="noreferrer">'
        f"{html.escape(title)} <span>↗</span></a>"
        for title, url in LINKS
    )
    changelog = "\n".join(
        f"        <section><h3>{html.escape(section_version)}</h3><ul>{html_list(entries)}</ul></section>"
        for section_version, entries in sections
    )
    glance = html_list(current_entries[:5])
    return f'''<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#B96DFF">
  <title>dotto++ {html.escape(version)} · Nick's Works</title>
  <style>
    :root {{ color-scheme: dark light; --bg:#15121c; --card:#211b2a; --line:#3c324b; --text:#f7f3fb; --muted:#b9afc5; --accent:#c687ff; }}
    * {{ box-sizing:border-box; }}
    body {{ margin:0; background:var(--bg); color:var(--text); font:16px/1.55 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }}
    main {{ max-width:680px; margin:0 auto; padding:28px 20px 42px; }}
    .package {{ display:flex; align-items:center; gap:16px; margin:4px 0 26px; }}
    .icon {{ width:76px; height:76px; border-radius:18px; box-shadow:0 8px 28px #0006; }}
    h1 {{ margin:0; font-size:28px; letter-spacing:-.04em; }}
    .version {{ color:var(--accent); font-size:15px; }}
    .sub {{ margin:3px 0 0; color:var(--muted); }}
    .card {{ margin:16px 0; padding:20px; border:1px solid var(--line); border-radius:18px; background:var(--card); }}
    h2 {{ margin:0 0 10px; font-size:18px; }} h3 {{ margin:20px 0 7px; color:var(--accent); font-size:16px; }}
    p {{ color:var(--muted); }} ul {{ margin:8px 0 0; padding-left:22px; color:var(--muted); }} li {{ margin:7px 0; }}
    .links {{ display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:9px; }}
    .links a {{ padding:10px 12px; border:1px solid var(--line); border-radius:10px; color:var(--text); text-decoration:none; }}
    .links span {{ float:right; color:var(--accent); }}
    footer {{ color:var(--muted); font-size:12px; text-align:center; }}
    @media (max-width:480px) {{ .links {{ grid-template-columns:1fr; }} }}
  </style>
</head>
<body>
  <main>
    <header class="package">
      <img class="icon" src="{html.escape(base_url, quote=True)}/assets/dottoplusplus.png" alt="dotto++ icon">
      <div><h1>dotto++</h1><div class="version">Version {html.escape(version)}</div><p class="sub">Nick's Works · iOS 15–17</p></div>
    </header>
    <section class="card">
      <h2>About</h2>
      <p>A focused badge redesign for modern rootless and RootHide devices. dotto++ keeps the familiar dotto+ look while improving badge placement, adaptive colour, SnowBoard compatibility, and idle performance.</p>
      <ul>{glance}</ul>
    </section>
    <section class="card"><h2>Links</h2><div class="links">{links}</div></section>
    <section class="card"><h2>Changelog</h2>{changelog}</section>
    <footer>{PACKAGE} · <a href="{html.escape(base_url, quote=True)}/Packages">APT metadata</a></footer>
  </main>
</body>
</html>
'''


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--version", required=True)
    parser.add_argument("--base-url", required=True)
    parser.add_argument(
        "--changelog",
        type=Path,
        default=Path(__file__).resolve().parent.parent / "CHANGELOG.md",
    )
    args = parser.parse_args()

    sections = read_sections(args.changelog)
    if not sections or sections[0][0] != args.version:
        raise SystemExit(f"expected CHANGELOG.md to start with section {args.version}")

    args.output_dir.mkdir(parents=True, exist_ok=True)
    depiction_json = render_sileo(args.version, sections, args.base_url)
    (args.output_dir / f"{PACKAGE}.json").write_text(
        json.dumps(depiction_json, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    (args.output_dir / f"{PACKAGE}.html").write_text(
        render_html(args.version, sections, args.base_url),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
