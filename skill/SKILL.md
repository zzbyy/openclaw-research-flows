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

This is an interactive 4-stage wizard. Each stage collects info that directly shapes
how the wiki finds and organizes research papers for the user. Explain WHY you're
asking each question — the user is a researcher, not a developer.

Ask questions one at a time. Wait for each answer. Acknowledge before moving on.

### Before starting

Find the vault path:
```bash
bash command:"DISPATCH=$(find ~/.openclaw -path '*/research-wiki/scripts/dispatch-research.sh' 2>/dev/null | head -1) && grep 'VAULT_DIR=' \"$DISPATCH\" | head -1 | cut -d'\"' -f2"
```
Store this as VAULT_DIR for all file operations below.

Check if this is a re-run:
```bash
bash command:"grep -c '\[YOUR_FIELD' $VAULT_DIR/CLAUDE.md"
```
If count = 0, tell user: "Looks like you've set this up before. No problem — I'll update your settings with the new answers."

### How to write to CLAUDE.md (works on first-run and re-run)

Always replace the **entire line** so it works regardless of current content:
```bash
bash command:"sed -i '' 's|^\*\*Field\*\*:.*|**Field**: NEW_VALUE|' $VAULT_DIR/CLAUDE.md"
```

For multi-line blocks (keywords), use python:
```bash
bash command:"python3 -c \"
import re
with open('$VAULT_DIR/CLAUDE.md') as f: text = f.read()
text = re.sub(r'(\*\*Primary keywords\*\*.*?\n)((?:- .*\n)*)', r'\g<1>- kw1\n- kw2\n- kw3\n', text)
with open('$VAULT_DIR/CLAUDE.md', 'w') as f: f.write(text)
\""
```

### How to write API keys

**NEVER write API keys to config.md or any file in the vault** — the user may sync
the vault to GitHub. Instead, write keys to environment variables:
```bash
bash command:"grep -q 'SEMANTIC_SCHOLAR_API_KEY' ~/.zshrc || echo 'export SEMANTIC_SCHOLAR_API_KEY=\"KEY\"' >> ~/.zshrc"
```
Tell the user: "I've added the key to your shell profile. Run `source ~/.zshrc` or open a new terminal for it to take effect."

---

### Stage 1: Research Profile

**Explain to the user:**
> "First, I need to understand your research so the wiki knows what papers matter to you.
> Your answers here are used to:
> - Score how relevant new papers are (daily briefings only surface what matters)
> - Connect new papers to existing knowledge in your wiki
> - Focus monitoring on your specific area"

**Questions (ask one at a time):**

1. "What is your research field? (e.g., Biomedical Engineering, Computational Biology, Machine Learning)"

2. "In one sentence, what is your primary research focus?"
   (This becomes the thesis — used to judge if a paper is worth auto-ingesting)

3. "List 3-5 primary keywords — the specific terms most central to your work. Separate with commas."
   (These get the highest weight when scoring paper relevance)

4. "Any broader/secondary keywords? These cast a wider net to catch adjacent work. (or 'skip')"

5. "Which databases should we scan for papers?"
   Present:
   - **PubMed** — biomedical and life sciences
   - **arXiv** — physics, CS, math, quantitative biology preprints. Categories help narrow results — e.g., `q-bio.BM` for biomolecular, `cs.LG` for machine learning. (ask which categories if they pick arXiv)
   - **Semantic Scholar** — cross-discipline, good for citation tracking

   User picks one or more.

6. If Semantic Scholar: "Do you have a Semantic Scholar API key? It's free and gives higher rate limits. (or 'skip' — it works without one)"
   If provided → write to `~/.zshrc` as env var (NOT to vault files).

**Write all answers** to CLAUDE.md and config.md using the line-replacement approach.
Enable/disable sources in `$VAULT_DIR/wiki/monitoring/config.md`:
```bash
bash command:"python3 -c \"
import re
with open('$VAULT_DIR/wiki/monitoring/config.md') as f: text = f.read()
text = re.sub(r'(pubmed:\n\s*enabled:) \w+', r'\g<1> true', text)  # or false
text = re.sub(r'(arxiv:\n\s*enabled:) \w+', r'\g<1> true', text)
text = re.sub(r'(semantic_scholar:\n\s*enabled:) \w+', r'\g<1> true', text)
with open('$VAULT_DIR/wiki/monitoring/config.md', 'w') as f: f.write(text)
\""
```

**Show summary:**
```
✅ Stage 1 Complete — Research Profile

Field: [field]
Focus: [thesis]
Keywords: [k1], [k2], [k3] + [secondary]
Sources: [PubMed, arXiv (q-bio.BM), Semantic Scholar]

This tells the wiki what to look for. Next: who and what to watch.
```

---

### Stage 2: Monitoring Watchlist

**Explain to the user:**
> "Now let's set up monitoring. This is how the wiki stays current automatically:
>
> - **Track researchers** — when someone you follow publishes a new paper, the wiki notices and can add it automatically
> - **Track papers** — when a key paper in your field gets cited by someone new, you'll know about it
> - **Track topics** — when a burst of papers appears on a topic you care about, the wiki flags it
>
> All of this feeds into your daily briefing and weekly monitoring reports."

