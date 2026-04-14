# /monitor Command — Literature Monitoring & Automated Reviews

Continuous literature tracking with periodic synthesis.

## Commands

```bash
/monitor status                  # Show monitoring status
/monitor add-researcher [name]   # Track a new researcher
/monitor add-paper [id]          # Track citations to a paper
/monitor add-topic [topic]       # Track emerging topic
/monitor run                     # Run full monitoring cycle
/monitor review [topic]          # Generate literature review
/monitor gaps                    # Analyze knowledge gaps
```

---

## Part 1: Monitoring Infrastructure

### 1.1 Monitoring Configuration

Create `wiki/monitoring/config.md`:

```markdown
# Literature Monitoring Configuration

## Tracked Researchers
<!-- Format: Name | Institution | Alert Level | Last Checked -->
| Name | Institution | Alert Level | Last Checked |
|------|-------------|-------------|--------------|
| [Researcher 1] | [Institution] | 🔴 high | YYYY-MM-DD |
| [Researcher 2] | [Institution] | 🟡 medium | YYYY-MM-DD |

## Tracked Papers (Citation Monitoring)
<!-- Papers whose citations we monitor -->
| Paper | ID | Why Important | Citations Last Check |
|-------|-----|---------------|---------------------|
| Attention Is All You Need | 1706.03762 | Foundation | 45,231 |
| [Your key paper] | [ID] | [Reason] | [Count] |

## Tracked Topics
<!-- Emerging areas to watch -->
| Topic | Keywords | Alert Threshold | Last Checked |
|-------|----------|-----------------|--------------|
| Efficient Attention | flash attention, linear attention, sparse | 5 papers/week | YYYY-MM-DD |
| [Your topic] | [keywords] | [threshold] | YYYY-MM-DD |

## Alert Levels
- 🔴 **High**: Immediate notification + auto-ingest
- 🟡 **Medium**: Include in daily briefing
- 🟢 **Low**: Weekly summary only
```

### 1.2 Monitoring State

Create `wiki/monitoring/state.md`:

```markdown
# Monitoring State

## Last Full Run
- Date: YYYY-MM-DD HH:MM
- Duration: Xm Ys
- Papers Found: N
- Alerts Triggered: M

## Researcher Check Cursors
<!-- Track pagination/dates for incremental checks -->
| Researcher | Last Paper Date | Cursor |
|------------|-----------------|--------|
| [Name] | YYYY-MM-DD | [cursor] |

## Citation Cursors
| Paper ID | Last Citation Count | Last New Citation Date |
|----------|---------------------|------------------------|
| 1706.03762 | 45,231 | YYYY-MM-DD |

## Topic Cursors
| Topic | Last Check Date | Papers Since |
|-------|-----------------|--------------|
| Efficient Attention | YYYY-MM-DD | 12 |
```

---

## Part 2: /monitor run — Full Monitoring Cycle

### Step 1: Load Monitoring Config

```python
config = parse_monitoring_config('wiki/monitoring/config.md')
state = parse_monitoring_state('wiki/monitoring/state.md')

researchers = config['tracked_researchers']
tracked_papers = config['tracked_papers']
tracked_topics = config['tracked_topics']
```

### Step 2: Check Tracked Researchers

```python
researcher_alerts = []

for researcher in researchers:
    print(f"Checking: {researcher['name']}...")
    
    # Get papers since last check
    last_check = state['researcher_cursors'].get(researcher['name'], {}).get('last_date')
    
    new_papers = search_semantic_scholar(
        author=researcher['name'],
        after_date=last_check
    )
    
    if new_papers:
        for paper in new_papers:
            # Score against thesis overlap
            overlap = calculate_thesis_overlap(paper)
            
            alert = {
                'type': 'researcher',
                'researcher': researcher['name'],
                'paper': paper,
                'overlap': overlap,
                'level': researcher['alert_level']
            }
            
            # Escalate if high thesis overlap
            if overlap > 0.7:
                alert['level'] = '🔴 high'
                alert['reason'] = 'HIGH THESIS OVERLAP'
            
            researcher_alerts.append(alert)
        
        # Update cursor
        state['researcher_cursors'][researcher['name']] = {
            'last_date': new_papers[0]['date'],
            'cursor': new_papers[0]['id']
        }
```

### Step 3: Check Citation Networks

