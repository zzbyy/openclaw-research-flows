# Heartbeat — Automated Research Workflow Schedule

OpenClaw triggers Claude Code sessions on this schedule.
All times in your local timezone.

---

## Daily Schedule

### 6:00 AM — Pre-Briefing Monitor Check
**Purpose**: Quick scan for urgent alerts before main briefing

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/monitor run --quick" \
       --auto-approve \
       --timeout 180
```

**Checks**:
- High-priority researchers only
- Citation alerts on tracked papers
- Urgent topic matches

**Output**:
- If urgent: Immediate Telegram alert
- Otherwise: Feeds into 7:00 AM briefing

---

### 7:00 AM — Morning Research Briefing
**Purpose**: Daily research update in Daily Notes

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/briefing" \
       --auto-approve \
       --timeout 600
```

**Actions**:
1. Scan arXiv, Semantic Scholar for new papers
2. Score against thesis + wiki knowledge
3. Auto-ingest high-priority papers (max 5)
4. Generate `Daily Notes/YYYY-MM-DD.md`
5. Update wiki connections

**Telegram notification**:
```
📬 Morning Briefing

🎯 HIGH PRIORITY: [count]
• [Paper 1 title]
• [Paper 2 title]

📋 TO TRIAGE: [count] papers

📖 Full: Daily Notes/[date].md
```

**If nothing found**:
```
✅ Briefing complete — no high-priority papers today
```

---

### 12:00 PM — Inbox Check (Optional)
**Purpose**: Process papers downloaded during morning

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/batch raw/inbox --all" \
       --auto-approve \
       --timeout 300
```

**Condition**: Only run if `raw/inbox/` has new files

**Silent unless**: Errors or >3 papers processed

---

### 7:00 PM — Triage Reminder
**Purpose**: Remind about unreviewed papers

**Check**: Count papers in triage queue

**If triage_count > 0**:
```
📋 [count] papers still in triage from today's briefing

Top 3:
• [Paper 1] — Score: [score]
• [Paper 2]
• [Paper 3]

Reply "triage" to see full list
```

**If triage_count == 0**: Silent

---

### 9:00 PM — Background Batch Processing
**Purpose**: Chip away at PDF library

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/batch --continue 5" \
       --auto-approve \
       --timeout 600
```

**Actions**:
1. Process 5 unprocessed papers from inventory
2. Prioritize by relevance score
3. Update `wiki/paper-inventory.csv`

**Notification**:
- If errors: Report failures
- Otherwise: Silent (logged in wiki/log.md)

**Progress milestone notifications** (weekly):
```
📊 Library Processing Progress

Processed: 350/2,147 (16.3%)
This week: +35 papers
ETA: ~51 weeks at current pace

Highlights:
• [Notable paper processed]
```

---

### 11:00 PM — Daily Log Summary
**Purpose**: Archive daily activity

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/stats --daily-summary" \
       --auto-approve \
       --timeout 120
```

**Creates**: Entry in `wiki/log.md` with daily totals

**Silent**: No notification (just logging)

---

## Weekly Schedule

### Saturday 6:00 AM — Full Monitoring Cycle
**Purpose**: Comprehensive literature monitoring

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/monitor run --full" \
       --auto-approve \
       --timeout 900
```

**Actions**:
1. Check ALL tracked researchers
2. Full citation network scan
3. All topic monitors
4. Generate `wiki/monitoring/reports/YYYY-MM-DD.md`

**Notification**:
```
📡 Weekly Monitoring Report

👤 Researchers: [new_papers] new papers
🔗 Citations: +[new_citations] to tracked papers
📚 Topics: [topic_papers] relevant papers

🔴 Urgent: [urgent_count] items
📄 Report: wiki/monitoring/reports/[date].md
```

---

### Saturday 8:00 AM — Gap Analysis
**Purpose**: Identify knowledge gaps

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/monitor gaps" \
       --auto-approve \
       --timeout 300
```

**Creates**: `wiki/monitoring/gap-analysis.md`

**Notification**:
```
🔍 Weekly Gap Analysis

🔴 Thesis-critical gaps: [count]
🟡 Thin coverage: [count] concepts
📋 Stale info: [count] papers

Top priority:
• [Gap 1 — suggestion]
• [Gap 2 — suggestion]
```

---

### Sunday 6:00 PM — Wiki Maintenance
**Purpose**: Health check and cleanup

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/lint --fix --deep" \
       --auto-approve \
       --timeout 600
```

**Actions**:
1. Find and fix orphans, broken links
2. Decay confidence scores
3. Archive low-confidence claims
4. Generate lint report

**Notification**:
```
🔧 Weekly Maintenance

✅ Auto-fixed: [count] issues
⚠️ Needs review: [count] items

Wiki health: [score]/100
• Orphan pages: [count]
• Low confidence: [count]
• Contradictions: [count] pending
```

---

### Sunday 7:00 PM — Weekly Research Summary
**Purpose**: Synthesize week's activity

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/synthesis --weekly" \
       --auto-approve \
       --timeout 600
```

**Creates**: `wiki/synthesis/weekly/YYYY-WXX.md`

**Notification**:
```
📊 Weekly Research Summary

Papers: +[ingested] ingested, [read] read
Entities: +[created] created
Connections: +[links] new links

Emerging themes:
• [Theme 1]
• [Theme 2]

