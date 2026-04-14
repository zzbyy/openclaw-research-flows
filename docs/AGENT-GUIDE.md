# Agent Guide

How Claude Code agent sessions work in the Research Wiki system.

---

## Session Lifecycle

Every Claude Code session in the vault follows this sequence:

```
1. Session starts (spawned by cc-bridge dispatch.sh)
   └─ session-start.sh hook fires → Telegram: "🚀 Task started"

2. Claude Code auto-reads CLAUDE.md
   └─ Loads research context, command routing, wiki rules

3. Claude parses the incoming command
   └─ e.g., "/briefing" or "/ingest raw/inbox/paper.pdf"

4. If a workflow file exists, Claude reads it
   └─ e.g., commands/briefing.md

5. Claude executes the workflow step by step
   └─ post-tool-use.sh hook fires on each tool call
   └─ Tracks files created, commands run

6. Claude updates wiki files
   └─ summaries, entities, index, log, graph

7. Claude outputs the final report
   └─ Formatted for OpenClaw relay (emoji + metrics)

8. Session ends
   └─ session-end.sh hook fires → Telegram: summary + duration
   └─ Task moved to cc-bridge/completed/
```

---

## How Claude Uses Command Files

The `commands/` directory contains detailed workflow files. Claude Code doesn't execute them as scripts — it reads them as instructions and follows them step by step.

### Example: /briefing

1. Claude sees the message contains `/briefing`
2. Claude reads `commands/briefing.md`
3. The file says "Step 3: Run `python3 scripts/search_arxiv.py`..."
4. Claude uses the Bash tool: `python3 scripts/search_arxiv.py --keywords "..." --days 1`
5. Claude parses the JSON output
6. The file says "Step 6: Score relevance using wiki context..."
7. Claude reads wiki files, then uses its own judgment to score papers
8. The file says "Step 7: Auto-ingest high-priority papers..."
9. Claude reads `commands/ingest.md` and runs that workflow for each paper
10. And so on through all steps

### Key principle

Command files are **instructions for an intelligent agent**, not code to be executed. Claude can:
- Make judgment calls (e.g., relevance scoring)
- Handle edge cases not explicitly covered
- Skip steps that don't apply (e.g., no contradictions found)
- Adapt to unexpected situations (e.g., API timeout, empty results)

---

## How Python Scripts Are Called

Python scripts are only used for external API access — things Claude Code can't do natively:

| Script | Purpose | Called by |
|--------|---------|----------|
| `search_arxiv.py` | Search arXiv API | `/briefing`, `/monitor` |
| `search_semantic_scholar.py` | Search Semantic Scholar API | `/briefing`, `/monitor` |
| `download_paper.py` | Download PDFs from URLs | `/briefing`, `/ingest` (for URLs) |

Claude calls them via the Bash tool:
```bash
python3 scripts/search_arxiv.py --keywords "attention,transformer" --categories "cs.LG" --days 1
```

Scripts output JSON to stdout. Claude parses the JSON and continues the workflow.

### What Claude does natively (no scripts needed)

- **Read PDFs**: Claude can read PDF files directly with the Read tool
- **Generate markdown**: Claude writes wiki articles, summaries, frontmatter
- **Search files**: Claude uses Grep and Glob to search the wiki
- **Edit files**: Claude uses Edit to update index, add backlinks
- **Score relevance**: Opus 4.6 can assess paper relevance better than keyword matching
- **Detect contradictions**: Claude reads existing claims and compares
- **Parse frontmatter**: Claude reads YAML frontmatter inline

---

## Wiki File Structure

### Frontmatter Schema

Every wiki file uses YAML frontmatter:

```yaml
---
title: "Display Title"
type: paper | article | person | method | tool | dataset | concept | contradiction
confidence: 0.8          # 0.0-1.0, see Confidence Rules in CLAUDE.md
created: 2026-04-13
updated: 2026-04-13
status: processed | stub | needs-review | pending | resolved
tags: [category1, category2]
# Type-specific fields:
authors: [Author1]       # summaries only
year: 2026               # summaries only
source: "[[raw/...]]"    # summaries only
doi: "10.1234/..."       # summaries only
arxiv: "2301.12345"      # summaries only
aliases: [alt-name]      # entities only
related: ["[[Other]]"]   # concepts only
---
```

### Wikilinks

Use `[[double-bracket]]` links everywhere:
- `[[wiki/summaries/20260413-title]]` — link to summary
- `[[Author Name]]` — link to entity
- `[[Concept Name]]` — link to concept
- `[[cites]]`, `[[extends]]`, `[[uses]]` — relationship types in graph.md

### Knowledge Graph (graph.md)

Append-only file of relationships:
```markdown
## [2026-04-13] Relationships from [[20260413-title]]
- [[20260413-title]] authored_by [[Author Name]] | confidence: 1.0
- [[20260413-title]] uses [[Method Name]] | confidence: 0.85
```

### Activity Log (_log.md)

Append-only audit trail:
```markdown
## [2026-04-13 07:03] briefing | Daily research scan
- arXiv: 45 papers
- Ingested: 3 papers
- Triage: 12 papers
```

---

## Troubleshooting

### Common Issues

**Claude Code session times out**
- Default timeout is 10 minutes. For large batches, increase timeout in the cron job.
- Check `~/.openclaw/cc-bridge/logs/` for the task log.

**Python script fails with "module not found"**
- Run `pip3 install -r scripts/requirements.txt` in the vault directory.
- The vault's `.claude/settings.local.json` should allow pip installs.

**arXiv returns empty results**
- arXiv API has a 3-second rate limit. The script handles this.
- Check that your keywords and categories are correct in CLAUDE.md.
- Try `python3 scripts/search_arxiv.py --keywords "test" --days 7 --max-results 5` manually.

**Semantic Scholar rate limited**
- Without an API key: 100 requests per 5 minutes.
- Set `SEMANTIC_SCHOLAR_API_KEY` environment variable for higher limits.
- The script has built-in retry logic.

**PDF can't be read**
- Scanned PDFs (image-only) can't be extracted. Claude will create a stub summary.
- Password-protected PDFs will fail. Remove protection first.

**Notifications not appearing in Telegram**
- Check that cc-bridge hooks are installed: `ls ~/.claude/hooks/`
- Check hook logs: `cat ~/.openclaw/cc-bridge/logs/hooks.log`
- Verify Telegram group ID in OpenClaw config.

**Wiki files have merge conflicts**
- If two sessions run simultaneously and both edit `_index.md`, the second may fail.
- The Heartbeat schedule avoids overlapping sessions by design.
- If it happens: resolve manually, re-run `/lint --fix`.

### Debugging a Session

1. Check task status: send `/cc-status` via Telegram
2. Read task log: `cat ~/.openclaw/cc-bridge/logs/task-[ID].log`
3. Check events: `ls ~/.openclaw/cc-bridge/events/`
4. Test a script manually: `cd [vault] && python3 scripts/search_arxiv.py --keywords "test" --days 1`
5. Run a command manually: `claude --directory [vault] -p "/stats"`
