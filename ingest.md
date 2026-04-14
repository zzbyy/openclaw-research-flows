# /ingest Command — Detailed Workflow

Process a single source into the wiki.

## Input
- `path`: Path to source file (PDF, markdown, or URL)

## Prerequisites
```bash
# Ensure we have PDF extraction
pip install pymupdf --quiet 2>/dev/null || true
```

## Step 1: Identify Source Type

```python
import os
path = "[INPUT_PATH]"
ext = os.path.splitext(path)[1].lower()

if ext == '.pdf':
    source_type = 'paper'
elif ext in ['.md', '.markdown']:
    source_type = 'clip'
elif path.startswith('http'):
    source_type = 'url'
else:
    source_type = 'unknown'
```

## Step 2: Extract Content

### For PDFs:
```bash
python scripts/extract_pdf.py "[path]" --output /tmp/extracted.txt
```

Or use Claude Code's native PDF reading:
```
View("[path]")  # Claude Code can read PDFs directly
```

Focus on:
- Title (first page, usually largest text)
- Authors (below title)
- Abstract (labeled section)
- Introduction (first ~500 words)
- Conclusion (last section)

### For Markdown clips:
```
View("[path]")
```
Read the full content, extract:
- Title (first H1 or frontmatter)
- Source URL (if in frontmatter)
- Main content

### For URLs:
```bash
curl -s "[url]" | python scripts/html_to_md.py > /tmp/extracted.md
```

## Step 3: Extract Metadata

Build frontmatter:

```yaml
title: "[Extracted or inferred title]"
authors: [Author1, Author2]  # From paper or byline
year: YYYY                   # From content or filename
type: paper | article | blog
source: "[[raw/papers/filename.pdf]]"  # Wikilink to original
doi: "[if found]"
arxiv: "[if found]"
venue: "[conference/journal if paper]"
confidence: 0.8              # Default for new sources
created: YYYY-MM-DD          # Today
updated: YYYY-MM-DD          # Today
status: processed
tags: [summary, [primary-topic]]
```

### Extracting DOI/arXiv:
- Look for patterns: `10.\d{4,}/[^\s]+` (DOI)
- Look for patterns: `\d{4}\.\d{4,}` (arXiv)
- Check filename for arXiv ID

## Step 4: Generate Summary

Write to `wiki/summaries/YYYYMMDD-[kebab-title].md`:

```markdown
---
[frontmatter from Step 3]
---

## Summary
[2-3 sentences answering: What is the main contribution? What problem does it solve? What's novel?]

## Key Claims
1. [Primary claim] — confidence: high
2. [Secondary claim] — confidence: medium
3. [Tertiary claim] — confidence: medium

## Method
[1-2 sentences: What approach/technique do they use?]

## Results
[Key quantitative or qualitative findings]

## Relevance to My Research
[How does this connect to my thesis? What can I use?]

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

### Length Guidelines:
- Papers: 300-500 words
- Articles/blogs: 100-200 words
- Focus on claims, not description

## Step 5: Extract and Update Entities

For each person, method, tool, dataset mentioned:

### Check if exists:
```bash
ls wiki/entities/ | grep -i "[entity-name]"
```

### If exists — add backlink:
```
Edit("wiki/entities/[entity].md", 
     "## Appears In\n", 
     "## Appears In\n- [[wiki/summaries/[new-summary]]]\n")
```

### If new and important — create entity page:

Criteria for "important":
- Authors of the paper (always create)
- Methods central to the paper
- Tools/datasets used extensively
- Mentioned 2+ times

```markdown
# wiki/entities/[entity-name].md

---
type: person | method | tool | dataset
name: "[Display Name]"
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
- [[wiki/summaries/[new-summary]]]

## Relationships
- [[affiliated_with]] [[Institution]]
```

## Step 6: Update Knowledge Graph

Append to `wiki/graph.md`:

```markdown
## [YYYY-MM-DD] Relationships from [[Summary-Title]]
- [[Summary-Title]] authored_by [[Author1]] | confidence: 1.0
- [[Summary-Title]] authored_by [[Author2]] | confidence: 1.0
- [[Summary-Title]] cites [[Cited-Paper]] | confidence: 0.9
- [[Summary-Title]] uses [[Method]] | confidence: 0.85
- [[Summary-Title]] extends [[Concept]] | confidence: 0.8
```

## Step 7: Check for Contradictions

Search wiki for claims that might conflict:

```bash
grep -r "[key claim terms]" wiki/summaries/ wiki/concepts/
```

If potential contradiction found:
1. Read the conflicting page
2. Determine if it's actually a contradiction (not just different framing)
3. If real contradiction:

```markdown
# wiki/contradictions/[topic]-YYYYMMDD.md

---
topic: "[topic]"
created: YYYY-MM-DD
status: pending
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
[Why do these conflict? Is it methodology, data, interpretation?]

## Proposed Resolution
[Which is more likely correct? Why?]
Basis: recency | authority | evidence | needs-human
```

## Step 8: Update Index

Add entry to `wiki/index.md` under appropriate section:

```markdown
### Summaries
- [[YYYYMMDD-title]] — [one-line description] (YYYY)
```

Sort by date descending within each section.

## Step 9: Update Log

Append to `wiki/log.md`:

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

## Step 10: Report

Output for OpenClaw to relay:

```
✅ Ingested: [Title]
📄 Summary: [[wiki/summaries/YYYYMMDD-title]]
👤 Entities: [count] created, [count] updated
🔗 Relationships: [count] added to graph
⚠️ Contradictions: [none | flagged: [topic]]
```

## Error Handling

If PDF extraction fails:
```
⚠️ Could not extract text from [filename]
Possible issues:
- Scanned PDF (needs OCR)
- Corrupted file
- Password protected

Created stub: [[wiki/summaries/YYYYMMDD-title]]
Status: needs-manual-review
```

If already processed:
```
ℹ️ Already ingested: [title]
Existing summary: [[wiki/summaries/...]]
Use /reingest to update.
```
