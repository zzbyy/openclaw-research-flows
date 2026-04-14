# /briefing Command — Daily Research Briefing

Generate a daily research briefing integrated with your wiki knowledge.

## Input
- `--sources [arxiv,semantic,pubmed]`: Which sources to scan (default: all)
- `--days [n]`: Look back n days (default: 1)
- `--deep`: Include citation analysis
- `--quiet`: No Telegram notification

## Examples
```bash
/briefing                           # Standard morning briefing
/briefing --days 3                  # Weekend catch-up
/briefing --sources arxiv           # arXiv only
/briefing --deep                    # Include citation network analysis
```

---

## Overview

The daily briefing:
1. Scans research sources for new papers
2. Scores relevance against your thesis + wiki knowledge
3. Auto-ingests high-priority papers
4. Generates a briefing note in Daily Notes/
5. Updates wiki with new connections
6. Notifies via OpenClaw

---

## Step 1: Load Research Context

Read from CLAUDE.md and wiki to build context:

```python
# Load your research profile
research_context = {
    'field': extract_from_claude_md('field'),
    'thesis': extract_from_claude_md('thesis'),
    'keywords': extract_from_claude_md('keywords'),
    'tracked_researchers': extract_from_claude_md('tracked_researchers'),
}

# Load wiki context for smarter relevance scoring
wiki_context = {
    'recent_papers': get_recent_summaries(days=30),
    'active_concepts': get_high_confidence_concepts(),
    'open_questions': get_open_questions(),
    'tracked_citations': get_citation_seeds(),
}
```

---

## Step 2: Scan Sources

### 2.1 arXiv Scan

```python
import arxiv

# Build query from keywords
query_parts = []
for kw in research_context['keywords']:
    query_parts.append(f'all:"{kw}"')

# Add category filters (adjust for your field)
categories = ['cs.LG', 'cs.CL', 'cs.AI', 'stat.ML']
cat_filter = ' OR '.join([f'cat:{c}' for c in categories])

query = f"({' OR '.join(query_parts)}) AND ({cat_filter})"

# Search
search = arxiv.Search(
    query=query,
    max_results=50,
    sort_by=arxiv.SortCriterion.SubmittedDate,
    sort_order=arxiv.SortOrder.Descending
)

arxiv_papers = []
for result in search.results():
    # Filter by date
    if result.published.date() >= date.today() - timedelta(days=days):
        arxiv_papers.append({
            'title': result.title,
            'authors': [a.name for a in result.authors],
            'abstract': result.summary,
            'arxiv_id': result.entry_id.split('/')[-1],
            'pdf_url': result.pdf_url,
            'published': result.published,
            'categories': result.categories,
            'source': 'arxiv'
        })
```

### 2.2 Semantic Scholar Scan

```python
import requests

SS_API = "https://api.semanticscholar.org/graph/v1"

# Search by keywords
for kw in research_context['keywords'][:3]:  # Top 3 keywords
    response = requests.get(
        f"{SS_API}/paper/search",
        params={
            'query': kw,
            'fields': 'title,authors,abstract,year,citationCount,paperId,externalIds',
            'limit': 20,
            'year': f"{date.today().year - 1}-{date.today().year}"
        },
        headers={'x-api-key': SS_API_KEY} if SS_API_KEY else {}
    )
    
    for paper in response.json().get('data', []):
        ss_papers.append({
            'title': paper['title'],
            'authors': [a['name'] for a in paper.get('authors', [])],
            'abstract': paper.get('abstract', ''),
            'ss_id': paper['paperId'],
            'citation_count': paper.get('citationCount', 0),
            'arxiv_id': paper.get('externalIds', {}).get('ArXiv'),
            'doi': paper.get('externalIds', {}).get('DOI'),
            'source': 'semantic_scholar'
        })

# Track citations to your key papers
for seed_paper_id in wiki_context['tracked_citations']:
    citations = get_citations(seed_paper_id, limit=10)
    for cite in citations:
        if cite['year'] >= date.today().year - 1:
            ss_papers.append({**cite, 'source': 'citation_tracking'})
```

### 2.3 PubMed Scan (if biomedical)

```python
from Bio import Entrez

Entrez.email = "your@email.com"

for kw in research_context['keywords']:
    handle = Entrez.esearch(
        db="pubmed",
        term=f"{kw} AND {date.today().year}[pdat]",
        retmax=20,
        sort="pub_date"
    )
    # ... extract paper details
```

---

## Step 3: Deduplicate

Merge results from all sources:

```python
def dedupe_papers(all_papers):
    seen = {}
    for paper in all_papers:
        # Create fingerprint
        title_norm = normalize_title(paper['title'])
        
        if title_norm in seen:
            # Merge metadata from multiple sources
            seen[title_norm] = merge_paper_data(seen[title_norm], paper)
        else:
            seen[title_norm] = paper
    
    return list(seen.values())

all_papers = dedupe_papers(arxiv_papers + ss_papers + pubmed_papers)
```

