# Heartbeat — Automated Schedule

Cron schedule for the Research Wiki. All jobs are registered via `openclaw cron add`.

---

## Quick Start: Starter Schedule (3 jobs)

Start with these 3 jobs. Expand to the full schedule after a week of stable operation.

```bash
# Replace <token> with your OpenClaw gateway auth token
# Replace <group> with your Telegram group ID
# Replace <tz> with your IANA timezone (e.g., Asia/Shanghai, America/New_York)

# 1. Morning Briefing (daily 7:03 AM)
openclaw cron add \
  --name "research-morning-briefing" \
  --cron "3 7 * * *" \
  --tz "<tz>" \
  --message "morning briefing" \
  --announce \
  --channel telegram \
  --to "<group>" \
  --timeout-seconds 600 \
  --token <token>

# 2. Nightly Batch (daily 9:07 PM) — silent
openclaw cron add \
  --name "research-nightly-batch" \
  --cron "7 21 * * *" \
  --tz "<tz>" \
  --message "batch 5 papers" \
  --timeout-seconds 600 \
  --token <token>

# 3. Daily Log (daily 11:02 PM) — silent
openclaw cron add \
  --name "research-daily-log" \
  --cron "2 23 * * *" \
  --tz "<tz>" \
  --message "wiki stats daily summary" \
  --timeout-seconds 120 \
  --token <token>
```

Verify with:
```bash
openclaw cron list --token <token>
```

Test manually:
```bash
openclaw cron run <job-id> --token <token>
```

---

## Full Daily Schedule

| Time | Job Name | Command | Announce | Timeout |
|------|----------|---------|----------|---------|
| 5:57 AM | pre-briefing-monitor | `monitor run quick` | No (unless urgent) | 180s |
| 7:03 AM | morning-briefing | `morning briefing` | Yes | 600s |
| 12:03 PM | noon-inbox | `process inbox if any new files` | No | 300s |
| 6:57 PM | triage-reminder | `triage reminder` | Yes (if queue non-empty) | 120s |
| 9:07 PM | nightly-batch | `batch 5 papers` | No | 600s |
| 11:02 PM | daily-log | `wiki stats daily summary` | No | 120s |

```bash
# Pre-Briefing Monitor (5:57 AM)
openclaw cron add \
  --name "research-pre-briefing-monitor" \
  --cron "57 5 * * *" \
  --tz "<tz>" \
  --message "monitor run quick" \
  --timeout-seconds 180 \
  --token <token>

# Noon Inbox Check (12:03 PM)
openclaw cron add \
  --name "research-noon-inbox" \
  --cron "3 12 * * *" \
  --tz "<tz>" \
  --message "process inbox if any new files" \
  --timeout-seconds 300 \
  --token <token>

# Triage Reminder (6:57 PM)
openclaw cron add \
  --name "research-triage-reminder" \
  --cron "57 18 * * *" \
  --tz "<tz>" \
  --message "triage reminder" \
  --announce \
  --channel telegram \
  --to "<group>" \
  --timeout-seconds 120 \
  --token <token>
```

---

## Weekly Schedule

| Day | Time | Job Name | Command | Announce |
|-----|------|----------|---------|----------|
| Saturday | 6:03 AM | weekly-monitor | `full monitoring cycle` | Yes |
| Saturday | 8:07 AM | gap-analysis | `monitor gaps` | Yes |
| Sunday | 6:03 PM | weekly-maintenance | `lint deep fix` | Yes |
| Sunday | 6:57 PM | weekly-summary | `weekly research summary` | Yes |