```python
citation_alerts = []

for tracked in tracked_papers:
    print(f"Checking citations to: {tracked['title'][:50]}...")
    
    # Get current citation count
    current_count = get_citation_count(tracked['id'])
    last_count = state['citation_cursors'].get(tracked['id'], {}).get('count', 0)
    
    if current_count > last_count:
        new_count = current_count - last_count
        print(f"  +{new_count} new citations")
        
        # Get the new citing papers
        new_citations = get_new_citations(
            paper_id=tracked['id'],
            since_count=last_count,
            limit=20
        )
        
        for citing_paper in new_citations:
            # Score relevance
            relevance = score_citation_relevance(citing_paper, tracked)
            
            if relevance['score'] > 30:
                citation_alerts.append({
                    'type': 'citation',
                    'cited_paper': tracked['title'],
                    'citing_paper': citing_paper,
                    'relevance': relevance,
                    'level': '🟡 medium' if relevance['score'] < 50 else '🔴 high'
                })
        
        # Update cursor
        state['citation_cursors'][tracked['id']] = {
            'count': current_count,
            'last_date': date.today().isoformat()
        }
```

### Step 4: Check Emerging Topics

```python
topic_alerts = []

for topic in tracked_topics:
    print(f"Checking topic: {topic['name']}...")
    
    last_check = state['topic_cursors'].get(topic['name'], {}).get('last_date')
    
    # Search for papers matching topic keywords
    papers = search_arxiv_and_ss(
        keywords=topic['keywords'],
        after_date=last_check,
        limit=50
    )
    
    # Filter to truly relevant
    relevant = [p for p in papers if topic_match_score(p, topic) > 0.5]
    
    if len(relevant) >= topic['alert_threshold']:
        topic_alerts.append({
            'type': 'topic_surge',
            'topic': topic['name'],
            'count': len(relevant),
            'papers': relevant[:10],  # Top 10
            'level': '🟡 medium'
        })
    
    # Track individual high-impact papers
    for paper in relevant:
        if paper.get('citation_count', 0) > 20 or is_from_major_lab(paper):
            topic_alerts.append({
                'type': 'topic_paper',
                'topic': topic['name'],
                'paper': paper,
                'level': '🟡 medium'
            })
    
    # Update cursor
    state['topic_cursors'][topic['name']] = {
        'last_date': date.today().isoformat(),
        'papers_since': len(relevant)
    }
```

### Step 5: Process Alerts

```python
all_alerts = researcher_alerts + citation_alerts + topic_alerts

# Sort by level and relevance
all_alerts.sort(key=lambda x: (
    0 if '🔴' in x['level'] else 1 if '🟡' in x['level'] else 2,
    -x.get('relevance', {}).get('score', 0)
))

# Process high-priority alerts
for alert in all_alerts:
    if '🔴' in alert['level']:
        # Auto-ingest
        pdf_path = download_paper(alert['paper'])
        if pdf_path:
            ingest_result = ingest_paper(pdf_path, alert['paper'])
            alert['ingested'] = True
            alert['summary_path'] = ingest_result['summary_path']
        
        # Immediate notification
        send_urgent_alert(alert)
    
    elif '🟡' in alert['level']:
        # Add to triage queue for daily briefing
        add_to_triage_queue(alert)
```

### Step 6: Generate Monitoring Report

Create `wiki/monitoring/reports/YYYY-MM-DD.md`:

```markdown
# Monitoring Report — YYYY-MM-DD

## 🔴 Urgent Alerts

{{for alert in urgent_alerts}}
### {{alert.type | title}}: {{alert.paper.title}}

**Source**: {{alert.researcher or alert.topic or "Citation to " + alert.cited_paper}}
**Why urgent**: {{alert.reason}}
**Thesis overlap**: {{alert.overlap * 100}}%

> {{alert.paper.abstract | truncate(200)}}

**Action taken**: {{alert.action}}
**Summary**: [[{{alert.summary_path}}]]

---
{{endfor}}

## 🟡 Notable Activity

### Researcher Updates
{{for r in researcher_summary}}
- **{{r.name}}**: {{r.new_papers}} new papers
  {{for p in r.papers[:3]}}
  - {{p.title | truncate(50)}}
  {{endfor}}
{{endfor}}

### Citation Activity
{{for c in citation_summary}}
- **{{c.paper | truncate(40)}}**: +{{c.new_citations}} citations
  - Notable: {{c.notable_citations | join(", ")}}
{{endfor}}

### Topic Trends
{{for t in topic_summary}}
- **{{t.name}}**: {{t.paper_count}} papers this period
  - Trend: {{t.trend}}
{{endfor}}

## 📊 Statistics

| Metric | Value |
|--------|-------|
| Researchers checked | {{researchers_checked}} |
| New papers found | {{total_new_papers}} |
| Citations tracked | {{total_new_citations}} |
| Urgent alerts | {{urgent_count}} |
| Auto-ingested | {{auto_ingested}} |

## 📋 Triage Queue

{{triage_count}} papers added to triage for next briefing.

---
*Generated by `/monitor run` at {{timestamp}}*
```

