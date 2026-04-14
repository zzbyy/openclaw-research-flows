---
name: research-wiki
description: >
  Research Wiki — automated research assistant powered by Claude Code.
  Handles /rw commands: setup (onboarding), briefing, ingest, batch,
  monitor, query, lint, stats, triage, review, schedule.
  /rw setup runs an interactive onboarding wizard DIRECTLY in this agent
  (no dispatch to Claude Code). All other /rw commands dispatch to Claude
  Code via dispatch-research.sh.
metadata:
  {
    "openclaw":
      {
        "emoji": "📚",
        "requires": { "anyBins": ["claude"] },
      },
  }
---

# /rw — Research Wiki Command Router

All commands use the `/rw` prefix to avoid ambiguity with other skills.
Example: `/rw setup`, `/rw briefing`, `/rw ingest raw/inbox/paper.pdf`

---

## ROUTING OVERVIEW

There are two types of `/rw` commands:

1. **Agent-handled** — the OpenClaw agent runs these directly in the conversation:
   - `/rw setup` — interactive onboarding wizard
   - `/rw schedule` — cron job management

2. **Claude Code dispatched** — the agent calls dispatch-research.sh, which spawns Claude Code:
   - All other `/rw` commands (briefing, ingest, batch, monitor, etc.)

---

## AGENT-HANDLED: /rw setup — Onboarding Wizard

When the user sends `/rw setup`, `/research-wiki setup`, or `/rw onboard`:

**Do NOT dispatch to Claude Code.** Handle this entirely yourself, in the conversation.

This is an interactive 5-stage wizard. Ask questions one at a time, wait for each answer,
then write the answers to files in the vault using `exec bash` commands.

The vault path is configured in `dispatch-research.sh`. Read it with:
```bash
bash command:"grep 'VAULT_DIR=' ~/.openclaw/workspace/skills/research-wiki/scripts/dispatch-research.sh | head -1 | cut -d'\"' -f2"
```
Store this as VAULT_DIR for all file operations below.

### Stage 1: Research Profile

Ask these questions one at a time. After each answer, acknowledge it before asking the next.

1. "What is your research field? (e.g., Biomedical Engineering, Machine Learning, Economics)"
2. "What is your primary research focus or thesis? Describe in one sentence."
3. "What institution or organization are you with? (or 'independent')"
4. "Who is your advisor or research lead? (or 'none')"
5. "List 3-5 primary keywords — the terms that matter most for finding relevant papers. Separate with commas."
6. "Any secondary/broader keywords? These cast a wider net. (or 'skip')"
7. "What arXiv categories should we scan? (e.g., cs.LG, cs.CL, q-bio.BM — or 'skip' if you don't use arXiv)"

After collecting all answers, write them to CLAUDE.md using sed:
```bash
bash command:"sed -i '' 's|\[YOUR_FIELD.*\]|ACTUAL_FIELD|' $VAULT_DIR/CLAUDE.md"
bash command:"sed -i '' 's|\[YOUR_THESIS.*\]|ACTUAL_THESIS|' $VAULT_DIR/CLAUDE.md"
bash command:"sed -i '' 's|\[YOUR_INSTITUTION\]|ACTUAL_INSTITUTION|' $VAULT_DIR/CLAUDE.md"
bash command:"sed -i '' 's|\[ADVISOR_NAME\]|ACTUAL_ADVISOR|' $VAULT_DIR/CLAUDE.md"
```

For keywords, replace the placeholder lines:
```bash
bash command:"sed -i '' '/^\- \[keyword1\]/,/^\- \[keyword5\]/{
s/- \[keyword1\]/- actual_keyword1/
s/- \[keyword2\]/- actual_keyword2/
s/- \[keyword3\]/- actual_keyword3/
}' $VAULT_DIR/CLAUDE.md"
```

Show summary:
```
✅ Research Profile Configured

Field: [field]
Thesis: [thesis]
Primary keywords: [k1], [k2], [k3]
Secondary keywords: [k4], [k5]
arXiv categories: [categories]

Moving to Stage 2...
```

### Stage 2: Sources & APIs

Ask: "Which paper sources should we enable?"
Present options:
- **PubMed** — biomedical and life sciences (free)
- **arXiv** — physics, CS, math, biology preprints (free)
- **Semantic Scholar** — cross-discipline citation tracking (free)

User can pick one or more.

If PubMed: ask for email (required by NCBI API policy).
If Semantic Scholar: ask if they have an API key (optional, higher rate limits).

