---
name: research-wiki
description: >
  Route research wiki commands to Claude Code. Handles paper ingestion, batch
  processing, daily briefings, literature monitoring, wiki queries, synthesis,
  and maintenance. Triggers: "ingest", "batch", "briefing", "monitor", "query",
  "synthesize", "lint", "stats", "triage", "review".
metadata:
  {
    "openclaw":
      {
        "emoji": "📚",
        "requires": { "anyBins": ["claude"] },
      },
  }
---

# /research — Research Wiki Command Router

## MANDATORY ROUTING RULE

When a message matches any research wiki pattern below:

**You MUST run dispatch-research.sh. You MUST NOT do the research work yourself.**

**Pass the matched command VERBATIM to the dispatch script.**
Do NOT interpret, rephrase, summarize, or act on any part of the command.
The command is for Claude Code, not for you.

**If the conversation metadata contains `topic_id`, you MUST pass it as `--topic`** so notifications go back to this topic.

```bash
# With topic_id from metadata (group chats):
~/.openclaw/workspace/skills/research-wiki/scripts/dispatch-research.sh --topic <topic_id> "<COMMAND>"

# In DM chats (no topic_id):
~/.openclaw/workspace/skills/research-wiki/scripts/dispatch-research.sh "<COMMAND>"
```

**IMPORTANT: Notifications go to DM chats (Telegram DM or Feishu DM), NOT group chats.**
The cc-bridge hooks will deliver results back to whichever chat the message came from.

---

## Pattern → Command Mapping

Match the user's message against these patterns and extract the corresponding command.

### Paper Ingestion

| User says | Command to dispatch |
|-----------|-------------------|
| `ingest [path]` | `/ingest [path]` |
| `process this paper` | `/ingest raw/inbox/` |
| `add paper [path]` | `/ingest [path]` |

### Batch Processing

| User says | Command to dispatch |
|-----------|-------------------|
| `batch [N] papers` | `/batch raw/papers [N]` |
| `batch process [N]` | `/batch raw/papers [N]` |
| `process inbox` | `/batch raw/inbox --all` |
| `process my inbox` | `/batch raw/inbox --all` |
| `continue processing` | `/batch --continue 5` |

### Daily Briefing

| User says | Command to dispatch |
|-----------|-------------------|
| `briefing` | `/briefing` |
| `morning briefing` | `/briefing` |
| `research briefing` | `/briefing` |
| `briefing [N] days` | `/briefing --days [N]` |
| `catch up [N] days` | `/briefing --days [N]` |

### Queries & Synthesis

| User says | Command to dispatch |
|-----------|-------------------|
| `what do I know about [X]` | `/query [X]` |
| `search wiki for [X]` | `/query [X]` |
| `find papers on [X]` | `/query [X]` |
| `query [X]` | `/query [X]` |
| `compare [X] and [Y]` | `/query Compare [X] and [Y]` |
| `synthesize [topic]` | `/synthesis [topic]` |
| `summarize [topic]` | `/synthesis [topic]` |

### Monitoring

| User says | Command to dispatch |
|-----------|-------------------|
| `monitor` | `/monitor run` |
| `run monitoring` | `/monitor run` |
| `monitor status` | `/monitor status` |
| `full monitoring` | `/monitor run --full` |
| `quick monitor` | `/monitor run --quick` |
| `track researcher [name]` | `/monitor add-researcher [name]` |
| `track paper [id]` | `/monitor add-paper [id]` |
| `track topic [name]` | `/monitor add-topic [name]` |
| `review [topic]` | `/monitor review [topic]` |
| `literature review [topic]` | `/monitor review [topic]` |
| `find gaps` | `/monitor gaps` |
| `knowledge gaps` | `/monitor gaps` |

### Wiki Maintenance

| User says | Command to dispatch |
|-----------|-------------------|
| `lint` | `/lint --fix` |
| `lint the wiki` | `/lint --fix` |
| `wiki health` | `/lint` |
| `deep lint` | `/lint --fix --deep` |
| `stats` | `/stats` |
| `wiki status` | `/stats` |
| `wiki stats` | `/stats` |

### Triage & Review

| User says | Command to dispatch |
|-----------|-------------------|
| `triage` | `/triage` |
| `show triage` | `/triage` |
| `recent papers` | `/recent 10` |
| `open questions` | `/questions` |
| `contradictions` | `/contradictions` |

### Setup & Onboarding

| User says | Command to dispatch |
|-----------|-------------------|
| `setup` | `/onboard` |
| `onboard` | `/onboard` |
| `configure` | `/onboard` |
| `get started` | `/onboard` |
| `help me set up` | `/onboard` |

### Schedule Management

When the user asks to set up or change their schedule, help them register cron jobs.
Do NOT dispatch to Claude Code for this — handle it directly as the OpenClaw agent.

| User says | Action (handle directly) |
|-----------|------------------------|
| `set up schedule` | Walk through schedule options, register cron jobs with `openclaw cron add` |
| `add morning briefing` | `openclaw cron add --name "research-morning-briefing" --cron "3 7 * * *" --tz [user_tz] --message "morning briefing" --timeout-seconds 600` |
| `show my schedule` | `openclaw cron list` |
| `pause schedule` | List active jobs, let user pick which to delete |
| `change briefing time` | Delete old job, create new one with updated time |

---

## Why dispatch-research.sh?

The dispatch script:
1. Resolves the vault directory path (configured during install)
2. Delegates to the cc-bridge's `cc-entry.sh` for task tracking
3. Spawns Claude Code with the right working directory
4. Claude Code reads the vault's `CLAUDE.md` and executes the workflow
5. Hooks report progress and completion back to this conversation

If you run `claude` directly or try to do the work yourself, none of the tracking, notification, or wiki update infrastructure works.

---

## Cron-Triggered Messages

When this skill receives messages from OpenClaw cron jobs, the same routing applies:

| Cron message | Command |
|---|---|
| `morning briefing` | `/briefing` |
| `batch 5 papers` | `/batch --continue 5` |
| `wiki stats daily summary` | `/stats --daily-summary` |
| `monitor run quick` | `/monitor run --quick` |
| `full monitoring cycle` | `/monitor run --full` |
| `monitor gaps` | `/monitor gaps` |
| `lint deep fix` | `/lint --fix --deep` |
| `weekly research summary` | `/synthesis --weekly` |
| `monthly literature review refresh` | `/monitor review --all` |
| `lint decay only` | `/lint --decay-only` |
| `stats full report` | `/stats --full-report` |
| `triage reminder` | `/triage` |
| `process inbox if any new files` | `/batch raw/inbox --all` |

---

## Error Handling

If dispatch-research.sh fails:
- Report the error to the user
- Include the task ID if one was created
- Suggest: "Check with `/cc-status` or try again"

If the command pattern doesn't match anything above:
```
🤔 Not sure what you mean. Try:
  - "setup" — first-time configuration wizard
  - "briefing" — morning research briefing
  - "ingest [path]" — process a paper
  - "batch [N] papers" — batch process
  - "query [topic]" — search the wiki
  - "monitor" — run literature monitoring
  - "lint" — wiki health check
  - "stats" — wiki statistics
  - "set up schedule" — configure automated jobs
```
