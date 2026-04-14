# Research Wiki — Claude Code Instructions

You maintain a persistent, compounding knowledge base using the LLM Wiki pattern.
OpenClaw triggers your sessions; you do the heavy lifting with Opus 4.6.

---

## My Research Context

**Field**: [YOUR FIELD — e.g., Machine Learning / NLP]
**Thesis**: [YOUR THESIS — e.g., Efficient attention mechanisms for long-context transformers]
**Institution**: [YOUR INSTITUTION]
**Advisor**: [ADVISOR NAME]

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

**arXiv categories**: cs.LG, cs.CL, cs.AI, stat.ML

---

## Architecture

```
vault/
├── raw/                        # IMMUTABLE — never modify
│   ├── papers/                 # PDF library
│   ├── clips/                  # Web articles (Obsidian Clipper)
│   └── inbox/                  # New downloads
│
├── wiki/                       # YOUR DOMAIN — read/write freely
│   ├── summaries/              # Per-source notes
│   ├── entities/               # People, methods, tools
│   ├── concepts/               # Topics, theories
│   ├── synthesis/              # Cross-source insights
│   │   ├── reviews/            # Literature reviews
│   │   └── weekly/             # Weekly summaries
│   ├── contradictions/         # Flagged disagreements
│   ├── monitoring/             # Tracking config & reports
│   │   ├── config.md           # What to track
│   │   ├── state.md            # Cursors & state
│   │   └── reports/            # Monitoring reports
│   ├── index.md                # Page catalog
│   ├── log.md                  # Activity log
│   └── graph.md                # Knowledge graph
│
├── Daily Notes/                # Obsidian daily notes
├── commands/                   # Detailed workflows
├── scripts/                    # Python helpers
└── CLAUDE.md                   # This file
```

---

## Slash Commands

### Core Wiki Operations

| Command | Description | Workflow |
|---------|-------------|----------|
| `/ingest [path]` | Process single source | `commands/ingest.md` |
| `/batch [folder] [count]` | Process multiple papers | `commands/batch.md` |
| `/query [question]` | Search wiki, synthesize answer | Direct |
| `/synthesis [topic]` | Generate topic synthesis | Direct |
| `/lint` | Wiki health check | `commands/lint.md` |
| `/stats` | Wiki statistics | Direct |

### Daily Operations

| Command | Description | Workflow |
|---------|-------------|----------|
| `/briefing` | Morning research briefing | `commands/briefing.md` |
| `/briefing --days 3` | Catch-up briefing | `commands/briefing.md` |

### Monitoring & Reviews

| Command | Description | Workflow |
|---------|-------------|----------|
| `/monitor run` | Full monitoring cycle | `commands/monitor.md` |
| `/monitor status` | Show tracking status | `commands/monitor.md` |
| `/monitor add-researcher [name]` | Track new researcher | `commands/monitor.md` |
| `/monitor add-paper [id]` | Track paper citations | `commands/monitor.md` |
| `/monitor review [topic]` | Generate lit review | `commands/monitor.md` |
| `/monitor gaps` | Knowledge gap analysis | `commands/monitor.md` |

### Quick Commands (No Workflow File)

| Command | Action |
|---------|--------|
| `/triage` | Show papers awaiting review |
| `/questions` | List open research questions |
| `/contradictions` | Show unresolved contradictions |
| `/recent [n]` | Show n most recent ingests |

---

## Command: /query [question]

Answer research questions from wiki knowledge.

```
1. Search wiki/index.md for relevant pages
2. Read relevant summaries, concepts, entities
3. Synthesize answer with [[wikilinks]]
4. Include confidence levels
5. If substantial answer (>200 words):
   - Offer to save as wiki/synthesis/[topic].md
```

**Example**:
```
User: "What are the main approaches to efficient attention?"

Response:
Based on the wiki, there are three main approaches:

1. **Sparse attention** ([[wiki/concepts/sparse-attention]])
   - Papers: [[20260401-longformer]], [[20260315-bigbird]]
   - Key insight: attend only to subset of tokens

2. **Linear attention** ([[wiki/concepts/linear-attention]])
   - Papers: [[20260320-performer]], [[20260410-linear-transformers]]
   - Key insight: approximate softmax with kernel features

3. **Chunked/Flash attention** ([[wiki/concepts/flash-attention]])
   - Papers: [[20260405-flashattention-2]]
   - Key insight: memory-efficient via tiling

Confidence: 0.85 (based on 12 wiki sources)

Should I save this as a synthesis page?
```

---

## Command: /synthesis [topic]

Generate comprehensive synthesis on a topic.

