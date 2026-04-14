# /onboard — Interactive Setup Wizard

Guide a new user through all critical configurations step by step. This command is run once after installation — it walks through every required setting conversationally.

---

## Overview

The onboarding has 5 stages. Complete each one before moving to the next. After each stage, confirm with the user before proceeding.

1. **Research Profile** — Field, thesis, keywords
2. **Sources & APIs** — Which search sources to enable, API keys
3. **Monitoring Watchlist** — Researchers, papers, topics to track
4. **Notification Preferences** — How and when to be notified
5. **Schedule Setup** — Set up automated cron jobs via OpenClaw

---

## Stage 1: Research Profile

Ask the user these questions one at a time. Wait for each answer.

**1.1** "What is your research field? (e.g., Biomedical Engineering, Machine Learning, Economics)"
→ Write answer to CLAUDE.md `Field:` line

**1.2** "What is your primary research focus or thesis? Describe in one sentence."
→ Write to CLAUDE.md `Thesis:` line

**1.3** "What institution or organization are you with? (or 'independent')"
→ Write to CLAUDE.md `Institution:` line

**1.4** "Who is your advisor or research lead? (or 'none')"
→ Write to CLAUDE.md `Advisor:` line

**1.5** "List 3-5 primary keywords for your research — these are the terms that matter most for finding relevant papers. Separate with commas."
→ Write to CLAUDE.md `Primary keywords:` section (one per line with `- ` prefix)

**1.6** "Any secondary/broader keywords? These cast a wider net. (or 'skip')"
→ Write to CLAUDE.md `Secondary keywords:` section

**1.7** "What arXiv categories should we scan? (e.g., cs.LG, cs.CL, q-bio.BM — or 'skip' if you don't use arXiv)"
→ Write to CLAUDE.md `arXiv categories:` line

After writing, show a summary:
```
✅ Research Profile Configured

Field: [field]
Thesis: [thesis]
Primary keywords: [k1], [k2], [k3]
Secondary keywords: [k4], [k5]
arXiv categories: [categories]

Ready for Stage 2?
```

---

## Stage 2: Sources & APIs

**2.1** "Which paper sources should we scan? Choose all that apply:
- **PubMed** — biomedical and life sciences (free, recommended for bio/medical research)
- **arXiv** — physics, CS, math, biology preprints (free, no key needed)
- **Semantic Scholar** — cross-discipline citation data (free, optional API key for higher limits)"

→ Update `wiki/monitoring/config.md` API settings:
  - Set `pubmed.enabled: true/false`
  - Set `arxiv.enabled: true/false`
  - Set `semantic_scholar.enabled: true/false`

**2.2** If PubMed enabled: "PubMed requires an email address for API access (NCBI policy). What email should we use?"
→ Write to `wiki/monitoring/config.md` `pubmed.email:` field
→ Write to CLAUDE.md `PubMed email:` line

**2.3** If Semantic Scholar enabled: "Semantic Scholar works without a key (100 requests/5 min). Do you have an API key for higher limits? (or 'skip')"
→ If provided, note it for the user to set as env var: `export SEMANTIC_SCHOLAR_API_KEY="..."`

Show summary:
```
✅ Sources Configured

Enabled: [PubMed, arXiv, Semantic Scholar]
PubMed email: [email]

Ready for Stage 3?
```

---

## Stage 3: Monitoring Watchlist

**3.1** "Name 1-5 researchers you want to track. For each, tell me their name and why they matter to your work. (or 'skip' to add later)"

For each researcher provided:
- Search Semantic Scholar to verify: `python3 scripts/search_semantic_scholar.py --author "[name]" --max-results 1`
- Add row to `wiki/monitoring/config.md` Tracked Researchers table
- Ask: "Alert level for [name]? high (instant alert) / medium (daily briefing) / low (weekly)"

**3.2** "Any key papers you want to monitor for new citations? Give me titles or IDs (arXiv, DOI, PMID). (or 'skip')"