### Step 7: Update State and Notify

```python
# Save updated state
save_monitoring_state(state)

# Update log
append_to_log(f"""
## [{datetime.now()}] monitor | Full monitoring cycle

### Checked
- Researchers: {len(researchers)}
- Citation seeds: {len(tracked_papers)}
- Topics: {len(tracked_topics)}

### Found
- Researcher papers: {len(researcher_alerts)}
- Citation alerts: {len(citation_alerts)}
- Topic alerts: {len(topic_alerts)}

### Actions
- Urgent alerts: {len([a for a in all_alerts if '🔴' in a['level']])}
- Auto-ingested: {len([a for a in all_alerts if a.get('ingested')])}
- Added to triage: {len([a for a in all_alerts if '🟡' in a['level']])}
""")

# OpenClaw notification
if urgent_alerts:
    notify(f"""
🚨 MONITORING ALERT

{len(urgent_alerts)} urgent items:
{{for a in urgent_alerts[:3]}}
• {a['paper']['title'][:50]}
  {a['reason']}
{{endfor}}

Full report: wiki/monitoring/reports/{date.today()}.md
""")
else:
    # Silent success or brief summary
    notify(f"✅ Monitoring complete: {len(all_alerts)} items tracked")
```

---

## Part 3: /monitor review [topic] — Literature Review Generation

### Step 1: Gather Sources

```python
def generate_literature_review(topic):
    # Find all wiki content related to topic
    summaries = search_wiki_summaries(topic)
    concepts = search_wiki_concepts(topic)
    entities = search_wiki_entities(topic)
    
    # Also check for related topics
    related_topics = find_related_concepts(topic)
    for rt in related_topics:
        summaries.extend(search_wiki_summaries(rt))
    
    # Deduplicate and sort by relevance
    summaries = dedupe_by_title(summaries)
    summaries.sort(key=lambda x: -calculate_topic_relevance(x, topic))
    
    return {
        'summaries': summaries,
        'concepts': concepts,
        'entities': entities,
        'related_topics': related_topics
    }
```

### Step 2: Analyze and Structure

```python
def analyze_for_review(sources, topic):
    analysis = {
        'papers_by_year': defaultdict(list),
        'papers_by_approach': defaultdict(list),
        'key_claims': [],
        'consensus_points': [],
        'debates': [],
        'gaps': [],
        'trends': []
    }
    
    for summary in sources['summaries']:
        # Temporal distribution
        analysis['papers_by_year'][summary['year']].append(summary)
        
        # Methodological clustering
        approach = classify_approach(summary)
        analysis['papers_by_approach'][approach].append(summary)
        
        # Extract claims
        for claim in summary['key_claims']:
            analysis['key_claims'].append({
                'claim': claim['text'],
                'paper': summary['title'],
                'confidence': claim['confidence']
            })
    
    # Find consensus (claims appearing in multiple papers)
    claim_counts = Counter([c['claim'] for c in analysis['key_claims']])
    analysis['consensus_points'] = [
        c for c, count in claim_counts.items() if count >= 3
    ]
    
    # Find debates (contradicting claims)
    analysis['debates'] = find_contradictions_in_claims(analysis['key_claims'])
    
    # Identify gaps
    analysis['gaps'] = identify_gaps(sources, topic)
    
    # Detect trends
    analysis['trends'] = detect_temporal_trends(analysis['papers_by_year'])
    
    return analysis
```

### Step 3: Generate Review Document

Create `wiki/synthesis/reviews/[topic]-review.md`:

