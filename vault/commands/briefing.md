# /briefing — Daily Research Briefing

Generate a daily research briefing: scan sources, score relevance, auto-ingest top papers, generate a Daily Note.

## Input

- `--days [n]`: Look back n days (default: 1)
- `--deep`: Include citation analysis and wiki connection mapping
- `--quiet`: No Telegram notification (log only)

## Examples

```bash
/briefing                           # Standard morning briefing
/briefing --days 3                  # Weekend catch-up
/briefing --deep                    # Include citation network analysis
```

---

## Step 1: Load Research Context

Read from CLAUDE.md to build your research profile:

- **Field** and **thesis**
- **Primary keywords** (for high-priority matching)
- **Secondary keywords** (for medium-priority matching)
- **Tracked researchers** (for author alerts)
- **Key papers** (for citation tracking)
- **arXiv categories** (for source filtering)

---

## Step 2: Load Wiki Context

Read from the wiki to inform relevance scoring:

1. **Recent summaries**: Read `wiki/_index.md` and scan `wiki/summaries/` for papers from the last 30 days
2. **Active concepts**: Read `wiki/concepts/` — these are topics you're actively tracking
3. **Open questions**: Read `wiki/questions/` — papers that address these get a boost
4. **Tracked citations**: From `wiki/monitoring/config.md` — papers citing these are relevant

This context helps you score papers more intelligently than keyword matching alone.

---

## Step 3: Search arXiv

Run the arXiv search script with keywords from CLAUDE.md:

```bash
python3 scripts/search_arxiv.py \
  --keywords "[primary_keyword1],[primary_keyword2],[secondary_keyword1]" \
  --categories "[categories from CLAUDE.md]" \
  --days [days] \
  --max-results 50
```

Parse the JSON output. Each result has: title, authors, abstract, arxiv_id, pdf_url, published, categories.

---

## Step 4: Search Semantic Scholar

Run the Semantic Scholar search:

```bash
python3 scripts/search_semantic_scholar.py \
  --keywords "[top 3 keywords]" \
  --days [days * 7] \
  --max-results 30
```

If citation tracking is configured, also run:
```bash
python3 scripts/search_semantic_scholar.py \
  --citations-of "[paper_id]" \
  --days [days * 30] \
  --max-results 10
```

---

## Step 4b: Search PubMed (if enabled)

Check `wiki/monitoring/config.md` — if `pubmed.enabled: true`:

```bash
python3 scripts/search_pubmed.py \
  --keywords "[primary_keyword1],[primary_keyword2]" \
  --days [days * 7] \
  --max-results 20 \
  --email "[pubmed.email from config.md]"
```

If citation tracking is configured for PMIDs:
```bash
python3 scripts/search_pubmed.py \
  --citations-of "[pmid]" \
  --days [days * 30] \
  --max-results 10 \
  --email "[pubmed.email from config.md]"
```

Parse the JSON output.

---

## Step 5: Deduplicate

Merge results from all sources. Papers may appear in both arXiv and Semantic Scholar.
Deduplicate by normalized title (lowercase, strip whitespace). When merging, keep metadata from both sources (e.g., arXiv ID from arXiv, citation count from Semantic Scholar).

---

## Step 6: Score Relevance

**This is where Opus 4.6 shines.** Rather than rigid keyword matching, use your understanding of the research context and wiki knowledge to score each paper holistically.

For each paper, consider:

1. **Keyword relevance**: Does the title/abstract address your primary or secondary keywords?
2. **Researcher match**: Is any author a tracked researcher from CLAUDE.md?
3. **Wiki connections**: Does this paper relate to existing concepts in your wiki?
4. **Open questions**: Could this paper address any of your open research questions?
5. **Citation tracking**: Does this paper cite one of your tracked papers?
6. **Recency**: Published today/this week gets a boost
7. **Impact signals**: High citation count for its age, published at major venue

Assign each paper a tier:
- **high** (score >= 40): Auto-ingest — directly relevant to your research
- **medium** (score 20-39): Add to triage — worth reviewing
- **low** (score < 20): Skip — not relevant enough