---

## Step 4: Score Relevance

Score each paper against your research context AND existing wiki:

```python
def score_paper(paper, research_context, wiki_context):
    score = 0
    reasons = []
    
    title_abstract = f"{paper['title']} {paper['abstract']}".lower()
    
    # Keyword matching (primary)
    for kw in research_context['keywords'][:3]:
        if kw.lower() in title_abstract:
            score += 15
            reasons.append(f"Primary keyword: {kw}")
    
    # Keyword matching (secondary)
    for kw in research_context['keywords'][3:]:
        if kw.lower() in title_abstract:
            score += 8
            reasons.append(f"Secondary keyword: {kw}")
    
    # Tracked researcher bonus
    for author in paper['authors']:
        for tracked in research_context['tracked_researchers']:
            if tracked['name'].lower() in author.lower():
                score += 25
                reasons.append(f"Tracked researcher: {tracked['name']}")
    
    # Wiki connection bonus - existing concepts
    for concept in wiki_context['active_concepts']:
        if concept['name'].lower() in title_abstract:
            score += 12
            reasons.append(f"Wiki concept: {concept['name']}")
    
    # Wiki connection bonus - answers open question
    for question in wiki_context['open_questions']:
        question_keywords = extract_keywords(question['text'])
        matches = sum(1 for qk in question_keywords if qk in title_abstract)
        if matches >= 2:
            score += 20
            reasons.append(f"Addresses question: {question['text'][:50]}...")
    
    # Citation tracking bonus
    if paper.get('source') == 'citation_tracking':
        score += 18
        reasons.append("Cites your tracked paper")
    
    # Recency bonus
    if paper.get('published'):
        days_old = (date.today() - paper['published'].date()).days
        if days_old <= 1:
            score += 10
            reasons.append("Published today/yesterday")
        elif days_old <= 7:
            score += 5
    
    # High citation velocity (if available)
    if paper.get('citation_count', 0) > 10:
        score += 5
        reasons.append(f"Already {paper['citation_count']} citations")
    
    return {
        'score': score,
        'tier': 'high' if score >= 40 else 'medium' if score >= 20 else 'low',
        'reasons': reasons
    }

# Score all papers
for paper in all_papers:
    paper['relevance'] = score_paper(paper, research_context, wiki_context)

# Sort by score
all_papers.sort(key=lambda x: -x['relevance']['score'])
```

---

## Step 5: Auto-Ingest High Priority

```python
ingested = []
to_triage = []

for paper in all_papers:
    if paper['relevance']['tier'] == 'high':
        # Download PDF
        pdf_path = download_paper(paper)
        
        if pdf_path:
            # Run ingest workflow
            result = ingest_paper(pdf_path, paper)
            ingested.append({
                'paper': paper,
                'summary_path': result['summary_path']
            })
        else:
            # Couldn't download, create stub
            stub_path = create_stub_summary(paper)
            ingested.append({
                'paper': paper,
                'summary_path': stub_path,
                'note': 'PDF unavailable, stub created'
            })
    
    elif paper['relevance']['tier'] == 'medium':
        to_triage.append(paper)

# Cap ingestion to avoid overwhelming
MAX_AUTO_INGEST = 5
if len(ingested) > MAX_AUTO_INGEST:
    overflow = ingested[MAX_AUTO_INGEST:]
    ingested = ingested[:MAX_AUTO_INGEST]
    to_triage = [o['paper'] for o in overflow] + to_triage
```

---

## Step 6: Generate Briefing Note

Create `Daily Notes/YYYY-MM-DD.md` (or append to existing):

```markdown
# Daily Research Briefing — YYYY-MM-DD

## 🎯 High Priority (Auto-Ingested)

{{for paper in ingested}}
### [[{{paper.summary_path}}|{{paper.title}}]]
**Authors**: {{paper.authors | join(", ")}}
**Why relevant**: {{paper.relevance.reasons | join(" • ")}}
**Score**: {{paper.relevance.score}}/100

> {{paper.abstract | truncate(300)}}

**Wiki connections**: {{paper.wiki_links | join(", ")}}

---
{{endfor}}

## 📋 To Triage (Medium Priority)

| Paper | Authors | Score | Why |
|-------|---------|-------|-----|
{{for paper in to_triage[:10]}}
| {{paper.title | truncate(50)}} | {{paper.authors[0]}} et al. | {{paper.relevance.score}} | {{paper.relevance.reasons[0]}} |
{{endfor}}

{{if to_triage | length > 10}}
*+{{to_triage | length - 10}} more papers in triage queue*
{{endif}}

## 📊 Briefing Stats

- **Sources scanned**: arXiv, Semantic Scholar{{", PubMed" if pubmed else ""}}
- **Papers found**: {{all_papers | length}}
- **High priority**: {{ingested | length}} (auto-ingested)
- **Medium priority**: {{to_triage | length}} (to triage)
- **Low priority**: {{all_papers | length - ingested | length - to_triage | length}} (skipped)

## 🔗 Wiki Impact

### New Connections Made
{{for connection in new_wiki_connections}}
- [[{{connection.from}}]] → [[{{connection.to}}]] ({{connection.type}})
{{endfor}}

### Open Questions Potentially Addressed
{{for question in addressed_questions}}
- [[{{question.path}}]]: {{question.text | truncate(60)}}
  - Potentially by: [[{{question.paper_summary}}]]
{{endfor}}

### Suggested Follow-ups
- [ ] Review triage queue ({{to_triage | length}} papers)
- [ ] Check [[wiki/contradictions/]] for new flags
{{for suggestion in suggestions}}
- [ ] {{suggestion}}
{{endfor}}

---
*Generated by `/briefing` at {{timestamp}}*
```

