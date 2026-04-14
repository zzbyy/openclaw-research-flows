# Workflows

Detailed description of every workflow, including triggers, data flow, and outputs.

---

## 1. /ingest — Single Source Processing

**Trigger**: `ingest [path]` via Telegram, or called internally by `/batch` and `/briefing`
**Timeout**: ~60 seconds per paper
**Wiki writes**: summaries/, entities/, graph.md, _index.md, _log.md, possibly contradictions/

```
Input: PDF / Markdown / URL
  │
  ├─ Step 1: Identify source type (PDF/MD/URL)
  ├─ Step 2: Extract content (Claude reads PDF natively)
  ├─ Step 3: Extract metadata (DOI, arXiv ID)
  ├─ Step 4: Generate summary → wiki/summaries/YYYYMMDD-title.md
  ├─ Step 5: Create/update entities → wiki/entities/
  ├─ Step 6: Update knowledge graph → wiki/graph.md
  ├─ Step 7: Check for contradictions → wiki/contradictions/ (if found)
  ├─ Step 8: Update index → wiki/_index.md
  ├─ Step 9: Update log → wiki/_log.md
  └─ Step 10: Report (✅ status + counts)
```

**Output example**:
```
✅ Ingested: Attention Is All You Need
📄 wiki/summaries/20260413-attention-is-all-you-need
👤 8 new entities
🔗 12 relationships added
```

---

## 2. /batch — Multi-Paper Processing

**Trigger**: `batch [N] papers` via Telegram, or cron nightly job
**Timeout**: ~10 minutes (N papers × ~60s each)
**Wiki writes**: paper-inventory.csv + everything /ingest writes × N

```
Input: folder path + count
  │
  ├─ Step 1: Load/create paper-inventory.csv
  ├─ Step 2: Select papers by priority (smart/recent/author)
  ├─ Step 3: For each paper:
  │    └─ Run full /ingest workflow
  │    └─ Update inventory row (processed=true or notes=error)
  ├─ Step 4: Save updated inventory
  ├─ Step 5: Generate batch report → wiki/_log.md
  └─ Step 6: Report (📦 summary + progress %)
```

**Output example**:
```
📦 Batch Complete: 5 papers processed
✅ Successful: 4
❌ Failed: 1 (corrupted PDF)
📊 Progress: 50/200 papers (25%)
```

---

## 3. /briefing — Daily Research Briefing

**Trigger**: `morning briefing` via cron (7:03 AM) or manual Telegram message
**Timeout**: ~10 minutes
**Wiki writes**: Daily Notes/, summaries/ (for auto-ingested), _log.md

```
Input: --days N (default 1)
  │
  ├─ Step 1: Load research context from CLAUDE.md
  ├─ Step 2: Load wiki context (recent papers, concepts, questions)
  ├─ Step 3: Search arXiv → scripts/search_arxiv.py
  ├─ Step 4: Search Semantic Scholar → scripts/search_semantic_scholar.py
  ├─ Step 5: Deduplicate results
  ├─ Step 6: Score relevance (Opus 4.6 judgment + scoring weights)
  │    ├─ High (≥40): auto-ingest
  │    ├─ Medium (20-39): triage
  │    └─ Low (<20): skip
  ├─ Step 7: Auto-ingest high-priority papers (max 5)
  │    ├─ Download PDF → scripts/download_paper.py
  │    └─ Run /ingest workflow
  ├─ Step 8: Generate Daily Note → Daily Notes/YYYY-MM-DD.md
  ├─ Step 9: Update wiki cross-references
  ├─ Step 10: Format Telegram output (<500 chars)
  └─ Step 11: Update log
```

**Output example**:
```
📬 Morning Briefing — 2026-04-13
🎯 HIGH PRIORITY (3)
• Flash Attention 3: Even Faster... — extends your flash-attention research
• Scaling Laws for... — tracked researcher: Kaplan
📋 TO TRIAGE: 12 papers
📖 Full: Daily Notes/2026-04-13.md
```

---

## 4. /monitor — Literature Monitoring

**Trigger**: `run monitoring` or cron (Saturday 6:03 AM for full, daily 5:57 AM for quick)
**Timeout**: ~15 minutes (full), ~3 minutes (quick)
**Wiki writes**: monitoring/state.md, monitoring/reports/, summaries/ (if auto-ingest), _log.md

### /monitor run (full cycle)

```
Input: --full or --quick
  │
  ├─ Step 1: Load config (wiki/monitoring/config.md)
  ├─ Step 2: Load state (wiki/monitoring/state.md)
  ├─ Step 3: Check tracked researchers → scripts/search_semantic_scholar.py
  ├─ Step 4: Check citation networks → scripts/search_semantic_scholar.py
  ├─ Step 5: Check emerging topics → scripts/search_arxiv.py
  ├─ Step 6: Process alerts:
  │    ├─ High → auto-ingest via /ingest
  │    └─ Medium → add to triage queue
  ├─ Step 7: Generate report → wiki/monitoring/reports/YYYY-MM-DD.md
  └─ Step 8: Update state, log, notify
```

### /monitor review [topic]

```
Input: topic name
  │
  ├─ Step 1: Gather all wiki content related to topic
  ├─ Step 2: Analyze: temporal, methodological, consensus, debates, gaps
  ├─ Step 3: Generate review → wiki/synthesis/reviews/[topic]-review.md
  └─ Step 4: Update index, log
```

### /monitor gaps

```
Input: (none)
  │
  ├─ Check 1: Thin coverage (concepts with <3 papers)
  ├─ Check 2: Stale info (papers >3 years, unconfirmed)
  ├─ Check 3: Unanswered questions
  ├─ Check 4: Missing connections (orphan concepts)
  ├─ Check 5: Thesis gaps (keywords with low coverage)
  └─ Generate → wiki/monitoring/gap-analysis.md
```

---

## 5. /lint — Wiki Maintenance

**Trigger**: `lint` or cron (Sunday 6:03 PM)
**Timeout**: ~10 minutes
**Wiki writes**: _index.md (fixes), graph.md (cleanup), _log.md, maintenance-queue.md

```
Input: --fix, --deep, --section, --decay-only
  │
  ├─ Check 1: Orphan pages (no inbound links)
  ├─ Check 2: Broken links (targets don't exist)
  ├─ Check 3: Missing index entries
  ├─ Check 4: Stale contradictions (>7 days pending)
  ├─ Check 5: Low-confidence claims (<0.5)
  ├─ Check 6: Missing entity pages (mentioned ≥3 times)
  ├─ Check 7: Concept gaps (referenced but no page)
  ├─ Check 8: Graph inconsistencies
  ├─ [--deep] Confidence decay (−0.05/month if unreinforced)
  ├─ Auto-fix if --fix enabled
  ├─ Generate report
  └─ Update log + maintenance-queue.md
```

---

## 6. Quick Commands (inline, no workflow file)

| Command | What it does | Reads | Writes |
|---------|-------------|-------|--------|
| `/query [Q]` | Search wiki, synthesize answer | summaries/, concepts/, entities/ | Optionally synthesis/ |
| `/synthesis [T]` | Cross-source synthesis | summaries/, concepts/ | synthesis/[topic].md, _index.md |
| `/stats` | Wiki health metrics | _index.md, _log.md, inventory.csv | Nothing |
| `/triage` | Show unreviewed papers | monitoring/triage-queue.md, Daily Notes/ | Nothing |
| `/questions` | List open questions | questions/ | Nothing |
| `/contradictions` | Show pending conflicts | contradictions/ | Nothing |
| `/recent [N]` | Show latest ingests | _log.md | Nothing |