```markdown
# Literature Review: {{topic}}

*Auto-generated: {{date}} | Sources: {{source_count}} papers | Last updated: {{updated}}*

## Executive Summary

{{executive_summary}}

## 1. Introduction

{{topic}} has emerged as a significant area of research in {{field}}. This review synthesizes {{source_count}} papers from the wiki knowledge base, spanning {{year_range}}.

### Scope
- **Primary focus**: {{primary_focus}}
- **Related concepts**: {{related_topics | join(", ")}}
- **Key researchers**: {{key_researchers | join(", ")}}

## 2. Historical Development

{{for year, papers in papers_by_year | sort(reverse=True)}}
### {{year}} ({{papers | length}} papers)
{{for paper in papers[:5]}}
- **[[{{paper.summary_path}}|{{paper.title}}]]** ({{paper.authors[0]}} et al.)
  {{paper.one_line_summary}}
{{endfor}}
{{if papers | length > 5}}
*+{{papers | length - 5}} more papers*
{{endif}}

{{endfor}}

## 3. Methodological Approaches

{{for approach, papers in papers_by_approach}}
### {{approach}}

**Papers**: {{papers | length}}
**Key representatives**: {{papers[:3] | map('title') | join(", ")}}

{{approach_description}}

#### Strengths
{{approach_strengths}}

#### Limitations
{{approach_limitations}}

{{endfor}}

## 4. Key Findings & Consensus

The following points represent consensus across multiple papers:

{{for point in consensus_points}}
1. **{{point.claim}}**
   - Supported by: {{point.supporting_papers | join(", ")}}
   - Confidence: {{point.aggregate_confidence}}
{{endfor}}

## 5. Open Debates

{{for debate in debates}}
### {{debate.topic}}

**Position A**: {{debate.position_a.claim}}
- Supported by: [[{{debate.position_a.paper}}]]
- Evidence: {{debate.position_a.evidence}}

**Position B**: {{debate.position_b.claim}}
- Supported by: [[{{debate.position_b.paper}}]]
- Evidence: {{debate.position_b.evidence}}

**Current status**: {{debate.status}}
{{endfor}}

## 6. Research Gaps

{{for gap in gaps}}
- **{{gap.description}}**
  - Evidence: {{gap.evidence}}
  - Potential directions: {{gap.suggestions}}
{{endfor}}

## 7. Trends & Future Directions

{{for trend in trends}}
### {{trend.name}}
{{trend.description}}

**Trajectory**: {{trend.trajectory}}
**Key papers driving this**: {{trend.key_papers | join(", ")}}
{{endfor}}

## 8. Relevance to My Research

### Direct connections to thesis
{{thesis_connections}}

### Potential applications
{{potential_applications}}

### Suggested next steps
{{for step in suggested_steps}}
- [ ] {{step}}
{{endfor}}

## References

{{for paper in all_papers | sort(attribute='year', reverse=True)}}
- [[{{paper.summary_path}}|{{paper.citation}}]]
{{endfor}}

---

## Metadata

```yaml
topic: {{topic}}
generated: {{date}}
source_count: {{source_count}}
year_range: {{min_year}}-{{max_year}}
related_concepts: {{related_topics}}
confidence: {{overall_confidence}}
status: auto-generated
```

---
*This review was auto-generated by `/monitor review`. Human review recommended before use in publications.*
```

### Step 4: Create Supporting Artifacts

```python
# Create comparison table
create_comparison_table(sources['summaries'], topic)

# Create timeline visualization (for Obsidian Canvas)
create_timeline_canvas(analysis['papers_by_year'], topic)

# Update concept page with review link
update_concept_page(topic, review_path)
```

---

## Part 4: /monitor gaps — Knowledge Gap Analysis

```python
def analyze_knowledge_gaps():
    gaps = []
    
    # 1. Concepts with few sources
    for concept in get_all_concepts():
        linked_papers = count_linked_papers(concept)
        if linked_papers < 3:
            gaps.append({
                'type': 'thin_coverage',
                'concept': concept['name'],
                'current_papers': linked_papers,
                'suggestion': f'Search for more papers on {concept["name"]}'
            })
    
    # 2. Old information without recent confirmation
    for summary in get_all_summaries():
        if summary['year'] < date.today().year - 3:
            if not has_recent_confirmation(summary):
                gaps.append({
                    'type': 'stale_info',
                    'paper': summary['title'],
                    'age': date.today().year - summary['year'],
                    'suggestion': 'Check for newer papers on this topic'
                })
    
    # 3. Unanswered questions
    for question in get_open_questions():
        if not has_potential_answers(question):
            gaps.append({
                'type': 'open_question',
                'question': question['text'],
                'age_days': question['age'],
                'suggestion': f'Search for papers addressing: {question["text"]}'
            })
    
    # 4. Missing connections
    orphan_concepts = find_orphan_concepts()
    for concept in orphan_concepts:
        gaps.append({
            'type': 'missing_connection',
            'concept': concept['name'],
            'suggestion': 'Link to related concepts or add supporting papers'
        })
    
    # 5. Thesis-specific gaps
    thesis_topics = extract_thesis_topics()
    for topic in thesis_topics:
        coverage = calculate_topic_coverage(topic)
        if coverage < 0.5:
            gaps.append({
                'type': 'thesis_gap',
                'topic': topic,
                'coverage': coverage,
                'suggestion': f'Critical for thesis: increase coverage of {topic}'
            })
    
    return gaps
```

