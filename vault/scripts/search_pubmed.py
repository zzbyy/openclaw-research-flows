#!/usr/bin/env python3
"""Search PubMed for papers matching keywords.

Usage:
    python3 search_pubmed.py --keywords "CRISPR,gene editing" --days 7 --max-results 20
    python3 search_pubmed.py --keywords "immunotherapy" --days 30 --email "you@example.com"

Output: JSON array of paper objects to stdout.

Requires: biopython (pip3 install biopython)
"""

import argparse
import json
import sys
import time
from datetime import datetime, timedelta

try:
    from Bio import Entrez, Medline
except ImportError:
    print(json.dumps({
        "error": "biopython not installed. Run: pip3 install biopython",
        "fix": "pip3 install biopython"
    }))
    sys.exit(1)


def search_pubmed(keywords: list[str], days: int, max_results: int, email: str) -> list[dict]:
    """Search PubMed for recent papers matching keywords."""
    Entrez.email = email

    # Build date range
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    date_range = f"{start_date.strftime('%Y/%m/%d')}:{end_date.strftime('%Y/%m/%d')}[pdat]"

    # Build query
    keyword_query = " OR ".join([f'"{kw.strip()}"' for kw in keywords if kw.strip()])
    query = f"({keyword_query}) AND {date_range}"

    papers = []

    try:
        # Step 1: Search for IDs
        handle = Entrez.esearch(
            db="pubmed",
            term=query,
            retmax=max_results,
            sort="pub_date",
            usehistory="y",
        )
        results = Entrez.read(handle)
        handle.close()

        id_list = results.get("IdList", [])
        if not id_list:
            return []

        # Rate limit: NCBI allows 3 requests per second without API key
        time.sleep(0.5)

        # Step 2: Fetch details
        handle = Entrez.efetch(
            db="pubmed",
            id=",".join(id_list),
            rettype="medline",
            retmode="text",
        )
        records = list(Medline.parse(handle))
        handle.close()

        for record in records:
            # Extract DOI from article identifiers
            doi = ""
            aid_list = record.get("AID", [])
            for aid in aid_list:
                if "[doi]" in aid:
                    doi = aid.replace(" [doi]", "")
                    break

            # Parse publication date
            pub_date = record.get("DP", "")
            year = None
            if pub_date:
                try:
                    year = int(pub_date[:4])
                except (ValueError, IndexError):
                    pass

            papers.append({
                "title": record.get("TI", ""),
                "authors": record.get("AU", []),
                "abstract": record.get("AB", ""),
                "pmid": record.get("PMID", ""),
                "doi": doi,
                "journal": record.get("JT", ""),
                "publication_date": pub_date,
                "year": year,
                "mesh_terms": record.get("MH", []),
                "keywords": record.get("OT", []),
                "source": "pubmed",
            })

    except Exception as e:
        print(json.dumps({"warning": f"PubMed search failed: {e}"}), file=sys.stderr)

    return papers


def search_citations(pmid: str, days: int, max_results: int, email: str) -> list[dict]:
    """Find papers that cite a given PubMed article."""
    Entrez.email = email
    papers = []

    try:
        # Use elink to find citing articles
        handle = Entrez.elink(
            dbfrom="pubmed",
            db="pubmed",
            id=pmid,
            linkname="pubmed_pubmed_citedin",
        )
        results = Entrez.read(handle)
        handle.close()

        # Extract citing PMIDs
        citing_ids = []
        for linkset in results:
            for link_db in linkset.get("LinkSetDb", []):
                for link in link_db.get("Link", []):
                    citing_ids.append(link["Id"])

        if not citing_ids:
            return []

        # Limit results
        citing_ids = citing_ids[:max_results]

        time.sleep(0.5)

        # Fetch details
        handle = Entrez.efetch(
            db="pubmed",
            id=",".join(citing_ids),
            rettype="medline",
            retmode="text",
        )
        records = list(Medline.parse(handle))
        handle.close()

        cutoff = datetime.now() - timedelta(days=days)

        for record in records:
            pub_date = record.get("DP", "")
            try:
                year = int(pub_date[:4])
                if year < cutoff.year:
                    continue
            except (ValueError, IndexError):
                pass

            doi = ""
            for aid in record.get("AID", []):
                if "[doi]" in aid:
                    doi = aid.replace(" [doi]", "")
                    break

            papers.append({
                "title": record.get("TI", ""),
                "authors": record.get("AU", []),
                "abstract": record.get("AB", ""),
                "pmid": record.get("PMID", ""),
                "doi": doi,
                "journal": record.get("JT", ""),
                "publication_date": pub_date,
                "year": int(pub_date[:4]) if pub_date else None,
                "mesh_terms": record.get("MH", []),
                "source": "pubmed_citation",
            })

    except Exception as e:
        print(json.dumps({"warning": f"PubMed citation search failed: {e}"}), file=sys.stderr)

    return papers


def main():
    parser = argparse.ArgumentParser(description="Search PubMed for papers")
    parser.add_argument("--keywords", default="", help="Comma-separated keywords")
    parser.add_argument("--citations-of", default="", help="PMID to track citations for")
    parser.add_argument("--days", type=int, default=7, help="Look back N days (default: 7)")
    parser.add_argument("--max-results", type=int, default=20, help="Max results (default: 20)")
    parser.add_argument("--email", default="researcher@example.com",
                        help="Email for NCBI API (required by their terms)")
    args = parser.parse_args()

    if not any([args.keywords, args.citations_of]):
        print(json.dumps({"error": "Provide at least one of: --keywords, --citations-of"}))
        sys.exit(1)

    all_papers = []

    try:
        if args.keywords:
            keywords = [k.strip() for k in args.keywords.split(",") if k.strip()]
            results = search_pubmed(keywords, args.days, args.max_results, args.email)
            all_papers.extend(results)

        if args.citations_of:
            time.sleep(0.5)
            results = search_citations(args.citations_of, args.days, args.max_results, args.email)
            all_papers.extend(results)

        print(json.dumps(all_papers, indent=2, ensure_ascii=False))

    except Exception as e:
        print(json.dumps({"error": str(e), "type": type(e).__name__}))
        sys.exit(1)


if __name__ == "__main__":
    main()
