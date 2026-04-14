# /lint — Wiki Health Check & Maintenance

Audit the wiki for structural issues and auto-fix what's possible.

## Input

- `--fix`: Auto-fix issues (default: report only)
- `--deep`: Include confidence decay analysis
- `--section [name]`: Lint only a specific section (summaries, entities, concepts)
- `--decay-only`: Only run confidence decay (for monthly scheduled runs)

## Examples

```bash
/lint                    # Report all issues
/lint --fix              # Report and auto-fix
/lint --deep             # Include confidence analysis
/lint --section entities # Lint only entities
/lint --decay-only       # Monthly confidence decay
```

---

## Check 1: Orphan Pages

Pages with no inbound `[[wikilinks]]` from any other page.

**How to check**:
1. List all `.md` files in `wiki/summaries/`, `wiki/entities/`, `wiki/concepts/`
2. Search all wiki files for `[[wikilinks]]` and collect all link targets
3. Pages not referenced by any other page are orphans

**Auto-fix** (`--fix`):
- If orphan is a summary → add to `wiki/_index.md`
- If orphan is an entity → search all wiki files for mentions of the entity name, add backlinks
- If orphan is old and low-confidence → suggest archiving

---

## Check 2: Broken Links

`[[wikilinks]]` pointing to pages that don't exist.

**How to check**:
1. Extract all `[[link-target]]` patterns from wiki files
2. For each target, check if the corresponding file exists
3. Report broken links with the source file

**Auto-fix** (`--fix`):
- Attempt fuzzy match against existing pages (typo correction)
- Remove obviously dead links
- Create stub pages for targets referenced 3+ times

---

## Check 3: Missing Index Entries

Wiki pages not listed in `wiki/_index.md`.

**How to check**:
1. List all files in `wiki/summaries/`, `wiki/entities/`, `wiki/concepts/`, `wiki/synthesis/`
2. Check if each file's name appears in `wiki/_index.md`

**Auto-fix** (`--fix`):
Add missing entries to the appropriate section of `wiki/_index.md`.

---

## Check 4: Stale Contradictions

Contradictions in `wiki/contradictions/` that have been pending for more than 7 days.

**How to check**:
1. Read all files in `wiki/contradictions/`
2. Filter for `status: pending`
3. Check the `created` date — flag if >7 days old

**Auto-fix**: Cannot auto-resolve contradictions. Instead:
- Notify human with summary
- Propose resolution based on confidence scores of each claim
- Escalate to daily report

---

## Check 5: Low-Confidence Claims

Summaries or concepts with confidence below 0.5.

**How to check**:
1. Scan frontmatter of all wiki files for `confidence:` field
2. Flag any with confidence < 0.5

**Auto-fix** (`--fix`):
- Flag for human review
- If confidence < 0.3, move to suggested archive list

---

## Check 6: Missing Entity Pages

Names mentioned 3+ times across the wiki without a dedicated entity page.

**How to check**:
1. Search all wiki files for capitalized names (potential person entities)
2. Count occurrences across files
3. For names appearing 3+ times, check if `wiki/entities/[name].md` exists

**Auto-fix** (`--fix`):
Create a stub entity page with basic info gathered from the contexts where the name appears.

---

## Check 7: Concept Gaps

Concepts referenced in wikilinks but lacking a dedicated page in `wiki/concepts/`.

**How to check**:
1. Extract all `[[concept-name]]` links from summaries and entities
2. Check if each concept has a page in `wiki/concepts/`

**Auto-fix** (`--fix`):
Create stub concept pages with info gathered from referencing pages.

---

## Check 8: Graph Inconsistencies

Relationships in `wiki/graph.md` pointing to pages that no longer exist.

**How to check**:
1. Parse all `[[targets]]` in `wiki/graph.md`
2. Check each target file exists

**Auto-fix** (`--fix`):
Remove orphaned relationship entries from `wiki/graph.md`.

---

## Confidence Decay (--deep or --decay-only)

For claims not reinforced in 30+ days:

1. Scan all wiki files with `confidence:` and `updated:` frontmatter
2. For each file where `updated` is more than 30 days ago:
   - Reduce confidence by 0.05 (minimum 0.1)
   - Update the `updated` date to today
   - Update the `confidence` field
3. Flag any claims that dropped below 0.5 (need verification)
4. Suggest archiving claims below 0.3

Report the decay:
```
📉 Confidence Decay
- Decayed: [N] claims
- Now below 0.5: [N] (need verification)
- Below 0.3: [N] (suggest archive)
- Strongest claims: [top 3 with scores]
```

---

## Output Report

### Console/Telegram Output:

```
🔍 Wiki Lint Report
═══════════════════

📊 Overview
   Total pages: [N]
   Summaries: [N]
   Entities: [N]
   Concepts: [N]

🔴 Critical Issues
   Broken links: [N]
   Stale contradictions: [N]

🟡 Warnings
   Orphan pages: [N]
   Low-confidence claims: [N]
   Missing entities: [N]

🟢 Auto-Fixed (if --fix)
   Index entries added: [N]
   Typos corrected: [N]
   Stubs created: [N]

📋 Action Required
   1. Resolve: [[wiki/contradictions/topic]]
   2. Review orphan: [[wiki/summaries/old-paper]]
   3. Verify low-confidence: [[wiki/concepts/topic]]

💡 Suggestions
   - Create entity page for "[Name]" (mentioned [N] times)
   - Archive [N] papers with confidence <0.3
```

### Log Entry:

Append to `wiki/_log.md`:

```markdown
## [YYYY-MM-DD HH:MM] lint | Wiki health check

### Stats
- Pages scanned: [N]
- Issues found: [N]
- Auto-fixed: [N]

### Critical
- [ ] Broken link: [[Missing-Page]] in [[Summary-A]]
- [ ] Stale contradiction: [[contradictions/topic]] ([N] days)

### Fixed
- Added [N] missing index entries
- Corrected typo: [[Atention]] → [[Attention]]

### Recommendations
- Create entity: [Name]
- Review orphans: [N] pages
```

---

## Maintenance Queue

For issues that can't be auto-fixed, append to `wiki/maintenance-queue.md` (create if doesn't exist):

```markdown
# Maintenance Queue

## Pending Human Review

### Contradictions (resolve within 7 days)
- [ ] [[contradictions/topic]] — Created: YYYY-MM-DD

### Low Confidence (verify or archive)
- [ ] [[summaries/old-paper]] — confidence: 0.4

### Missing Entities (create or skip)
- [ ] "[Name]" — [N] mentions — Create? Skip?

### Orphans (link or archive)
- [ ] [[summaries/old-paper]] — No references
```