Generate `wiki/monitoring/gap-analysis.md`:

```markdown
# Knowledge Gap Analysis

*Generated: {{date}}*

## 🔴 Critical Gaps (Thesis-Related)

{{for gap in thesis_gaps}}
### {{gap.topic}}
- **Coverage**: {{gap.coverage * 100}}%
- **Papers needed**: ~{{gap.papers_needed}}
- **Suggested search**: `{{gap.search_query}}`
{{endfor}}

## 🟡 Thin Coverage

{{for gap in thin_coverage}}
- **[[{{gap.concept}}]]**: Only {{gap.current_papers}} papers
{{endfor}}

## 🟢 Maintenance Items

### Stale Information
{{for gap in stale_info}}
- [[{{gap.paper}}]] ({{gap.age}} years old)
{{endfor}}

### Unanswered Questions
{{for gap in open_questions}}
- [[{{gap.question_path}}]]: {{gap.question | truncate(60)}}
{{endfor}}

## 📋 Recommended Actions

1. **This week**: Address {{critical_gaps | length}} critical gaps
2. **This month**: Review {{stale_info | length}} stale papers
3. **Ongoing**: Monitor {{thin_coverage | length}} thin concepts

---
*Run `/monitor gaps` to refresh*
```

---

## Part 5: Heartbeat Integration

Add to `HEARTBEAT.md`:

```markdown
## Daily: 6:00 AM — Quick Monitor Check
```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/monitor run --quick" \
       --auto-approve
```
Only check high-priority researchers and urgent citation alerts.
Feeds into 7:00 AM briefing.

## Weekly: Saturday 8:00 AM — Full Monitoring Cycle
```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/monitor run --full" \
       --auto-approve
```
Full scan of all researchers, citations, and topics.
Generate weekly monitoring digest.

## Weekly: Saturday 10:00 AM — Gap Analysis
```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/monitor gaps" \
       --auto-approve
```
Identify knowledge gaps for the coming week.

## Monthly: 1st at 9:00 AM — Literature Review Refresh
```bash
claude --model opus-4.6 \
       --directory /path/to/vault \
       --message "/monitor review [primary-thesis-topic]" \
       --auto-approve
```
Regenerate main literature review with latest papers.
```

---

## Part 6: OpenClaw Triggers

Add to routing config:

```yaml
triggers:
  # Monitor commands
  - pattern: "monitor( status)?"
    action: claude_code
    command: "/monitor status"
  
  - pattern: "(track|monitor|watch) (researcher |author )?(.+)"
    action: claude_code
    command: "/monitor add-researcher $3"
  
  - pattern: "(track|monitor) (citations to |paper )(.+)"
    action: claude_code
    command: "/monitor add-paper $3"
  
  - pattern: "(track|monitor) (topic |area )(.+)"
    action: claude_code
    command: "/monitor add-topic $3"
  
  - pattern: "run monitor(ing)?"
    action: claude_code
    command: "/monitor run"
  
  - pattern: "(generate |create )?(literature )?review (on |for |about )(.+)"
    action: claude_code
    command: "/monitor review $4"
  
  - pattern: "(find |show |what are )(the )?(gaps|missing)"
    action: claude_code
    command: "/monitor gaps"
```

---

## Obsidian Integration

### Daily Notes Integration

The monitoring system automatically updates your Daily Notes with relevant alerts and papers.

### Dataview Queries

Add to your Obsidian dashboard:

```dataview
TABLE researcher, level, last_checked
FROM "wiki/monitoring"
WHERE type = "researcher"
SORT level ASC, last_checked DESC
```

```dataview
LIST
FROM "wiki/monitoring/reports"
SORT file.name DESC
LIMIT 5
```

### Graph View

Monitoring creates connections between:
- Tracked researchers → their papers → your concepts
- Citation seeds → new citing papers → your summaries
- Topics → matching papers → related concepts

The graph view reveals how your monitoring network connects to your knowledge base.