For each paper:
- Look up on Semantic Scholar or PubMed to get current citation count
- Add row to `wiki/monitoring/config.md` Tracked Papers table
- Ask: "Alert level for [title]?"

**3.3** "Any emerging topics you want to watch? Give me a topic name and 2-3 keywords for each. (or 'skip')"

For each topic:
- Add row to `wiki/monitoring/config.md` Tracked Topics table
- Default alert threshold: 5 papers/week

Show summary:
```
✅ Monitoring Watchlist Configured

Researchers: [N] tracked
Papers: [N] citation seeds
Topics: [N] watched

Ready for Stage 4?
```

---

## Stage 4: Notification Preferences

**4.1** "How do you want to receive notifications?
- **Telegram DM** — direct messages to your Telegram account
- **Feishu** — messages via Feishu/Lark
- **Both**"

→ Update `wiki/monitoring/config.md` notification preferences

**4.2** "What timezone are you in? (e.g., Asia/Shanghai, America/New_York, Europe/London)"
→ Save for cron schedule setup in Stage 5

**4.3** "Do you want quiet hours — a window where only urgent alerts come through? (e.g., 22:00-07:00, or 'no')"
→ Update notification preferences in config.md

Show summary:
```
✅ Notifications Configured

Channel: [Telegram DM / Feishu / Both]
Timezone: [tz]
Quiet hours: [window or 'none']

Ready for Stage 5?
```

---

## Stage 5: Schedule Setup

Explain to the user what automated jobs are available, then set them up.

**5.1** Present the schedule options:

```
I can set up these automated research jobs for you:

📬 Morning Briefing (recommended)
   Scans papers daily, auto-ingests the best ones.
   Suggested: every day at 7:00 AM

📦 Nightly Batch Processing
   Chips away at your PDF library in the background.
   Suggested: every day at 9:00 PM (silent)

📡 Weekly Full Monitoring
   Deep scan of all tracked researchers, citations, topics.
   Suggested: every Saturday at 6:00 AM

🔧 Weekly Maintenance
   Fixes broken links, decays old claims, cleans up wiki.
   Suggested: every Sunday at 6:00 PM

Which ones would you like? (recommended: start with Morning Briefing + Nightly Batch)
```

**5.2** For each selected job, ask:
- "What time for [job name]? (or accept the suggested time)"

**5.3** Set up the cron jobs by asking OpenClaw to register them. Output the commands for the user to send to OpenClaw:

For each job, tell the user:
```
Send this to OpenClaw to register the [job name]:

schedule add [job-name] --cron "[expression]" --tz "[timezone]" --message "[command]"
```

Or, if the session has access to run OpenClaw commands directly:
```bash
openclaw cron add --name "[job-name]" --cron "[expression]" --tz "[timezone]" --message "[command]" --timeout-seconds [timeout]
```

**Important**: Use DM delivery, not group chats. Do NOT use `--to` with a group ID.

---

## Completion

After all 5 stages:

```
🎉 Research Wiki Setup Complete!

Your vault is ready at: [vault path]

📋 What's configured:
- Research profile: [field] / [thesis]
- Sources: [list]
- Monitoring: [N] researchers, [N] papers, [N] topics
- Notifications: [channel] in [timezone]
- Schedule: [N] automated jobs

📖 Quick reference:
- "briefing" — get your daily research update
- "ingest [path]" — process a paper
- "query [topic]" — ask your wiki a question
- "monitor" — run a monitoring cycle
- "stats" — see wiki health
- "triage" — review pending papers

Your first briefing will run at [next scheduled time].
Drop PDFs into raw/inbox/ anytime — they'll be processed automatically.
```

Append to `wiki/_log.md`:
```markdown
## [YYYY-MM-DD HH:MM] onboard | Initial setup complete
- Field: [field]
- Sources: [list]
- Researchers tracked: [N]
- Papers tracked: [N]
- Topics tracked: [N]
- Schedule: [N] cron jobs
```
