# Configuration Guide

How to configure the Research Wiki for your domain, research context, and preferences.

---

## 1. Research Context (CLAUDE.md)

The most important configuration is the "My Research Context" section in `vault/CLAUDE.md`. This tells Claude Code what your research is about, which drives relevance scoring and monitoring.

### Fields to fill in

Open `CLAUDE.md` in your vault and replace all `[PLACEHOLDER]` values:

```yaml
Field: Machine Learning / NLP          # Your research field
Thesis: Efficient attention mechanisms  # Your thesis or primary focus
Institution: Stanford University        # Your institution
Advisor: Dr. Smith                      # Your advisor

Primary keywords:                       # High-priority search terms (3-5)
- flash attention
- efficient transformers
- linear attention

Secondary keywords:                     # Broader related terms (2-5)
- long context
- memory efficient

Researchers to track:                   # People whose work you follow
- Tri Dao at Princeton — flash attention author
- Ashish Vaswani at Google — transformer inventor

Key papers to monitor citations:        # Papers you want citation alerts for
- FlashAttention — 2205.14135
- Attention Is All You Need — 1706.03762

arXiv categories: cs.LG, cs.CL, cs.AI  # Which arXiv categories to scan
```

### Tips

- **Primary keywords** get 15 points in relevance scoring. Choose terms specific to your niche.
- **Secondary keywords** get 8 points. Use broader terms that might surface relevant adjacent work.
- **Tracked researchers**: Papers by these authors automatically get 25 bonus points.
- **arXiv categories**: More categories = more papers found, but also more noise.
- You can update these any time. Changes take effect on the next session.

---

## 2. Monitoring Configuration (wiki/monitoring/config.md)

This file controls what the `/monitor` command tracks. It lives inside the vault at `wiki/monitoring/config.md`.

### Tracked Researchers Table

```markdown
| Name | Institution | Alert Level | Notes |
|------|-------------|-------------|-------|
| Tri Dao | Princeton | high | Flash attention author |
| Dan Fu | Stanford | medium | Related efficient attention work |
```

**Alert levels**:
- `high` → Immediate notification + auto-ingest any new paper
- `medium` → Include in daily briefing
- `low` → Weekly summary only

### Tracked Papers Table

```markdown
| Paper | ID | Why Important | Alert Level |
|-------|-----|---------------|-------------|
| FlashAttention | 2205.14135 | Foundation of my work | high |
| Attention Is All You Need | 1706.03762 | Seminal paper | medium |
```

**ID formats**: arXiv ID (`2205.14135`), DOI (`10.1234/...`), or Semantic Scholar paperId.

### Tracked Topics Table

```markdown
| Topic | Keywords | Alert Threshold | Alert Level |
|-------|----------|-----------------|-------------|
| Efficient Attention | flash attention, linear attention | 3 papers/week | high |
| State Space Models | mamba, S4, state space | 5 papers/week | medium |
```

**Alert threshold**: How many papers per week before generating a "topic surge" alert.

### Scoring Weights

The `scoring:` YAML block in config.md lets you tune how papers are ranked:

```yaml
scoring:
  primary_keyword_match: 15     # Points for matching a primary keyword
  secondary_keyword_match: 8    # Points for matching a secondary keyword
  tracked_researcher_paper: 25  # Points when author is tracked
  wiki_concept_match: 12        # Points when paper relates to wiki concept
  answers_open_question: 20     # Points when paper might answer a question
  cites_tracked_paper: 18       # Points when paper cites a tracked paper
  published_today: 10           # Recency bonus
  published_this_week: 5
  high_citation_velocity: 5
  major_venue: 8

thresholds:
  high_priority: 40             # Score >= this → auto-ingest
  medium_priority: 20           # Score >= this → triage queue
```

Adjust these based on your experience. If too many papers are auto-ingested, raise `high_priority`. If you're missing relevant papers, lower `medium_priority`.

---

## 3. API Keys

### Semantic Scholar (optional but recommended)

Without a key: 100 requests per 5 minutes.
With a key: 10,000 requests per day.

Get a free key at: https://www.semanticscholar.org/product/api

Set it as an environment variable:
```bash
export SEMANTIC_SCHOLAR_API_KEY="your-key-here"
```

Or add to the vault's `.env` file if your setup supports it.

### arXiv

No API key needed. The arXiv API is free and unauthenticated. Rate limit: 1 request per 3 seconds (handled by the script).

### PubMed (optional)

If you work in biomedical research and want PubMed scanning:
1. Set `pubmed.enabled: true` in config.md
2. Provide your email (required by NCBI): `pubmed.email: "you@example.com"`
3. Install biopython: `pip3 install biopython`

---

## 4. Vault Directory Path

The dispatch script (`skill/scripts/dispatch-research.sh`) needs to know where your vault is. This is set during installation:

```bash
# In dispatch-research.sh:
VAULT_DIR="/Users/you/vault"  # Set by install.sh
```

If you move the vault, update this path. Or set the `VAULT_DIR` environment variable:
```bash
export VAULT_DIR="/new/path/to/vault"
```

---

## 5. Notification Preferences

In `wiki/monitoring/config.md`, the `notifications:` block controls what you receive:

```yaml
notifications:
  telegram: true
  slack: false

  urgent_alerts: always          # Always notify for high-priority
  daily_briefing: always         # Always send briefing summary
  weekly_summary: always         # Always send weekly digest
  batch_progress: milestones_only  # Only notify on progress milestones
  maintenance: issues_only       # Only if human action needed

  quiet_start: "22:00"          # No notifications after 10 PM
  quiet_end: "07:00"            # Until 7 AM
  quiet_exceptions:
    - urgent_alerts             # Urgent alerts bypass quiet hours
```

---

## 6. Obsidian Integration

The vault is a standard Obsidian vault. For best results:

### Recommended Obsidian plugins
- **Dataview**: Query wiki data with inline SQL-like queries
- **Graph View**: Visualize connections between wiki pages
- **Calendar**: See daily notes on a calendar
- **Backlinks**: Navigate the knowledge graph

### Dataview example queries

Add to your Obsidian dashboard:

```dataview
TABLE confidence, year, venue
FROM "wiki/summaries"
WHERE created = date(today)
SORT confidence DESC
```

```dataview
TABLE type, confidence
FROM "wiki/entities"
SORT file.name ASC
```

### Daily Notes

Ensure your Obsidian Daily Notes settings point to the `Daily Notes/` folder in the vault. The format should be `YYYY-MM-DD.md`.

---

## 7. Cron Schedule

See [HEARTBEAT.md](./HEARTBEAT.md) for the full schedule and registration commands.

**To customize timing**: Adjust the cron expressions in the `openclaw cron add` commands. All times use the `--tz` timezone flag.

**To customize frequency**: Start with the 3-job starter schedule, then expand as needed.

---

## Configuration Checklist

- [ ] Fill in CLAUDE.md research context (field, thesis, keywords, researchers, papers, categories)
- [ ] Configure monitoring tables in wiki/monitoring/config.md
- [ ] Set vault directory in dispatch-research.sh (or run install.sh)
- [ ] Install Python dependencies: `pip3 install -r scripts/requirements.txt`
- [ ] (Optional) Set SEMANTIC_SCHOLAR_API_KEY environment variable
- [ ] Register at least the starter cron schedule (see HEARTBEAT.md)
- [ ] Test manually: send "briefing" via Telegram
- [ ] Verify: check Daily Notes/ for the generated briefing
