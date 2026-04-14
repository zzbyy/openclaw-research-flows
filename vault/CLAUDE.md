# Research Wiki — Claude Code Instructions

You maintain a persistent, compounding knowledge base using the LLM Wiki pattern.
OpenClaw triggers your sessions; you do the heavy lifting with Opus 4.6.

---

## My Research Context

**Field**: [YOUR_FIELD — e.g., Machine Learning / NLP / Data Engineering]
**Thesis**: [YOUR_THESIS — e.g., Efficient attention mechanisms for long-context transformers]
**Institution**: [YOUR_INSTITUTION]
**Advisor**: [ADVISOR_NAME]

**Primary keywords** (high priority):
- [keyword1]
- [keyword2]
- [keyword3]

**Secondary keywords**:
- [keyword4]
- [keyword5]

**Researchers to track**:
- [Name 1] at [Institution] — [why: e.g., "direct competitor on efficient attention"]
- [Name 2] at [Institution] — [why: e.g., "foundational work I build on"]

**Key papers to monitor citations**:
- [Paper Title 1] — [arXiv/DOI ID]
- [Paper Title 2] — [arXiv/DOI ID]

**arXiv categories**: [e.g., cs.LG, cs.CL, cs.AI, stat.ML]

**PubMed email** (required for PubMed API): [YOUR_EMAIL]

---

## Architecture

```
vault/
├── raw/                        # IMMUTABLE — never modify
│   ├── papers/                 # PDF library
│   ├── clips/                  # Web articles (Obsidian Clipper)
│   └── inbox/                  # New downloads awaiting processing
│
├── wiki/                       # YOUR DOMAIN — read/write freely
│   ├── summaries/              # Per-source notes (papers, articles)
│   ├── entities/               # People, methods, tools, datasets
│   ├── concepts/               # Topics, theories, frameworks
│   ├── synthesis/              # Cross-source insights
│   │   ├── reviews/            # Literature reviews
│   │   └── weekly/             # Weekly summaries
│   ├── contradictions/         # Flagged disagreements
│   ├── monitoring/             # Tracking config & reports
│   │   ├── config.md           # What to track
│   │   ├── state.md            # Cursors & state
│   │   └── reports/            # Monitoring reports
│   ├── questions/              # Open research questions
│   ├── _index.md               # Page catalog
│   ├── _log.md                 # Activity log (append-only)
│   ├── graph.md                # Knowledge graph (relationships)
│   └── paper-inventory.csv     # PDF processing tracker
│
├── Daily Notes/                # Obsidian daily notes (briefings land here)
├── commands/                   # Detailed workflow files
│   ├── ingest.md
│   ├── batch.md
│   ├── briefing.md
│   ├── monitor.md
│   └── lint.md
├── scripts/                    # Python helpers for API access
│   ├── search_arxiv.py
│   ├── search_semantic_scholar.py
│   └── download_paper.py
└── CLAUDE.md                   # This file
```

---

## Session Behavior

When a Claude Code session starts in this vault:

1. **Read this CLAUDE.md** (automatic)
2. **Parse the incoming command** from the OpenClaw message
3. **Load the workflow** from `commands/[command].md` if one exists
4. **Execute** the workflow steps with full vault access
5. **Update wiki** (summaries, entities, index, log, graph)
6. **Report** results in OpenClaw-friendly format (see Output Formatting below)
7. **Exit cleanly**

### Principles

- **Never modify `raw/`** — source files are immutable
- **Always update `wiki/_log.md`** — every action leaves an audit trail
- **Link everything** — use `[[wikilinks]]` to connect pages
- **Include confidence** — every claim gets a score
- **Flag contradictions** — never silently overwrite conflicting claims
- **Be thorough** — Opus 4.6 can handle complex, multi-step workflows

---

## Slash Commands

### Core Wiki Operations (workflow file required)

| Command | Description | Workflow |
|---------|-------------|----------|
| `/ingest [path]` | Process a single source into the wiki | `commands/ingest.md` |
| `/batch [folder] [count]` | Batch-process multiple papers | `commands/batch.md` |
| `/briefing` | Generate daily research briefing | `commands/briefing.md` |
| `/monitor [subcommand]` | Literature monitoring & reviews | `commands/monitor.md` |
| `/lint [--fix] [--deep]` | Wiki health check & maintenance | `commands/lint.md` |
| `/onboard` | Interactive first-time setup wizard | `commands/onboard.md` |

### Quick Commands (no workflow file — execute inline)

| Command | Action |
|---------|--------|
| `/query [question]` | Search wiki, synthesize answer (see below) |
| `/synthesis [topic]` | Generate topic synthesis (see below) |
| `/stats` | Report wiki health and progress (see below) |
| `/triage` | Show papers awaiting review |
| `/questions` | List open research questions |
| `/contradictions` | Show unresolved contradictions |
| `/recent [n]` | Show n most recent ingests |

---

## Quick Command: /query [question]

Answer research questions from wiki knowledge.

1. Search `wiki/_index.md` for relevant pages
2. Read relevant summaries, concepts, entities
3. Synthesize answer with `[[wikilinks]]` to sources
4. Include confidence levels for each claim
5. If substantial answer (>200 words), offer to save as `wiki/synthesis/[topic].md`

**Example output**:
```
Based on the wiki, there are three main approaches:

1. **Sparse attention** ([[wiki/concepts/sparse-attention]])
   - Papers: [[20260401-longformer]], [[20260315-bigbird]]
   - Key insight: attend only to subset of tokens

2. **Linear attention** ([[wiki/concepts/linear-attention]])
   - Papers: [[20260320-performer]], [[20260410-linear-transformers]]

Confidence: 0.85 (based on 12 wiki sources)
Save as synthesis page? [topic suggestion]
```

