# /batch Command — Detailed Workflow

Process multiple papers efficiently.

## Input
- `folder`: Path to folder containing PDFs (default: `raw/inbox`)
- `count`: Max papers to process (default: 10)
- `--priority`: Prioritization method (default: recent)

## Examples
```bash
/batch raw/inbox 5              # Process 5 from inbox
/batch raw/papers/2026 10       # Process 10 from 2026
/batch raw/papers --all         # Process all unprocessed
/batch --continue               # Continue from last position
```

---

## Step 1: Load or Create Inventory

Check for existing inventory:

```bash
if [ -f "wiki/paper-inventory.csv" ]; then
    echo "Loading existing inventory..."
else
    echo "Creating new inventory..."
    python scripts/inventory_pdfs.py raw/papers
fi
```

### Inventory CSV Format:
```csv
path,filename,title,year,processed,summary_path,priority,last_attempt,notes
raw/papers/2026/attention.pdf,attention.pdf,Attention Is All You Need,2017,true,wiki/summaries/20260413-attention.md,high,,
raw/papers/2025/bert.pdf,bert.pdf,BERT,2018,false,,medium,,
```

---

## Step 2: Select Papers to Process

### Priority Algorithm:

```python
import csv
from datetime import datetime

def prioritize_papers(inventory_path, count, method='smart'):
    with open(inventory_path) as f:
        papers = list(csv.DictReader(f))
    
    # Filter unprocessed
    unprocessed = [p for p in papers if p['processed'] != 'true']
    
    if method == 'recent':
        # Most recent first
        unprocessed.sort(key=lambda x: -int(x['year'] or 0))
    
    elif method == 'smart':
        # Score by multiple factors
        for p in unprocessed:
            score = 0
            # Recency bonus
            year = int(p['year'] or 2000)
            score += (year - 2000) * 2  # +2 per year after 2000
            
            # Keyword bonus (check title against research keywords)
            keywords = ['attention', 'transformer', 'efficient']  # From CLAUDE.md
            title = p['title'].lower()
            score += sum(10 for k in keywords if k in title)
            
            # Priority override
            if p['priority'] == 'high': score += 50
            if p['priority'] == 'low': score -= 20
            
            p['_score'] = score
        
        unprocessed.sort(key=lambda x: -x['_score'])
    
    elif method == 'author':
        # Papers by tracked authors first
        tracked = ['Vaswani', 'Sutskever']  # From CLAUDE.md
        def author_score(p):
            return sum(1 for a in tracked if a.lower() in p['title'].lower())
        unprocessed.sort(key=author_score, reverse=True)
    
    return unprocessed[:count]
```

---

## Step 3: Process Each Paper

For each selected paper:

```python
results = []
for paper in selected_papers:
    print(f"\n{'='*50}")
    print(f"Processing: {paper['filename']}")
    print(f"{'='*50}")
    
    try:
        # Run ingest workflow
        result = ingest(paper['path'])
        
        # Update inventory
        paper['processed'] = 'true'
        paper['summary_path'] = result['summary_path']
        paper['last_attempt'] = datetime.now().isoformat()
        
        results.append({
            'status': 'success',
            'title': result['title'],
            'summary': result['summary_path'],
            'entities_created': result['entities_created'],
            'entities_updated': result['entities_updated']
        })
        
    except Exception as e:
        paper['last_attempt'] = datetime.now().isoformat()
        paper['notes'] = str(e)
        
        results.append({
            'status': 'failed',
            'title': paper['filename'],
            'error': str(e)
        })
```

### Rate Limiting:
- Pause 2 seconds between papers (avoid overwhelming)
- If processing time > 60s, flag as complex

---

## Step 4: Update Inventory

Write back to `wiki/paper-inventory.csv`:

```python
with open('wiki/paper-inventory.csv', 'w', newline='') as f:
    writer = csv.DictWriter(f, fieldnames=papers[0].keys())
    writer.writeheader()
    writer.writerows(papers)
```

---

## Step 5: Generate Batch Report

Append to `wiki/log.md`:

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
- ETA at 10/day: ~D days
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
⏱️ ETA: ~[D] days remaining

Next batch: /batch [folder] [count]
```

---

## Batch Strategies

### Initial Library Processing
For a fresh ~2000 paper library:

```bash
# Week 1: High-value papers
/batch raw/papers --priority high --count 50

# Week 2-4: Recent papers (last 2 years)
/batch raw/papers/2026 20
/batch raw/papers/2025 20

# Ongoing: Background processing
# (via Heartbeat: 5 papers/day)
```

### Targeted Batch
When exploring a specific topic:

```bash
# Process all papers with "attention" in title
/batch raw/papers --filter "attention" --count 20
```

### Catch-up After Absence
```bash
# Process everything in inbox
/batch raw/inbox --all

# Then resume background processing
/batch --continue
```

---

## Error Recovery

### Common Failures:

**Scanned PDFs (no extractable text)**
```
⚠️ [filename]: No extractable text
Action: Created stub, marked for OCR
Fix: Run OCR tool, then /reingest
```

**Corrupted PDFs**
```
❌ [filename]: File corrupted
Action: Skipped, logged
Fix: Re-download or remove from library
```

**Timeout (large/complex paper)**
```
⚠️ [filename]: Processing timeout
Action: Created partial summary
Fix: /ingest [path] --deep for full processing
```

### Recovery Commands:
```bash
/batch --retry-failed           # Retry all failed papers
/batch --reset [filename]       # Reset single paper for reprocessing
/batch --skip [filename]        # Mark as skip (won't process)
```

---

## Performance Tuning

### For Large Libraries:

1. **Parallel Processing** (if resources allow):
```bash
# Split into chunks, process in parallel sessions
/batch raw/papers/2026 --chunk 1of4
/batch raw/papers/2026 --chunk 2of4
# etc.
```

2. **Shallow First, Deep Later**:
```bash
# Quick pass: title + abstract only
/batch raw/papers --shallow --count 100

# Deep pass on important ones
/batch raw/papers --deep --filter "high-priority"
```

3. **Incremental Confidence**:
- First pass: confidence 0.6 (basic extraction)
- Human review: boost confidence on verified
- Second pass: confidence 0.8 (full processing)

---

## Integration with Heartbeat

Daily background processing (add to Heartbeat config):

```markdown
## Daily: 9:00 PM
1. Run: /batch raw/inbox --all
2. Run: /batch --continue --count 5
3. Report progress to Telegram
```

This processes ~5 papers/day = ~150/month = full library in ~13 months
(Adjust count based on your time/cost tolerance)