Write to `$VAULT_DIR/wiki/monitoring/config.md` — update the `apis:` YAML block:
```bash
bash command:"sed -i '' 's/pubmed:/pubmed:\n    enabled: true/' $VAULT_DIR/wiki/monitoring/config.md"
```

Show summary:
```
✅ Sources Configured

Enabled: [list]
PubMed email: [email if applicable]
```

### Stage 3: Monitoring Watchlist

Ask: "Name 1-5 researchers you want to track. For each, give their name and why they matter. (or 'skip')"

For each researcher, verify they exist:
```bash
bash command:"cd $VAULT_DIR && python3 scripts/search_semantic_scholar.py --author 'RESEARCHER_NAME' --max-results 1"
```

Ask alert level: high (instant alert) / medium (daily briefing) / low (weekly)

Append to the Tracked Researchers table in `$VAULT_DIR/wiki/monitoring/config.md`:
```bash
bash command:"sed -i '' '/^\| \[Researcher 1\]/i\\
| Actual Name | Institution | high | reason' $VAULT_DIR/wiki/monitoring/config.md"
```

Then ask: "Any key papers to monitor for citations? Give titles or IDs. (or 'skip')"
Then ask: "Any topics to watch? Give topic name + 2-3 keywords each. (or 'skip')"

Show summary:
```
✅ Monitoring Watchlist Configured

Researchers: [N] tracked
Papers: [N] citation seeds
Topics: [N] watched
```

### Stage 4: Notification Preferences

Ask: "What timezone are you in? (e.g., Asia/Shanghai, America/New_York, Europe/London)"
Ask: "Want quiet hours — only urgent alerts? (e.g., 22:00-07:00, or 'no')"

Write to `$VAULT_DIR/wiki/monitoring/config.md` notification block.

Show summary:
```
✅ Notifications Configured

Timezone: [tz]
Quiet hours: [window or 'none']
```

### Stage 5: Schedule Setup

Present available automated jobs:
```
I can set up these automated research jobs for you:

📬 Morning Briefing (recommended)
   Scans papers daily, auto-ingests the best ones.
   Suggested: every day at 7:00 AM

📦 Nightly Batch Processing
   Processes PDFs from your library in the background.
   Suggested: every day at 9:00 PM (silent)

📡 Weekly Full Monitoring
   Deep scan of all tracked researchers, citations, topics.
   Suggested: every Saturday at 6:00 AM

🔧 Weekly Maintenance
   Fixes broken links, decays old claims, cleans up wiki.
   Suggested: every Sunday at 6:00 PM

Which ones would you like? (recommended: start with Morning Briefing + Nightly Batch)
```

For each selected job, ask what time (or accept suggested).

Register each cron job using the timezone from Stage 4:
```bash
bash command:"openclaw cron add --name 'rw-morning-briefing' --cron '3 7 * * *' --tz 'USER_TZ' --message '/rw briefing' --timeout-seconds 600"
bash command:"openclaw cron add --name 'rw-nightly-batch' --cron '7 21 * * *' --tz 'USER_TZ' --message '/rw batch 5' --timeout-seconds 600"
bash command:"openclaw cron add --name 'rw-weekly-monitor' --cron '3 6 * * 6' --tz 'USER_TZ' --message '/rw monitor' --timeout-seconds 900"
bash command:"openclaw cron add --name 'rw-weekly-maintenance' --cron '3 18 * * 0' --tz 'USER_TZ' --message '/rw lint deep' --timeout-seconds 600"
```

### Completion

After all 5 stages:
```
🎉 Research Wiki Setup Complete!

📋 What's configured:
- Research profile: [field] / [thesis]
- Sources: [list]
- Monitoring: [N] researchers, [N] papers, [N] topics
- Timezone: [tz]
- Schedule: [N] automated jobs

📖 Quick reference:
- /rw briefing       — daily research update
- /rw ingest [path]  — process a paper
- /rw query [topic]  — ask your wiki a question
- /rw monitor        — run a monitoring cycle
- /rw stats          — wiki health
- /rw triage         — review pending papers

Your first briefing will run at [next scheduled time].
Drop PDFs into raw/inbox/ anytime — they'll be processed automatically.
```

Write a log entry:
```bash
bash command:"echo '## [DATE] onboard | Initial setup complete\n- Field: [field]\n- Sources: [list]\n- Researchers: [N]\n- Schedule: [N] jobs' >> $VAULT_DIR/wiki/_log.md"
```

---

## AGENT-HANDLED: /rw schedule — Cron Job Management

