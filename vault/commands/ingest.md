# /ingest — Process a Single Source into the Wiki

Process a PDF, markdown file, or URL into a structured wiki summary with entities, relationships, and contradiction checks.

## Input

- `path`: Path to source file (PDF, markdown) or URL
- Examples:
  - `/ingest raw/inbox/attention-paper.pdf`
  - `/ingest raw/papers/bert.pdf`
  - `/ingest https://arxiv.org/abs/2301.12345`

---

## Step 1: Identify Source Type

Determine what kind of source this is:

| Extension / Pattern | Type | Extraction Method |
|---|---|---|
| `.pdf` | paper | Read the PDF directly (Claude Code can read PDFs natively) |
| `.md`, `.markdown` | clip | Read the markdown file |
| `http://`, `https://` | url | Fetch with `WebFetch` or `curl`, extract main content |

If the source is a URL pointing to an arXiv abstract page, download the PDF first:
```bash
python3 scripts/download_paper.py --url "[url]" --dest raw/papers/
```
Then proceed with the downloaded PDF.

---

## Step 2: Extract Content

### For PDFs
Read the PDF directly using the Read tool. Focus on extracting:
- **Title** (first page, usually largest text)
- **Authors** (below title, before abstract)
- **Abstract** (labeled section)
- **Introduction** (first ~500 words after abstract)
- **Conclusion** (last major section before references)
- **Key figures/tables** (note them, describe if relevant)

### For Markdown clips
Read the file. Extract:
- Title (first H1 or frontmatter `title:` field)
- Source URL (if in frontmatter)
- Main content body

### For URLs
Fetch the content and extract the main article body. Strip navigation, ads, sidebars.

---

## Step 3: Extract Metadata

Build frontmatter fields:

```yaml
title: "[Extracted or inferred title]"
authors: [Author1, Author2]
year: YYYY
type: paper | article | blog
source: "[[raw/papers/filename.pdf]]"
doi: "[if found — match pattern: 10.\d{4,}/[^\s]+]"
arxiv: "[if found — match pattern: \d{4}\.\d{4,}]"
venue: "[conference/journal if identifiable]"
confidence: 0.8
created: YYYY-MM-DD
updated: YYYY-MM-DD
status: processed
tags: [summary, primary-topic-tag]
```

**DOI detection**: Search the first 2 pages for `10.\d{4,}/[^\s]+`
**arXiv detection**: Check filename and first page for `\d{4}\.\d{4,}` patterns

---

## Step 4: Generate Summary

Create `wiki/summaries/YYYYMMDD-[kebab-title].md`:

```markdown
---
[frontmatter from Step 3]
---

## Summary
[2-3 sentences: What is the main contribution? What problem does it solve? What's novel?]

## Key Claims
1. [Primary claim] — confidence: high
2. [Secondary claim] — confidence: medium
3. [Tertiary claim] — confidence: medium

## Method
[1-2 sentences: What approach/technique do they use?]

## Results
[Key quantitative or qualitative findings]

## Relevance to My Research
[How does this connect to my thesis from CLAUDE.md? What can I use?]

## Limitations
[What are the weaknesses or constraints?]

## Entities Extracted
- People: [[Author1]], [[Author2]]
- Methods: [[Method-Name]]
- Tools: [[Tool-Name]]
- Datasets: [[Dataset-Name]]

## Relationships
- [[cites]] [[Other-Paper]] — [why relevant]
- [[extends]] [[Concept-Name]]
- [[uses]] [[Method-Name]]

## Follow-up Questions
- [ ] [Question raised by this paper]
```

**Length guidelines**:
- Papers: 300–500 words
- Articles/blogs: 100–200 words
- Focus on claims and insights, not description

---

## Step 5: Extract and Update Entities

For each person, method, tool, or dataset mentioned significantly:

### Check if entity page exists:
```bash
ls wiki/entities/ | grep -i "[entity-name]"
```

### If exists — add backlink:
Append to the entity's `## Appears In` section:
```markdown
- [[wiki/summaries/YYYYMMDD-title]]
```

