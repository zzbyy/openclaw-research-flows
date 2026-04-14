#!/usr/bin/env python3
"""Search arXiv for papers matching keywords and categories.

Usage:
    python3 search_arxiv.py --keywords "attention,transformer" --categories "cs.LG,cs.CL" --days 1
    python3 search_arxiv.py --keywords "efficient attention" --max-results 10

Output: JSON array of paper objects to stdout.
"""

import argparse
import json
import sys
import time
from datetime import datetime, timedelta, timezone

try:
    import arxiv
except ImportError:
    print(json.dumps({"error": "arxiv package not installed. Run: pip3 install arxiv"}), file=sys.stderr)
    sys.exit(1)


def search_papers(keywords: list[str], categories: list[str], days: int, max_results: int) -> list[dict]:
    """Search arXiv for papers matching criteria."""
    # Build query
    keyword_parts = [f'all:"{kw.strip()}"' for kw in keywords if kw.strip()]
    keyword_query = " OR ".join(keyword_parts)

    if categories:
        cat_parts = [f"cat:{c.strip()}" for c in categories if c.strip()]
        cat_query = " OR ".join(cat_parts)
        query = f"({keyword_query}) AND ({cat_query})"
    else:
        query = keyword_query

    if not query.strip("() "):
        return []

    # Search with rate limiting (arXiv requires 3s between requests)
    client = arxiv.Client(page_size=max_results, delay_seconds=3.0, num_retries=3)
    search = arxiv.Search(
        query=query,
        max_results=max_results,
        sort_by=arxiv.SortCriterion.SubmittedDate,
        sort_order=arxiv.SortOrder.Descending,
    )

    cutoff_date = datetime.now(timezone.utc) - timedelta(days=days)
    papers = []

    for result in client.results(search):
        # Filter by date
        published = result.published.replace(tzinfo=timezone.utc) if result.published.tzinfo is None else result.published
        if published < cutoff_date:
            continue

        papers.append({
            "title": result.title,
            "authors": [a.name for a in result.authors],
            "abstract": result.summary.replace("\n", " "),
            "arxiv_id": result.entry_id.split("/")[-1],
            "pdf_url": result.pdf_url,
            "published": result.published.isoformat(),
            "updated": result.updated.isoformat() if result.updated else None,
            "categories": result.categories,
            "primary_category": result.primary_category,
            "source": "arxiv",
        })

    return papers


def main():
    parser = argparse.ArgumentParser(description="Search arXiv for papers")
    parser.add_argument("--keywords", required=True, help="Comma-separated keywords")
    parser.add_argument("--categories", default="", help="Comma-separated arXiv categories (e.g., cs.LG,cs.CL)")
    parser.add_argument("--days", type=int, default=1, help="Look back N days (default: 1)")
    parser.add_argument("--max-results", type=int, default=50, help="Max results (default: 50)")
    args = parser.parse_args()

    keywords = [k.strip() for k in args.keywords.split(",") if k.strip()]
    categories = [c.strip() for c in args.categories.split(",") if c.strip()]

    if not keywords:
        print(json.dumps({"error": "No keywords provided"}))
        sys.exit(1)

    try:
        papers = search_papers(keywords, categories, args.days, args.max_results)
        print(json.dumps(papers, indent=2, ensure_ascii=False))
    except Exception as e:
        print(json.dumps({"error": str(e), "type": type(e).__name__}))
        sys.exit(1)


if __name__ == "__main__":
    main()