---

## Step 7: Update Wiki Cross-References

```python
# For each ingested paper, update wiki connections
for item in ingested:
    paper = item['paper']
    summary_path = item['summary_path']
    
    # Find concept pages that should link to this
    for concept in wiki_context['active_concepts']:
        if concept['name'].lower() in paper['abstract'].lower():
            # Add backlink to concept page
            add_backlink(
                target=f"wiki/concepts/{concept['slug']}.md",
                source=summary_path,
                section="## Related Papers"
            )
    
    # Check if this addresses any open questions
    for question in wiki_context['open_questions']:
        if is_potentially_relevant(paper, question):
            # Add note to question page
            add_to_question(
                question_path=question['path'],
                note=f"Potentially addressed by [[{summary_path}]]"
            )
    
    # Update graph.md with new relationships
    append_to_graph(summary_path, paper['extracted_relationships'])
```

---

## Step 8: Notify via OpenClaw

Format output for Telegram relay:

```
📬 Morning Briefing — YYYY-MM-DD

🎯 HIGH PRIORITY ({{ingested | length}})
{{for paper in ingested[:3]}}
• {{paper.title | truncate(60)}}
  {{paper.relevance.reasons[0]}}
{{endfor}}
{{if ingested | length > 3}}
  +{{ingested | length - 3}} more...
{{endif}}

📋 TO TRIAGE: {{to_triage | length}} papers

📊 Wiki updated:
• {{new_connections}} new connections
• {{entities_created}} entities created

📖 Full briefing: Daily Notes/{{date}}.md
```

---

## Step 9: Update Log

Append to `wiki/log.md`:

```markdown
## [YYYY-MM-DD HH:MM] briefing | Daily research scan

### Sources
- arXiv: {{arxiv_count}} papers
- Semantic Scholar: {{ss_count}} papers
- Citation tracking: {{citation_count}} papers

### Results
- Total found: {{total}}
- High priority: {{high}} (ingested)
- Medium priority: {{medium}} (triage)
- Low priority: {{low}} (skipped)

### Ingested
{{for paper in ingested}}
- [[{{paper.summary_path}}]] — Score: {{paper.score}}
{{endfor}}

### Wiki Updates
- Connections added: {{connections}}
- Entities created: {{entities}}
- Questions addressed: {{questions}}
```

---

## Integration with Obsidian

The briefing note lands in `Daily Notes/` where Obsidian displays it naturally.

### Dataview Queries (optional)

Add to your Obsidian dashboard:

```dataview
TABLE score as "Score", status as "Status"
FROM "wiki/summaries"
WHERE created = date(today)
SORT score DESC
```

### Graph View

After briefing runs, Obsidian's graph view shows new connections radiating from today's ingested papers.

### Calendar Plugin

Briefing notes appear in the calendar, creating a research timeline.

---

## Heartbeat Schedule

Add to `HEARTBEAT.md`:

```markdown
## Daily: 7:00 AM — Morning Briefing
```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/briefing" \
       --auto-approve \
       --timeout 600
```

Parse output, relay summary to Telegram.
If errors, relay: "⚠️ Briefing failed: [reason]"

## Daily: 7:00 PM — Evening Triage Reminder
If papers_in_triage > 0:
    Send: "📋 {{count}} papers awaiting triage from this morning"
```

---

## Customization

### Adjust Scoring Weights

Edit the scoring function in `commands/briefing.md` or create `config/briefing-weights.yaml`:

```yaml
scoring:
  primary_keyword: 15
  secondary_keyword: 8
  tracked_researcher: 25
  wiki_concept_match: 12
  open_question_match: 20
  citation_tracking: 18
  recency_today: 10
  recency_week: 5
  high_citations: 5

thresholds:
  high_priority: 40
  medium_priority: 20
```

### Field-Specific Sources

For biomedical research, enable PubMed:
```bash
/briefing --sources arxiv,semantic,pubmed
```

For pure ML, maybe just arXiv:
```bash
/briefing --sources arxiv
```