**Questions:**

1. "Name 1-5 researchers whose new publications you want to track. For each, tell me their name. (or 'skip' to set up later with `/rw track researcher [name]`)"

   For each researcher, verify they exist on Semantic Scholar:
   ```bash
   bash command:"cd $VAULT_DIR && python3 scripts/search_semantic_scholar.py --author 'NAME' --max-results 1"
   ```
   Show the result to confirm it's the right person.

   Ask: "How should we handle new papers from [name]?
   - **daily** — include in your morning briefing
   - **weekly** — include in the weekly monitoring report"

2. "Any key papers whose new citations you want to track? Give me titles or IDs — arXiv ID, DOI, or PMID. (or 'skip')"

   For each paper, look up current citation count. Ask daily or weekly.

3. "Any emerging topics to watch? Give a topic name and 2-3 keywords. (or 'skip')"

On **re-run**, show existing watchlist first and ask "Replace or add to it?"

Write to `$VAULT_DIR/wiki/monitoring/config.md` tracked researchers/papers/topics tables
using python to replace the table body.

**Show summary:**
```
✅ Stage 2 Complete — Monitoring Watchlist

Researchers: [N] tracked
Papers: [N] citation seeds
Topics: [N] watched

These will be checked automatically on your schedule. Next: let's set that up.
```

---

### Stage 3: Schedule

**Explain to the user:**
> "Now let's decide when the wiki does its work automatically. Each job runs in the
> background and sends you results right here in this chat."

First, check for existing rw- cron jobs (re-run case):
```bash
bash command:"openclaw cron list 2>/dev/null | grep 'rw-' || echo 'none'"
```
If found, tell user: "You have existing scheduled jobs. I'll replace them with your new choices."
Delete old rw- jobs before creating new ones.

**Present the jobs:**
```
Here's what I can automate for you:

📬 Morning Briefing (recommended)
   Every morning, scans your configured databases for new papers,
   scores them against your keywords, and auto-adds the best ones
   to your wiki. You get a summary here in chat.
   Suggested: every day at 7:00 AM

📦 Background Processing
   Quietly works through PDFs you've dropped into the vault's inbox.
   No notification unless something goes wrong.
   Suggested: every day at 9:00 PM

📡 Weekly Monitoring
   Deep check of all your tracked researchers, citation networks,
   and topics. Generates a monitoring report in the wiki.
   Suggested: every Saturday at 6:00 AM

🔧 Weekly Maintenance
   Cleans up the wiki — fixes broken links, flags stale claims,
   updates confidence scores.
   Suggested: every Sunday at 6:00 PM

Which ones would you like? (I'd recommend starting with Morning Briefing + Background Processing)
```

For each selected job, ask: "What time? (or keep the suggested time)"

OpenClaw already knows the user's timezone — no need to ask. Register jobs:
```bash
bash command:"openclaw cron add --name 'rw-morning-briefing' --cron '3 7 * * *' --message '/rw briefing' --timeout-seconds 600"
bash command:"openclaw cron add --name 'rw-nightly-batch' --cron '7 21 * * *' --message '/rw batch 5' --timeout-seconds 600"
bash command:"openclaw cron add --name 'rw-weekly-monitor' --cron '3 6 * * 6' --message '/rw monitor' --timeout-seconds 900"
bash command:"openclaw cron add --name 'rw-weekly-maintenance' --cron '3 18 * * 0' --message '/rw lint deep' --timeout-seconds 600"
```

**Show summary:**
```
✅ Stage 3 Complete — Schedule

[N] automated jobs set up:
- Morning Briefing: daily at [time]
- Background Processing: daily at [time]
...

Results will be sent to you here in this chat.
```

---

### Stage 4: Done

```
🎉 Your Research Wiki is ready!

Here's what's set up:

📖 Wiki vault: [VAULT_DIR]
   This is where your knowledge base lives. You can open it in Obsidian too.

🔬 Research focus: [field] — [thesis]
   Papers are scored against your keywords: [k1], [k2], [k3]

📡 Monitoring: [N] researchers, [N] papers, [N] topics
   New publications and citations will be caught automatically.

⏰ Schedule: [N] automated jobs
   [list jobs and times]

📖 Commands you can use anytime:
   /rw briefing       — run a briefing now
   /rw ingest [path]  — add a paper to the wiki
   /rw query [topic]  — ask your wiki a question
   /rw monitor        — run monitoring now
   /rw stats          — check wiki health
   /rw triage         — review papers waiting for you
   /rw schedule       — change your automated schedule

Drop PDFs into [VAULT_DIR]/raw/inbox/ anytime — they'll be processed by
your background job, or send /rw process inbox to do it now.
```

Write a log entry:
```bash
bash command:"echo '## [DATE] setup | Configuration complete\n- Field: [field]\n- Sources: [list]\n- Monitoring: [N] researchers, [N] papers, [N] topics\n- Schedule: [N] jobs' >> $VAULT_DIR/wiki/_log.md"
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