---

## Quick Command: /synthesis [topic]

Generate comprehensive synthesis on a topic.

1. Find all wiki pages tagged/related to `[topic]`
2. Read summaries, extract key claims
3. Identify consensus, debates, gaps
4. Generate `wiki/synthesis/[topic].md` with:
   - Overview
   - Key papers table
   - Main findings
   - Open debates
   - Gaps identified
   - Connection to my thesis
5. Update `wiki/_index.md`

---

## Quick Command: /stats

Report wiki health and progress.

```
📊 Wiki Statistics

## Content
- Summaries: [count]
- Entities: [count] ([people], [methods], [tools])
- Concepts: [count]
- Synthesis pages: [count]
- Open questions: [count]
- Contradictions: [count] pending

## Processing
- PDFs in library: [count from paper-inventory.csv]
- Processed: [count] ([percent]%)
- In triage: [count]

## Health
- Average confidence: [score]
- Orphan pages: [count]
- Broken links: [count]
- Last lint: [date]

## Activity (last 7 days)
- Papers ingested: [count]
- Entities created: [count]
- Questions answered: [count]
```

---

## Quick Command: /triage

Show papers awaiting human review.

1. Read `wiki/monitoring/triage-queue.md` (if exists)
2. Also scan `Daily Notes/` for medium-priority papers from recent briefings
3. Display with: title, source date, relevance score
4. Suggest quick actions: [Ingest] [Skip] [Later]

---

## Quick Command: /questions

List open research questions.

1. Scan `wiki/questions/` for all question files
2. Group by: thesis-critical, general interest, methodological
3. Show: question text, when raised, potential answers (if any papers flagged)

---

## Quick Command: /contradictions

Show unresolved contradictions.

1. Scan `wiki/contradictions/` where status = pending
2. Show: topic, Claim A vs Claim B, sources, age (days), suggested resolution

---

## Quick Command: /recent [n]

Show the `n` most recent ingests (default 10).

1. Read `wiki/_log.md`, filter for `ingest` entries
2. Show: date, title, summary path, entity count

---

## Confidence Rules

| Score | Meaning |
|-------|---------|
| 0.9+ | Multiple recent sources agree |
| 0.7–0.9 | Single authoritative source |
| 0.5–0.7 | Single source, not corroborated |
| <0.5 | Speculation or contradicted |

- **Decay**: −0.05/month without reinforcement
- **Reinforce**: +0.1 when new source confirms (cap 0.95)
- **Contradict**: −0.2 when source disagrees → create contradiction page

---

## Wiki File Schemas

### Summary (wiki/summaries/YYYYMMDD-kebab-title.md)

```yaml
---
title: "[Title]"
authors: [Author1, Author2]
year: YYYY
type: paper | article | blog
source: "[[raw/papers/filename.pdf]]"
doi: "[if found]"
arxiv: "[if found]"
venue: "[conference/journal if paper]"
confidence: 0.8
created: YYYY-MM-DD
updated: YYYY-MM-DD
status: processed
tags: [summary, primary-topic]
---
```

### Entity (wiki/entities/entity-name.md)

```yaml
---
title: "[Display Name]"
type: person | method | tool | dataset
aliases: [alternate names]
confidence: 0.8
created: YYYY-MM-DD
tags: [entity, type]
---
```

### Concept (wiki/concepts/concept-name.md)

```yaml
---
title: "[Concept Name]"
type: concept
confidence: 0.8
created: YYYY-MM-DD
related: ["[[Other Concept]]"]
tags: [concept, domain]
---
```

### Contradiction (wiki/contradictions/topic-YYYYMMDD.md)

```yaml
---
title: "[Topic]"
type: contradiction
status: pending | resolved
created: YYYY-MM-DD
tags: [contradiction]
---
```

---

## Output Formatting for OpenClaw

Structure outputs so OpenClaw can relay them to Telegram:

```
✅ Success indicator
📄 File references
👤 Entity counts
🔗 Relationship counts
⚠️ Warnings
❌ Errors
📊 Statistics
📬 Briefing header
🎯 High priority items
📋 Triage items
🔍 Search/lint results
🔧 Maintenance actions
```

**Keep Telegram summaries under 500 characters.** Full details go in wiki files.

**Standard report format**:
```
[emoji] [Action]: [Title/Summary]
[emoji] [Key metric 1]
[emoji] [Key metric 2]
[if errors] ⚠️ [Error summary]
📖 Full details: [wiki file path]
```

---

## Integration Points

### Obsidian
- Wiki files appear in Obsidian immediately (shared filesystem)
- Graph view shows connections via `[[wikilinks]]`
- Daily Notes receive briefing content
- Dataview queries can surface wiki data

### OpenClaw
- Routes messages to Claude Code sessions via cc-bridge
- Handles Heartbeat scheduling (cron jobs)
- Relays notifications to Telegram/Slack
- Parses command patterns via research-wiki skill

### External APIs (called via Python scripts)
- **arXiv**: Paper search and PDF download (`scripts/search_arxiv.py`)
- **Semantic Scholar**: Citation data, author search (`scripts/search_semantic_scholar.py`)
- **PubMed**: Biomedical/life science papers (`scripts/search_pubmed.py`) — enable in `wiki/monitoring/config.md`

Rate limits are handled within the Python scripts. Claude Code calls them via `Bash("python3 scripts/search_arxiv.py --keywords ...")`.
