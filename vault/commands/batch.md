# /batch — Process Multiple Papers

Batch-process papers from a folder using the `/ingest` workflow for each.

## Input

- `folder`: Path to folder containing PDFs (default: `raw/inbox`)
- `count`: Max papers to process this run (default: 10)
- `--all`: Process all unprocessed papers in the folder
- `--continue`: Resume from last position in inventory
- `--priority [recent|smart|author]`: Prioritization method (default: smart)

## Examples

```bash
/batch raw/inbox 5              # Process 5 from inbox
/batch raw/papers 10            # Process 10 from papers
/batch raw/inbox --all          # Process everything in inbox
/batch --continue 5             # Continue from inventory, 5 papers
```

---

## Step 1: Load or Create Inventory

Check if `wiki/paper-inventory.csv` has entries:

```bash
wc -l wiki/paper-inventory.csv
```

### If inventory is empty or folder has new files:

Scan the target folder for PDFs not yet in the inventory:

```bash
ls [folder]/*.pdf
```

For each new PDF found, add a row to `wiki/paper-inventory.csv`:

```csv
path,filename,title,year,processed,summary_path,priority,last_attempt,notes
raw/papers/attention.pdf,attention.pdf,Attention Is All You Need,2017,true,wiki/summaries/20260413-attention.md,high,,
raw/inbox/bert.pdf,bert.pdf,,,,false,,medium,,
```

For new entries:
- `title`: Try to extract from filename (strip author info, z-lib tags, etc.)
- `year`: Extract from filename if present, otherwise leave empty
- `processed`: `false`
- `priority`: `medium` (default)

---

## Step 2: Select Papers to Process

Filter the inventory to unprocessed papers, then apply priority:

### Priority: `recent` (default for catch-up)
Sort by year descending. Most recent papers first.

### Priority: `smart` (default)
Score each unprocessed paper by:
- +2 per year after 2000 (recency)
- +10 for each primary keyword from CLAUDE.md found in title
- +5 for each secondary keyword found in title
- +50 if manually marked as `high` priority
- -20 if manually marked as `low` priority

Sort by score descending.

### Priority: `author`
Papers by tracked researchers from CLAUDE.md first.

Select the top `count` papers from the sorted list.

---

## Step 3: Process Each Paper

For each selected paper:

1. Print progress: `[N/total] Processing: filename`
2. Run the full `/ingest` workflow (follow `commands/ingest.md`)
3. On success:
   - Update inventory: `processed=true`, `summary_path=[path]`, `last_attempt=[now]`
4. On failure:
   - Update inventory: `last_attempt=[now]`, `notes=[error message]`
   - Continue to next paper (don't stop the batch)

**Rate limiting**: Pause briefly between papers to avoid overwhelming the system.

---

## Step 4: Update Inventory

Write the updated inventory back to `wiki/paper-inventory.csv`.

---

## Step 5: Generate Batch Report

Append to `wiki/_log.md`:

```markdown
## [YYYY-MM-DD HH:MM] batch | Processed [N] papers

### Successful ([M])
| Paper | Summary | Entities |
|-------|---------|----------|
| [Title 1] | [[wiki/summaries/...]] | +2 created |
| [Title 2] | [[wiki/summaries/...]] | +1 updated |

### Failed ([K])
| Paper | Error |
|-------|-------|
| [filename] | [error message] |

### Progress
- Total in library: X
- Processed: Y (Z%)
- Remaining: W
```

---

## Step 6: Report to OpenClaw

```
📦 Batch Complete: [N] papers processed

✅ Successful: [M]
- [Title 1] → [[summary]]
- [Title 2] → [[summary]]

❌ Failed: [K]
- [filename]: [short error]

📊 Progress: [Y]/[X] papers (Z%)
```

---

## Batch Strategies

### Initial Library Processing
For a large PDF library:
```bash
# Week 1: High-value papers
/batch raw/papers --priority smart 50

# Week 2-4: Recent papers
/batch raw/papers --priority recent 20

# Ongoing: Background processing (via Heartbeat)
/batch --continue 5
```

### Catch-up After Absence
```bash
/batch raw/inbox --all          # Process inbox first
/batch --continue 5             # Then resume background
```

---

## Error Recovery

**Scanned PDF (no text)**:
```
⚠️ [filename]: No extractable text → stub created, marked for OCR
```

**Corrupted PDF**:
```
❌ [filename]: File corrupted → skipped, logged
```

**Timeout (complex paper)**:
```
⚠️ [filename]: Processing took too long → partial summary created
```

### Recovery commands:
```bash
/batch --retry-failed           # Retry all failed papers
```