```bash
# Saturday: Full Monitoring (6:03 AM)
openclaw cron add \
  --name "research-weekly-monitor" \
  --cron "3 6 * * 6" \
  --tz "<tz>" \
  --message "full monitoring cycle" \
  --announce \
  --channel telegram \
  --to "<group>" \
  --timeout-seconds 900 \
  --token <token>

# Saturday: Gap Analysis (8:07 AM)
openclaw cron add \
  --name "research-gap-analysis" \
  --cron "7 8 * * 6" \
  --tz "<tz>" \
  --message "monitor gaps" \
  --announce \
  --channel telegram \
  --to "<group>" \
  --timeout-seconds 300 \
  --token <token>

# Sunday: Maintenance (6:03 PM)
openclaw cron add \
  --name "research-weekly-maintenance" \
  --cron "3 18 * * 0" \
  --tz "<tz>" \
  --message "lint deep fix" \
  --announce \
  --channel telegram \
  --to "<group>" \
  --timeout-seconds 600 \
  --token <token>

# Sunday: Weekly Summary (6:57 PM)
openclaw cron add \
  --name "research-weekly-summary" \
  --cron "57 18 * * 0" \
  --tz "<tz>" \
  --message "weekly research summary" \
  --announce \
  --channel telegram \
  --to "<group>" \
  --timeout-seconds 600 \
  --token <token>
```

---

## Monthly Schedule

| Day | Time | Job Name | Command | Announce |
|-----|------|----------|---------|----------|
| 1st | 6:03 AM | monthly-litreview | `monthly literature review refresh` | Yes |
| 1st | 9:07 AM | monthly-decay | `lint decay only` | Yes |
| 15th | 10:03 AM | bimonthly-report | `stats full report` | Yes |

```bash
# 1st: Literature Review Refresh (6:03 AM)
openclaw cron add \
  --name "research-monthly-litreview" \
  --cron "3 6 1 * *" \
  --tz "<tz>" \
  --message "monthly literature review refresh" \
  --announce \
  --channel telegram \
  --to "<group>" \
  --timeout-seconds 1200 \
  --token <token>

# 1st: Confidence Decay (9:07 AM)
openclaw cron add \
  --name "research-monthly-decay" \
  --cron "7 9 1 * *" \
  --tz "<tz>" \
  --message "lint decay only" \
  --announce \
  --channel telegram \
  --to "<group>" \
  --timeout-seconds 300 \
  --token <token>

# 15th: State of Knowledge Report (10:03 AM)
openclaw cron add \
  --name "research-bimonthly-report" \
  --cron "3 10 15 * *" \
  --tz "<tz>" \
  --message "stats full report" \
  --announce \
  --channel telegram \
  --to "<group>" \
  --timeout-seconds 600 \
  --token <token>
```

---

## Notification Rules

| Job Type | Notify? | Condition |
|----------|---------|-----------|
| Morning briefing | Always | Papers found or not |
| Urgent monitoring alerts | Always | High-priority researcher/citation |
| Weekly/monthly summaries | Always | — |
| Triage reminder | Conditional | Only if triage queue non-empty |
| Batch processing | Silent | Unless errors occur |
| Daily log | Silent | Always silent |
| Maintenance | Conditional | Only if issues need human review |
| Pre-briefing monitor | Conditional | Only if urgent alerts |

---

## Timing Notes

- Minutes are offset from round numbers (3, 7, 57, 2) to avoid gateway congestion
- Pre-briefing monitor at 5:57 AM feeds into 7:03 AM briefing
- No two jobs overlap in their expected time windows
- Triage reminder at 6:57 PM gives you time to review before nightly batch at 9:07 PM

---

## Managing Cron Jobs

```bash
# List all jobs
openclaw cron list --token <token>

# Run a job manually (test it)
openclaw cron run <job-id> --token <token>

# Delete a job
openclaw cron delete <job-id> --token <token>

# View run history
openclaw cron runs --token <token>
openclaw cron runs <job-id> --token <token>
```

---

## Schedule Summary Table

| Time | Mon–Fri | Saturday | Sunday | Monthly |
|------|---------|----------|--------|---------|
| ~6:00 | Quick monitor | **Full monitor** | | Lit review (1st) |
| ~7:00 | **Briefing** | | | |
| ~8:00 | | Gap analysis | | |
| ~9:00 | | | | Decay (1st) |
| ~10:00 | | | | Report (15th) |
| ~12:00 | Inbox check | | | |
| ~18:00 | | | **Maintenance** | |
| ~19:00 | Triage reminder | | Weekly summary | |
| ~21:00 | Batch (5 papers) | | | |
| ~23:00 | Daily log | | | |