Open questions: [count]
Next week focus: [suggestion]

📖 Full: wiki/synthesis/weekly/[week].md
```

---

## Monthly Schedule

### 1st at 6:00 AM — Monthly Literature Review Refresh
**Purpose**: Update main literature review

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/monitor review [PRIMARY_THESIS_TOPIC]" \
       --auto-approve \
       --timeout 1200
```

**Creates/Updates**: `wiki/synthesis/reviews/[topic]-review.md`

**Notification**:
```
📚 Monthly Literature Review Updated

Topic: [topic]
Sources: [count] papers (+[new] since last month)
New sections: [list]

📖 Review: wiki/synthesis/reviews/[topic]-review.md
```

---

### 1st at 9:00 AM — Confidence Decay Cycle
**Purpose**: Age out stale knowledge

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/lint --decay-only" \
       --auto-approve \
       --timeout 300
```

**Actions**:
1. Decay unreinforced claims by 0.05
2. Flag claims dropping below 0.5
3. Archive claims below 0.3

**Notification**:
```
📉 Monthly Confidence Update

Decayed: [count] claims
Now below 0.5: [count] (need verification)
Archived: [count]

Strongest claims: [top 3]
Review needed: wiki/monitoring/decay-report.md
```

---

### 15th at 10:00 AM — State of Knowledge Report
**Purpose**: Comprehensive wiki assessment

```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/stats --full-report" \
       --auto-approve \
       --timeout 600
```

**Creates**: `wiki/reports/YYYY-MM-state.md`

**Notification**:
```
📊 State of Knowledge — [Month]

📚 Library
• Total papers: [total]
• Processed: [processed] ([percent]%)
• This month: +[new]

🧠 Wiki
• Summaries: [count]
• Entities: [count]
• Concepts: [count]
• Avg confidence: [score]

🎯 Thesis Coverage
• [Topic 1]: [coverage]%
• [Topic 2]: [coverage]%

📋 Priorities
1. [Priority 1]
2. [Priority 2]

📖 Full: wiki/reports/[month]-state.md
```

---

## Event-Driven Triggers

### On New File in raw/inbox/
**Detection**: File watcher or periodic check

```bash
# Every 15 minutes during work hours (9 AM - 6 PM)
if [ "$(ls -A raw/inbox/)" ]; then
    claude --message "/batch raw/inbox --all"
fi
```

**Or** use filesystem watcher:
```bash
fswatch -o raw/inbox/ | xargs -n1 -I{} \
    claude --message "/batch raw/inbox --all"
```

---

### On New File in raw/clips/
**Detection**: Obsidian Web Clipper saves file

```bash
# Trigger when new .md file appears
fswatch -o raw/clips/*.md | xargs -n1 -I{} \
    claude --message "/ingest raw/clips/$(ls -t raw/clips/*.md | head -1)"
```

---

### On Explicit Command
**Via OpenClaw message parsing**

Patterns are defined in OpenClaw routing config.
Any matched pattern spawns corresponding Claude Code session.

---

## Notification Rules

### Always Notify
- 🔴 Urgent monitoring alerts
- ❌ Errors and failures
- 📊 Weekly/monthly summaries

### Notify If Content
- 📬 Morning briefing (if papers found)
- 📋 Triage reminders (if queue non-empty)
- 🔧 Maintenance (if issues need review)

### Silent
- ✅ Successful background processing
- 📝 Routine logging
- 🔄 Empty briefings (no papers)

### Notification Format
```
[Emoji] [Title]

[Key metrics — 2-3 lines max]

[Action items if any]

📖 [Link to full report]
```

---

## Failure Handling

### Session Timeout
```
⏱️ Session timed out: [command]
Partial results saved to wiki/log.md
Retry? Reply "retry [command]"
```

### API Rate Limit
```
⚠️ Rate limited: [service]
Will retry in [minutes] minutes
Or run manually: [command]
```

### File Error
```
❌ File error: [details]
Check vault permissions
Manual fix may be needed
```

### Retry Logic
- Auto-retry once after 60 seconds
- If second failure, notify and log
- Skip task, continue schedule
- Resume on next scheduled run

---

## Customization

### Adjust Times
Edit times to match your schedule:
- Early riser? Move briefing to 6:00 AM
- Night owl? Shift everything +4 hours
- Weekend focus? Move weekly tasks to Sunday

### Adjust Frequencies
- More aggressive: Increase batch count, reduce intervals
- Conservative: Decrease batch count, weekly briefings

### Adjust Notifications
- Verbose: Notify on all events
- Minimal: Only urgent + weekly summaries
- Silent: Log only, check wiki manually

---

## Schedule Summary

| Time | Daily | Weekly | Monthly |
|------|-------|--------|---------|
| 6:00 AM | Quick monitor | Full monitor (Sat) | Lit review (1st) |
| 7:00 AM | **Briefing** | | |
| 8:00 AM | | Gap analysis (Sat) | |
| 9:00 AM | | | Confidence decay (1st) |
| 10:00 AM | | | State report (15th) |
| 12:00 PM | Inbox check | | |
| 6:00 PM | | Maintenance (Sun) | |
| 7:00 PM | Triage reminder | Summary (Sun) | |
| 9:00 PM | Batch (5 papers) | | |
| 11:00 PM | Daily log | | |