```
1. Find all wiki pages tagged/related to [topic]
2. Read summaries, extract key claims
3. Identify consensus, debates, gaps
4. Generate wiki/synthesis/[topic].md
5. Update wiki/index.md
```

**Output structure**:
- Overview
- Key papers table
- Main findings
- Open debates
- Gaps identified
- Connection to my thesis

---

## Command: /stats

Report wiki health and progress.

```
📊 Wiki Statistics

## Content
- Summaries: 245
- Entities: 67 (32 people, 20 methods, 15 tools)
- Concepts: 30
- Synthesis pages: 12
- Open questions: 8
- Contradictions: 3 pending

## Processing
- PDFs in library: 2,147
- Processed: 312 (14.5%)
- In triage: 23

## Health
- Average confidence: 0.76
- Orphan pages: 5
- Broken links: 2
- Last lint: 2 days ago

## Activity (last 7 days)
- Papers ingested: 34
- Entities created: 12
- Questions answered: 8
```

---

## Command: /triage

Show papers awaiting human review.

```
Read wiki/monitoring/triage-queue.md
Display papers with:
- Title
- Source (briefing date or monitoring alert)
- Relevance score
- Quick actions: [Ingest] [Skip] [Later]
```

---

## Command: /questions

List open research questions.

```
Scan wiki/questions/
Group by:
- Thesis-critical
- General interest
- Methodological

Show:
- Question text
- When raised
- Potential answers (if any papers flagged)
```

---

## Command: /contradictions

Show unresolved contradictions.

```
Scan wiki/contradictions/
Filter: status = pending
Show:
- Topic
- Claim A vs Claim B
- Sources
- Age (days since flagged)
- Suggested resolution
```

---

## Confidence Rules

| Score | Meaning |
|-------|---------|
| 0.9+ | Multiple recent sources agree |
| 0.7-0.9 | Single authoritative source |
| 0.5-0.7 | Single source, not corroborated |
| <0.5 | Speculation or contradicted |

- **Decay**: −0.05/month without reinforcement
- **Reinforce**: +0.1 when new source confirms (cap 0.95)
- **Contradict**: −0.2 when source disagrees → create contradiction

---

## Session Behavior

When a Claude Code session starts:

1. **Read this CLAUDE.md** (automatic)
2. **Parse command** from OpenClaw message
3. **Load workflow** from `commands/[command].md` if exists
4. **Execute** with access to full vault
5. **Update wiki** (summaries, entities, index, log, graph)
6. **Report** in OpenClaw-friendly format
7. **Exit cleanly**

### Principles

- **Never modify raw/** — immutable sources
- **Always update log.md** — audit trail
- **Link everything** — [[wikilinks]] for connections
- **Include confidence** — every claim has a score
- **Flag contradictions** — never silently overwrite
- **Be thorough** — Opus 4.6 can handle complex workflows

---

## Output Formatting for OpenClaw

Structure outputs so OpenClaw can relay them nicely:

```
✅ Success indicator
📄 File references
👤 Entity counts
🔗 Relationship counts
⚠️ Warnings
❌ Errors
📊 Statistics

Keep summaries under 500 chars for Telegram.
Full details go in wiki/log.md or wiki/monitoring/reports/.
```

---

## Integration Points

### Obsidian
- Wiki files appear in Obsidian immediately
- Graph view shows connections
- Daily Notes receive briefing content
- Dataview queries can surface wiki data

### OpenClaw
- Routes messages to Claude Code sessions
- Handles Heartbeat scheduling
- Relays notifications to Telegram/Slack
- Parses command patterns

### External APIs
- **arXiv**: Paper search and download
- **Semantic Scholar**: Citation data, author search
- **PubMed**: Biomedical papers (if needed)

Rate limits are handled in individual command workflows.

---

## File Operations Reference

```python
# Read file
View("wiki/index.md")
View("raw/papers/attention.pdf")  # PDFs work

# Write new file
Write("wiki/summaries/20260413-paper.md", content)

# Edit existing file
Edit("wiki/index.md", 
     "## Summaries\n", 
     "## Summaries\n- [[20260413-paper]] — New paper\n")

# Run script
Bash("python scripts/search_arxiv.py 'efficient attention'")

# List directory
Bash("ls -la wiki/summaries/")

# Search content
Bash("grep -r 'attention' wiki/summaries/")
```

---

## Quick Reference

**Morning routine**: `/briefing`
**Process new paper**: `/ingest raw/inbox/paper.pdf`
**Batch process**: `/batch raw/papers/2026 10`
**Research question**: `/query What methods exist for X?`
**Generate review**: `/monitor review [topic]`
**Check health**: `/lint`
**Check progress**: `/stats`