When the user sends `/rw schedule`, handle it directly (no Claude Code dispatch).

| User says | Action |
|-----------|--------|
| `/rw schedule` | Walk through schedule options, register cron jobs |
| `/rw schedule list` | Run: `bash command:"openclaw cron list"` |
| `/rw schedule pause` | List active jobs, let user pick which to delete |

---

## DISPATCHED TO CLAUDE CODE: All other /rw commands

For every `/rw` command NOT listed as agent-handled above, dispatch to Claude Code.

**CRITICAL: Do NOT put a `/` prefix on the dispatched prompt.**
Claude Code treats `/something` as a built-in skill invocation and will fail.
Send plain text like `briefing`, not `/briefing`.

```bash
# With topic_id from metadata (group chats):
~/.openclaw/workspace/skills/research-wiki/scripts/dispatch-research.sh --topic <topic_id> "<COMMAND>"

# In DM chats (no topic_id):
~/.openclaw/workspace/skills/research-wiki/scripts/dispatch-research.sh "<COMMAND>"
```

**IMPORTANT**: The dispatch-research.sh path above may differ per installation.
The skill is installed into the agent's workspace. Check the actual path with:
```bash
bash command:"find ~/.openclaw -path '*/research-wiki/scripts/dispatch-research.sh' 2>/dev/null | head -1"
```

### Pattern → Prompt Mapping

| User says | Prompt to dispatch |
|-----------|-------------------|
| `/rw briefing` | `briefing` |
| `/rw briefing 3 days` | `briefing --days 3` |
| `/rw catch up` | `briefing --days 3` |
| `/rw ingest [path]` | `ingest [path]` |
| `/rw ingest` | `ingest raw/inbox/` |
| `/rw batch [N]` | `batch raw/papers [N]` |
| `/rw process inbox` | `batch raw/inbox --all` |
| `/rw continue` | `batch --continue 5` |
| `/rw query [X]` | `query [X]` |
| `/rw compare [X] and [Y]` | `query Compare [X] and [Y]` |
| `/rw synthesize [topic]` | `synthesis [topic]` |
| `/rw monitor` | `monitor run` |
| `/rw monitor status` | `monitor status` |
| `/rw monitor quick` | `monitor run --quick` |
| `/rw track researcher [name]` | `monitor add-researcher [name]` |
| `/rw track paper [id]` | `monitor add-paper [id]` |
| `/rw track topic [name]` | `monitor add-topic [name]` |
| `/rw review [topic]` | `monitor review [topic]` |
| `/rw gaps` | `monitor gaps` |
| `/rw lint` | `lint --fix` |
| `/rw lint deep` | `lint --fix --deep` |
| `/rw stats` | `stats` |
| `/rw triage` | `triage` |
| `/rw recent` | `recent 10` |
| `/rw questions` | `questions` |
| `/rw contradictions` | `contradictions` |

---

## Cron-Triggered Messages

When this skill receives messages from OpenClaw cron jobs, the same dispatch routing applies:

| Cron message | Prompt to dispatch |
|---|---|
| `/rw briefing` | `briefing` |
| `/rw batch 5` | `batch --continue 5` |
| `/rw stats daily` | `stats --daily-summary` |
| `/rw monitor quick` | `monitor run --quick` |
| `/rw monitor` | `monitor run --full` |
| `/rw gaps` | `monitor gaps` |
| `/rw lint deep` | `lint --fix --deep` |
| `/rw synthesize weekly` | `synthesis --weekly` |
| `/rw review all` | `monitor review --all` |
| `/rw lint decay` | `lint --decay-only` |
| `/rw stats full` | `stats --full-report` |
| `/rw triage` | `triage` |
| `/rw process inbox` | `batch raw/inbox --all` |

---

## Error Handling

If dispatch-research.sh fails:
- Report the error to the user
- Include the task ID if one was created
- Suggest: "Check with `/cc-status` or try again"

If the command doesn't start with `/rw` or `/research-wiki`, ignore it — it's not for this skill.

If it starts with `/rw` but doesn't match any pattern:
```
📚 Research Wiki — available commands:

  /rw setup          — first-time configuration wizard
  /rw briefing       — morning research briefing
  /rw ingest [path]  — process a paper
  /rw batch [N]      — batch process papers
  /rw query [topic]  — search the wiki
  /rw monitor        — run literature monitoring
  /rw review [topic] — generate literature review
  /rw lint           — wiki health check
  /rw stats          — wiki statistics
  /rw triage         — papers awaiting review
  /rw schedule       — manage automated jobs
```
