# /lint Command — Wiki Health Check

Audit the wiki for issues and auto-fix what's possible.

## Input
- `--fix`: Auto-fix issues (default: report only)
- `--deep`: Include confidence decay analysis
- `--section [name]`: Lint only specific section

## Examples
```bash
/lint                    # Report all issues
/lint --fix              # Report and auto-fix
/lint --deep             # Include confidence analysis
/lint --section entities # Lint only entities
```

---

## Checks Performed

### 1. Orphan Pages
Pages with no inbound [[wikilinks]].

```bash
# Find all wiki pages
find wiki -name "*.md" -type f > /tmp/all_pages.txt

# Find all wikilinks in the wiki
grep -roh '\[\[[^]]*\]\]' wiki/ | sort | uniq > /tmp/all_links.txt

# Pages not linked from anywhere
comm -23 /tmp/all_pages.txt /tmp/all_links.txt > /tmp/orphans.txt
```

**Auto-fix**: 
- If orphan is a summary → add to index.md
- If orphan is an entity → search for mentions, add backlinks
- If orphan is old/low-confidence → suggest archiving

### 2. Broken Links
[[wikilinks]] pointing to non-existent pages.

```bash
# Extract all link targets
grep -roh '\[\[[^]]*\]\]' wiki/ | sed 's/\[\[//g;s/\]\]//g' | sort | uniq > /tmp/link_targets.txt

# Check each target exists
while read link; do
    if [ ! -f "wiki/${link}.md" ] && [ ! -f "${link}" ]; then
        echo "BROKEN: $link"
    fi
done < /tmp/link_targets.txt
```

**Auto-fix**:
- Typo correction (fuzzy match existing pages)
- Remove obviously dead links
- Create stub pages for frequently referenced missing pages

### 3. Missing Index Entries
Wiki pages not listed in index.md.

```bash
# Pages that should be indexed
find wiki/summaries wiki/entities wiki/concepts wiki/synthesis -name "*.md" > /tmp/indexable.txt

# Check each is in index.md
while read page; do
    if ! grep -q "$(basename $page .md)" wiki/index.md; then
        echo "MISSING FROM INDEX: $page"
    fi
done < /tmp/indexable.txt
```

**Auto-fix**: Add missing entries to appropriate index section

### 4. Stale Contradictions
Contradictions unresolved for >7 days.

```bash
# Find old contradiction files
find wiki/contradictions -name "*.md" -mtime +7
```

**Auto-fix**: Cannot auto-resolve, but can:
- Notify human with summary
- Propose resolution based on confidence scores
- Escalate to daily report

### 5. Low-Confidence Claims
Claims with confidence <0.5.

```bash
grep -r "confidence: 0\.[0-4]" wiki/summaries/ wiki/concepts/
```

**Auto-fix**: 
- Flag for human review
- Search for corroborating sources
- Move to wiki/archive/ if confidence <0.3

### 6. Missing Entity Pages
Names mentioned ≥3 times without entity page.

```python
from collections import Counter
import re

# Extract all potential entity mentions (capitalized words)
mentions = Counter()
for file in glob.glob('wiki/**/*.md', recursive=True):
    content = open(file).read()
    # Find capitalized words that look like names
    names = re.findall(r'\b[A-Z][a-z]+ [A-Z][a-z]+\b', content)
    mentions.update(names)

# Filter: mentioned ≥3 times, no entity page
for name, count in mentions.most_common():
    slug = name.lower().replace(' ', '-')
    if count >= 3 and not os.path.exists(f'wiki/entities/{slug}.md'):
        print(f"MISSING ENTITY: {name} ({count} mentions)")
```

**Auto-fix**: Create stub entity page with basic info from context

### 7. Concept Gaps
Concepts referenced but lacking dedicated page.

Same approach as entities but for `wiki/concepts/`.

### 8. Graph Inconsistencies
Relationships in graph.md pointing to non-existent pages.

```bash
# Extract relationship targets
grep -oP '\[\[[^\]]+\]\]' wiki/graph.md | sort | uniq > /tmp/graph_targets.txt

# Check each exists
# (same as broken links check)
```

**Auto-fix**: Remove orphaned relationships

---

## Confidence Decay (--deep)

For claims not reinforced in 30+ days:

```python
from datetime import datetime, timedelta

DECAY_THRESHOLD = timedelta(days=30)
DECAY_AMOUNT = 0.05

for file in glob.glob('wiki/summaries/*.md'):
    frontmatter = extract_frontmatter(file)
    updated = datetime.fromisoformat(frontmatter['updated'])
    confidence = float(frontmatter['confidence'])
    
    if datetime.now() - updated > DECAY_THRESHOLD:
        new_confidence = max(0.1, confidence - DECAY_AMOUNT)
        print(f"DECAY: {file} {confidence} → {new_confidence}")
        
        if '--fix' in args:
            update_frontmatter(file, {
                'confidence': new_confidence,
                'updated': datetime.now().isoformat()
            })
```

---

## Output Report

### Console Output:
```
🔍 Wiki Lint Report
═══════════════════════════════════════════

📊 Overview
   Total pages: 342
   Summaries: 245
   Entities: 67
   Concepts: 30

🔴 Critical Issues
   Broken links: 5
   Stale contradictions: 2

🟡 Warnings  
   Orphan pages: 12
   Low-confidence claims: 8
   Missing entities: 4

🟢 Auto-Fixed
   Index entries added: 3
   Typos corrected: 2

📋 Action Required
   1. Resolve: [[wiki/contradictions/attention-20260410]]
   2. Review orphan: [[wiki/summaries/20260101-old-paper]]
   3. Verify low-confidence: [[wiki/concepts/sparse-attention]]

💡 Suggestions
   - Create entity page for "Ashish Vaswani" (mentioned 12 times)
   - Archive 3 papers with confidence <0.3
```

### Log Entry:
```markdown
## [YYYY-MM-DD HH:MM] lint | Wiki health check

### Stats
- Pages scanned: 342
- Issues found: 31
- Auto-fixed: 5

### Critical
- [ ] Broken link: [[Missing-Page]] in [[Summary-A]]
- [ ] Stale contradiction: [[contradictions/topic]] (12 days)

### Fixed
- Added 3 missing index entries
- Corrected typo: [[Atention]] → [[Attention]]

### Recommendations
- Create entity: Ashish Vaswani
- Review orphans: 12 pages
```

---

## Scheduling

Add to Heartbeat for automated maintenance:

```markdown
## Weekly: Sunday 6:00 PM
1. Run: /lint --fix --deep
2. Generate report
3. Send summary to Telegram
4. Create wiki/reports/lint-YYYYMMDD.md
```

---

## Manual Intervention Queue

For issues that can't be auto-fixed, create a queue:

```markdown
# wiki/maintenance-queue.md

## Pending Human Review

### Contradictions (resolve within 7 days)
- [ ] [[contradictions/attention-mechanism]] — Created: 2026-04-10
- [ ] [[contradictions/scaling-laws]] — Created: 2026-04-08

### Low Confidence (verify or archive)
- [ ] [[summaries/20250615-old-paper]] — confidence: 0.4
- [ ] [[concepts/deprecated-method]] — confidence: 0.35

### Missing Entities (create or skip)
- [ ] "Ashish Vaswani" — 12 mentions — Create? Skip?
- [ ] "FlashAttention" — 8 mentions — Create? Skip?

### Orphans (link or archive)
- [ ] [[summaries/20240101-ancient-paper]] — No references
```

Human processes this queue, then runs `/lint --clear-queue` to update.
