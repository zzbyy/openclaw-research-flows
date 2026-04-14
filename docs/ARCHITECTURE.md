# Architecture

How the Research Wiki system works end-to-end.

---

## System Overview

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  You         │     │  OpenClaw        │     │  Claude Code    │
│  (Telegram)  │────▶│  Gateway         │────▶│  (Opus 4.6)     │
│              │◀────│  + SKILL.md      │◀────│  + CLAUDE.md    │
└─────────────┘     └──────────────────┘     └────────┬────────┘
                           │                           │
                    ┌──────┴──────┐              ┌─────┴─────┐
                    │ Cron        │              │ Obsidian  │
                    │ Scheduler   │              │ Vault     │
                    └─────────────┘              └───────────┘
```

### Flow: Interactive Command (Telegram)

```
1. You send "briefing" via Telegram
2. OpenClaw gateway receives the message
3. OpenClaw agent (MiniMax) pattern-matches against SKILL.md
4. SKILL.md says: run dispatch-research.sh "/briefing"
5. dispatch-research.sh calls cc-entry.sh with vault directory
6. cc-entry.sh calls dispatch.sh → spawns Claude Code in background
7. Claude Code starts in vault directory, reads CLAUDE.md
8. CLAUDE.md routes /briefing → commands/briefing.md
9. Claude follows briefing workflow:
   a. Runs python3 scripts/search_arxiv.py
   b. Runs python3 scripts/search_semantic_scholar.py
   c. Scores papers, ingests top ones
   d. Creates Daily Notes/YYYY-MM-DD.md
   e. Updates wiki files
10. session-end.sh hook fires → sends summary to Telegram
11. You see the briefing summary in Telegram
```

### Flow: Scheduled Task (Cron)

```
1. OpenClaw cron fires at 7:03 AM: message "morning briefing"
2. OpenClaw agent receives cron message
3. Same flow as interactive (steps 3-11)
4. Results announced to Telegram if --announce is set
```

---

## Component Responsibilities

| Component | Role | Location |
|-----------|------|----------|
| **OpenClaw Gateway** | Message routing, scheduling, notifications | Runs as daemon on localhost |
| **research-wiki SKILL.md** | Pattern matching: user text → Claude Code command | `~/.openclaw/workspace/skills/research-wiki/` |
| **dispatch-research.sh** | Thin wrapper: adds vault directory, delegates to cc-bridge | `~/.openclaw/workspace/skills/research-wiki/scripts/` |
| **cc-bridge (cc-entry.sh → dispatch.sh)** | Task tracking, background spawning, PID management | `~/.agents/skills/cc/scripts/` or `~/.openclaw/workspace/skills/cc/scripts/` |
| **Claude Code hooks** | Session lifecycle notifications (start, progress, end) | `~/.claude/hooks/` |
| **CLAUDE.md** | Master instructions: command routing, wiki rules, research context | `vault/CLAUDE.md` |
| **Command workflows** | Step-by-step instructions for each slash command | `vault/commands/*.md` |
| **Python scripts** | External API access (arXiv, Semantic Scholar) | `vault/scripts/*.py` |
| **Obsidian vault** | Persistent knowledge base (wiki/, raw/, Daily Notes/) | `vault/` |

---

## Data Flow

### Ingest Pipeline

```
raw/inbox/paper.pdf
    │
    ▼
/ingest ──▶ Read PDF ──▶ Extract metadata ──▶ Generate summary
    │                                              │
    ├──▶ wiki/summaries/YYYYMMDD-title.md          │
    ├──▶ wiki/entities/author-name.md               │
    ├──▶ wiki/graph.md (append relationships)       │
    ├──▶ wiki/_index.md (add entry)                 │
    ├──▶ wiki/_log.md (append log)                  │
    └──▶ wiki/contradictions/topic.md (if conflict) │
```

### Briefing Pipeline

```
CLAUDE.md (research context)
    │
    ▼
/briefing ──▶ scripts/search_arxiv.py ──────────┐
          ──▶ scripts/search_semantic_scholar.py ─┤
                                                   ▼
                                        Deduplicate & Score
                                                   │
                        ┌──────────────────────────┤
                        ▼                          ▼
                  High priority              Medium priority
                  (auto-ingest)              (add to triage)
                        │
                        ▼
                  /ingest pipeline
                        │
                        ▼
              Daily Notes/YYYY-MM-DD.md
```

### Monitoring Pipeline

```
wiki/monitoring/config.md (what to track)
wiki/monitoring/state.md (cursors)
    │
    ▼
/monitor run ──▶ Check researchers (Semantic Scholar)
             ──▶ Check citations (Semantic Scholar)
             ──▶ Check topics (arXiv)
                        │
                        ▼
                  Process alerts
                  (high → auto-ingest, medium → triage)
                        │
                        ▼
              wiki/monitoring/reports/YYYY-MM-DD.md
              wiki/monitoring/state.md (updated cursors)
```

---

## File Ownership

| Directory | Written by | Read by |
|-----------|-----------|---------|
| `raw/` | User (manual downloads), `/briefing` (auto-download) | `/ingest`, `/batch` |
| `wiki/summaries/` | `/ingest` | `/briefing`, `/monitor`, `/query`, `/lint` |
| `wiki/entities/` | `/ingest` | `/query`, `/lint` |
| `wiki/concepts/` | `/ingest`, `/synthesis` | `/briefing`, `/monitor`, `/query` |
| `wiki/synthesis/` | `/synthesis`, `/monitor review` | `/query` |
| `wiki/contradictions/` | `/ingest` | `/lint`, `/contradictions` |
| `wiki/monitoring/` | `/monitor` | `/monitor`, `/briefing` |
| `wiki/questions/` | `/ingest`, user | `/briefing`, `/monitor gaps` |
| `wiki/_index.md` | `/ingest`, `/lint` | Everything |
| `wiki/_log.md` | All commands | `/stats`, `/recent` |
| `wiki/graph.md` | `/ingest` | `/query`, `/lint` |
| `Daily Notes/` | `/briefing` | User (Obsidian) |
| `CLAUDE.md` | User (manual config) | All Claude Code sessions |
| `commands/*.md` | Install (static) | Claude Code sessions |
| `scripts/*.py` | Install (static) | Claude Code via Bash |