For each high/medium paper, note 1-2 reasons why it's relevant.

**Sort all papers by score descending.**

---

## Step 7: Auto-Ingest High Priority Papers

For each **high-tier** paper (max 5):

1. Download the PDF:
   ```bash
   python3 scripts/download_paper.py --url "[pdf_url]" --dest raw/papers/
   ```

2. If download succeeds, run the full `/ingest` workflow on it (follow `commands/ingest.md`)

3. If download fails, create a stub summary with the metadata you have:
   ```markdown
   ---
   title: "[title]"
   authors: [authors]
   year: YYYY
   arxiv: "[id]"
   confidence: 0.5
   status: stub-pdf-unavailable
   ---

   ## Summary
   [Write summary from abstract only]

   ## Note
   PDF download failed. Summary based on abstract only. Confidence reduced.
   ```

Track what was ingested:
```python
ingested = []  # List of {paper, summary_path}
```

---

## Step 8: Generate Daily Note

Create `Daily Notes/YYYY-MM-DD.md`:

```markdown
# Daily Research Briefing — YYYY-MM-DD

## High Priority (Auto-Ingested)

[For each ingested paper:]
### [[wiki/summaries/YYYYMMDD-title|Title]]
**Authors**: Author1, Author2
**Why relevant**: [1-2 reasons from scoring]
**Score**: [score]/100

> [First 300 chars of abstract]

**Wiki connections**: [[concept1]], [[concept2]]

---

## To Triage (Medium Priority)

| Paper | Authors | Score | Why |
|-------|---------|-------|-----|
| [Title] | Author1 et al. | [score] | [primary reason] |
| ... | ... | ... | ... |

[Show top 10 medium papers]

## Briefing Stats

- **Sources scanned**: arXiv, Semantic Scholar
- **Papers found**: [total]
- **High priority**: [count] (auto-ingested)
- **Medium priority**: [count] (to triage)
- **Low priority**: [count] (skipped)

## Wiki Impact

### New Connections Made
[List any new wikilinks created during auto-ingest]

### Open Questions Potentially Addressed
[List questions from wiki/questions/ that a new paper might address]

### Suggested Follow-ups
- [ ] Review triage queue ([count] papers)
- [ ] Check [[wiki/contradictions/]] for new flags
[Any other suggestions based on what was found]

---
*Generated by `/briefing` at [timestamp]*
```

---

## Step 9: Update Wiki Cross-References

For each ingested paper:
1. Find concept pages in `wiki/concepts/` that relate to the paper's topic
2. Add backlinks from concept pages to the new summary
3. If the paper potentially addresses an open question in `wiki/questions/`, add a note

---

## Step 10: Format Output for OpenClaw

```
📬 Morning Briefing — YYYY-MM-DD

🎯 HIGH PRIORITY ([count])
• [Paper 1 title (truncated to 60 chars)]
  [Primary reason for relevance]
• [Paper 2 title]
  [Primary reason]
[+N more if > 3]

📋 TO TRIAGE: [count] papers

📊 Wiki updated:
• [N] new connections
• [M] entities created

📖 Full briefing: Daily Notes/YYYY-MM-DD.md
```

If nothing was found:
```
✅ Briefing complete — no high-priority papers today
📋 [count] medium-priority papers in triage
📖 Daily Notes/YYYY-MM-DD.md
```

---

## Step 11: Update Log

Append to `wiki/_log.md`:

```markdown
## [YYYY-MM-DD HH:MM] briefing | Daily research scan

### Sources
- arXiv: [count] papers found
- Semantic Scholar: [count] papers found
- Citation tracking: [count] papers found

### Results
- Total found: [total]
- High priority: [count] (ingested)
- Medium priority: [count] (triage)
- Low priority: [count] (skipped)

### Ingested
[For each ingested paper:]
- [[wiki/summaries/YYYYMMDD-title]] — Score: [score]

### Wiki Updates
- Connections added: [count]
- Entities created: [count]
- Questions addressed: [count]
```
