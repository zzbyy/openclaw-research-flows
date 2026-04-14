#!/usr/bin/env python3
"""Search Semantic Scholar for papers, authors, and citations.

Usage:
    # Keyword search
    python3 search_semantic_scholar.py --keywords "efficient attention" --days 30

    # Author search
    python3 search_semantic_scholar.py --author "Ashish Vaswani" --max-results 10

    # Citation tracking (papers citing a given paper)
    python3 search_semantic_scholar.py --citations-of "1706.03762" --days 90

    # Combined
    python3 search_semantic_scholar.py --keywords "flash attention" --author "Tri Dao"

Output: JSON array of paper objects to stdout.
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime, timedelta

import requests

SS_API = "https://api.semanticscholar.org/graph/v1"
SS_API_KEY = os.environ.get("SEMANTIC_SCHOLAR_API_KEY", "")

# Rate limiting: 100 requests per 5 minutes without key
REQUEST_DELAY = 3.0  # seconds between requests (conservative)
PAPER_FIELDS = "title,authors,abstract,year,citationCount,paperId,externalIds,venue,publicationDate"


def _headers() -> dict:
    h = {"Accept": "application/json"}
    if SS_API_KEY:
        h["x-api-key"] = SS_API_KEY
    return h


def _rate_limit():
    time.sleep(REQUEST_DELAY)


def search_by_keywords(keywords: list[str], days: int, max_results: int) -> list[dict]:
    """Search papers by keywords."""
    papers = []
    query = " ".join(keywords)
    current_year = datetime.now().year

    # Determine year range from days
    if days <= 365:
        year_filter = f"{current_year - 1}-{current_year}"
    elif days <= 730:
        year_filter = f"{current_year - 2}-{current_year}"
    else:
        year_filter = f"{current_year - 5}-{current_year}"

    try:
        response = requests.get(
            f"{SS_API}/paper/search",
            params={
                "query": query,
                "fields": PAPER_FIELDS,
                "limit": min(max_results, 100),
                "year": year_filter,
            },
            headers=_headers(),
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()

        cutoff = datetime.now() - timedelta(days=days)
        for paper in data.get("data", []):
            pub_date = paper.get("publicationDate")
            if pub_date:
                try:
                    if datetime.fromisoformat(pub_date) < cutoff:
                        continue
                except (ValueError, TypeError):
                    pass

            papers.append(_normalize_paper(paper, "keyword_search"))

    except requests.RequestException as e:
        print(json.dumps({"warning": f"Keyword search failed: {e}"}), file=sys.stderr)

    return papers


def search_by_author(author_name: str, max_results: int) -> list[dict]:
    """Search for papers by a specific author."""
    papers = []

    try:
        # First, find the author
        response = requests.get(
            f"{SS_API}/author/search",
            params={"query": author_name, "limit": 3},
            headers=_headers(),
            timeout=30,
        )
        response.raise_for_status()
        authors = response.json().get("data", [])

        if not authors:
            return []

        _rate_limit()

        # Get papers by the top-matched author
        author_id = authors[0]["authorId"]
        response = requests.get(
            f"{SS_API}/author/{author_id}/papers",
            params={"fields": PAPER_FIELDS, "limit": min(max_results, 100)},
            headers=_headers(),
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()

        for paper in data.get("data", []):
            papers.append(_normalize_paper(paper, "author_search"))

    except requests.RequestException as e:
        print(json.dumps({"warning": f"Author search failed: {e}"}), file=sys.stderr)

    return papers


def search_citations(paper_id: str, days: int, max_results: int) -> list[dict]:
    """Find papers that cite a given paper."""
    papers = []

    # Resolve paper ID (could be arXiv ID, DOI, or SS ID)
    if "/" in paper_id:
        # Likely a DOI
        resolved_id = f"DOI:{paper_id}"
    elif "." in paper_id and len(paper_id) < 15:
        # Likely arXiv ID
        resolved_id = f"ArXiv:{paper_id}"
    else:
        resolved_id = paper_id

    try:
        response = requests.get(
            f"{SS_API}/paper/{resolved_id}/citations",
            params={"fields": PAPER_FIELDS, "limit": min(max_results, 100)},
            headers=_headers(),
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()

        cutoff = datetime.now() - timedelta(days=days)
        for entry in data.get("data", []):
            citing_paper = entry.get("citingPaper", {})
            if not citing_paper.get("title"):
                continue

            pub_date = citing_paper.get("publicationDate")
            if pub_date:
                try:
                    if datetime.fromisoformat(pub_date) < cutoff:
                        continue
                except (ValueError, TypeError):
                    pass

            papers.append(_normalize_paper(citing_paper, "citation_tracking"))

    except requests.RequestException as e:
        print(json.dumps({"warning": f"Citation search failed: {e}"}), file=sys.stderr)

    return papers


def _normalize_paper(paper: dict, source: str) -> dict:
    """Normalize a Semantic Scholar paper into our standard format."""
    external_ids = paper.get("externalIds") or {}
    authors = paper.get("authors") or []

    return {
        "title": paper.get("title", ""),
        "authors": [a.get("name", "") for a in authors],
        "abstract": (paper.get("abstract") or "").replace("\n", " "),
        "ss_id": paper.get("paperId", ""),
        "arxiv_id": external_ids.get("ArXiv"),
        "doi": external_ids.get("DOI"),
        "year": paper.get("year"),
        "citation_count": paper.get("citationCount", 0),
        "venue": paper.get("venue", ""),
        "publication_date": paper.get("publicationDate"),
        "source": source,
    }


def deduplicate(papers: list[dict]) -> list[dict]:
    """Remove duplicate papers by title normalization."""
    seen = {}
    for p in papers:
        key = p["title"].lower().strip()
        if key not in seen:
            seen[key] = p
        else:
            # Merge: keep the one with more metadata
            existing = seen[key]
            if not existing.get("abstract") and p.get("abstract"):
                seen[key] = p
            if p.get("arxiv_id") and not existing.get("arxiv_id"):
                existing["arxiv_id"] = p["arxiv_id"]
            if p.get("doi") and not existing.get("doi"):
                existing["doi"] = p["doi"]
    return list(seen.values())


def main():
    parser = argparse.ArgumentParser(description="Search Semantic Scholar")
    parser.add_argument("--keywords", default="", help="Comma-separated keywords")
    parser.add_argument("--author", default="", help="Author name to search")
    parser.add_argument("--citations-of", default="", help="Paper ID to track citations (arXiv ID, DOI, or SS ID)")
    parser.add_argument("--days", type=int, default=30, help="Look back N days (default: 30)")
    parser.add_argument("--max-results", type=int, default=20, help="Max results per query (default: 20)")
    args = parser.parse_args()

    if not any([args.keywords, args.author, args.citations_of]):
        print(json.dumps({"error": "Provide at least one of: --keywords, --author, --citations-of"}))
        sys.exit(1)

    all_papers = []

    try:
        if args.keywords:
            keywords = [k.strip() for k in args.keywords.split(",") if k.strip()]
            results = search_by_keywords(keywords, args.days, args.max_results)
            all_papers.extend(results)
            if args.author or args.citations_of:
                _rate_limit()

        if args.author:
            results = search_by_author(args.author, args.max_results)
            all_papers.extend(results)
            if args.citations_of:
                _rate_limit()

        if args.citations_of:
            results = search_citations(args.citations_of, args.days, args.max_results)
            all_papers.extend(results)

        all_papers = deduplicate(all_papers)
        print(json.dumps(all_papers, indent=2, ensure_ascii=False))

    except Exception as e:
        print(json.dumps({"error": str(e), "type": type(e).__name__}))
        sys.exit(1)


if __name__ == "__main__":
    main()
