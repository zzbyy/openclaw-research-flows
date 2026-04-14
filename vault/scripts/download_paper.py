#!/usr/bin/env python3
"""Download a paper PDF to the local vault.

Usage:
    python3 download_paper.py --url "https://arxiv.org/pdf/1706.03762" --dest raw/papers/
    python3 download_paper.py --url "https://arxiv.org/pdf/1706.03762" --dest raw/inbox/ --filename "attention.pdf"

Output: JSON with download result to stdout.
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path
from urllib.parse import urlparse

import requests


def sanitize_filename(name: str, max_len: int = 80) -> str:
    """Create a filesystem-safe filename."""
    name = re.sub(r'[^\w\-.]', '_', name)
    name = re.sub(r'_+', '_', name).strip('_')
    return name[:max_len]


def resolve_arxiv_url(url: str) -> str:
    """Convert arXiv abstract URLs to PDF URLs."""
    # https://arxiv.org/abs/1706.03762 -> https://arxiv.org/pdf/1706.03762.pdf
    if "arxiv.org/abs/" in url:
        arxiv_id = url.split("/abs/")[-1].split("?")[0].split("#")[0]
        return f"https://arxiv.org/pdf/{arxiv_id}.pdf"
    return url


def guess_filename(url: str, headers: dict) -> str:
    """Guess a filename from URL or response headers."""
    # Check Content-Disposition header
    cd = headers.get("Content-Disposition", "")
    if "filename=" in cd:
        match = re.search(r'filename="?([^";\n]+)"?', cd)
        if match:
            return sanitize_filename(match.group(1))

    # Extract from URL path
    path = urlparse(url).path
    basename = os.path.basename(path)
    if basename and "." in basename:
        return sanitize_filename(basename)

    # Fallback: timestamp-based
    return f"paper_{int(time.time())}.pdf"


def download(url: str, dest_dir: str, filename: str = "") -> dict:
    """Download a file from URL to destination directory."""
    dest_path = Path(dest_dir)
    dest_path.mkdir(parents=True, exist_ok=True)

    # Resolve special URLs
    url = resolve_arxiv_url(url)

    # Download with streaming
    response = requests.get(
        url,
        stream=True,
        timeout=120,
        headers={"User-Agent": "ResearchWiki/1.0 (academic use)"},
        allow_redirects=True,
    )
    response.raise_for_status()

    # Determine filename
    if not filename:
        filename = guess_filename(url, response.headers)
    if not filename.endswith(".pdf"):
        filename += ".pdf"
    filename = sanitize_filename(filename)

    # Check if already exists
    target = dest_path / filename
    if target.exists():
        return {
            "success": True,
            "local_path": str(target),
            "filename": filename,
            "size_bytes": target.stat().st_size,
            "note": "Already exists, skipped download",
        }

    # Write file
    total_size = 0
    with open(target, "wb") as f:
        for chunk in response.iter_content(chunk_size=8192):
            f.write(chunk)
            total_size += len(chunk)

    # Verify it looks like a PDF
    with open(target, "rb") as f:
        header = f.read(5)
    if header != b"%PDF-":
        # Not a PDF — might be HTML error page
        os.remove(target)
        return {
            "success": False,
            "error": "Downloaded file is not a valid PDF",
            "url": url,
        }

    return {
        "success": True,
        "local_path": str(target),
        "filename": filename,
        "size_bytes": total_size,
    }


def main():
    parser = argparse.ArgumentParser(description="Download a paper PDF")
    parser.add_argument("--url", required=True, help="URL to download")
    parser.add_argument("--dest", default="raw/papers/", help="Destination directory (default: raw/papers/)")
    parser.add_argument("--filename", default="", help="Override filename (optional)")
    args = parser.parse_args()

    try:
        result = download(args.url, args.dest, args.filename)
        print(json.dumps(result, indent=2))
        if not result["success"]:
            sys.exit(1)
    except requests.RequestException as e:
        print(json.dumps({"success": False, "error": str(e), "type": type(e).__name__}))
        sys.exit(1)
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e), "type": type(e).__name__}))
        sys.exit(1)


if __name__ == "__main__":
    main()