### If new and important — create entity page:

**Importance criteria** (create if any apply):
- Authors of the paper (always create)
- Methods central to the paper
- Tools/datasets used extensively
- Mentioned 3+ times across wiki

Create `wiki/entities/[kebab-entity-name].md`:

```markdown
---
title: "[Display Name]"
type: person | method | tool | dataset
aliases: [alternate names]
confidence: 0.8
created: YYYY-MM-DD
tags: [entity, [type]]
---

## Overview
[2-3 sentences from context]

## Key Contributions
- [What are they known for?]

## Appears In
- [[wiki/summaries/YYYYMMDD-title]]

## Relationships
- [[affiliated_with]] [[Institution]]
```

---

## Step 6: Update Knowledge Graph

Append to `wiki/graph.md`:

```markdown
## [YYYY-MM-DD] Relationships from [[YYYYMMDD-title]]
- [[YYYYMMDD-title]] authored_by [[Author1]] | confidence: 1.0
- [[YYYYMMDD-title]] authored_by [[Author2]] | confidence: 1.0
- [[YYYYMMDD-title]] cites [[Cited-Paper]] | confidence: 0.9
- [[YYYYMMDD-title]] uses [[Method]] | confidence: 0.85
- [[YYYYMMDD-title]] extends [[Concept]] | confidence: 0.8
```

---

## Step 7: Check for Contradictions

Search the wiki for claims that might conflict with the new paper's claims:

```bash
grep -r "[key claim terms]" wiki/summaries/ wiki/concepts/
```

If a potential contradiction is found:
1. Read the conflicting page
2. Determine if it's actually a contradiction (not just different framing)
3. If real contradiction, create `wiki/contradictions/[topic]-YYYYMMDD.md`:

```markdown
---
title: "[Topic]"
type: contradiction
status: pending
created: YYYY-MM-DD
tags: [contradiction]
---

## Claim A (older)
Source: [[wiki/summaries/older-paper]]
Date: YYYY-MM-DD
Claim: "[exact claim]"
Confidence: 0.X

## Claim B (newer)
Source: [[wiki/summaries/new-paper]]
Date: YYYY-MM-DD
Claim: "[exact claim]"
Confidence: 0.Y

## Analysis
[Why do these conflict? Methodology, data, interpretation?]

## Proposed Resolution
[Which is more likely correct? Why?]
Basis: recency | authority | evidence | needs-human
```

---

## Step 8: Update Index

Add entry to `wiki/_index.md` under `## Summaries`:

```markdown
- [[YYYYMMDD-title]] — [one-line description] (YYYY)
```

Sort by date descending within the section. Also add any new entities or concepts to their respective index sections.

---

## Step 9: Update Log

Append to `wiki/_log.md`:

```markdown
## [YYYY-MM-DD HH:MM] ingest | [Title]
Source: [[raw/papers/filename.pdf]]
Summary: [[wiki/summaries/YYYYMMDD-title]]
Entities created: [[Entity1]], [[Entity2]]
Entities updated: [[Entity3]]
Concepts linked: [[Concept1]]
Contradictions: none | [[wiki/contradictions/topic]]
Confidence: 0.8
```

---

## Step 10: Report

Output for OpenClaw to relay to Telegram:

```
✅ Ingested: [Title]
📄 Summary: [[wiki/summaries/YYYYMMDD-title]]
👤 Entities: [N] created, [M] updated
🔗 Relationships: [K] added to graph
⚠️ Contradictions: [none | flagged: [topic]]
```

---

## Error Handling

**PDF extraction fails**:
```
⚠️ Could not extract text from [filename]
Possible issues: Scanned PDF (needs OCR), corrupted, password protected
Created stub: [[wiki/summaries/YYYYMMDD-title]] (status: needs-manual-review)
```

**Already processed**:
```
ℹ️ Already ingested: [title]
Existing summary: [[wiki/summaries/...]]
Use /reingest to update.
```

**URL fetch fails**:
```
❌ Could not fetch [url]: [error]
Check URL and try again.
```
