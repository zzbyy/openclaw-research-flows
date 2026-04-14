# Monitoring Configuration

This file defines what the monitoring system tracks.
Edit the tables below to customize your monitoring.

---

## Tracked Researchers

Researchers whose new papers trigger alerts.

| Name | Institution | Alert Level | Notes |
|------|-------------|-------------|-------|
| [Researcher 1] | [Institution] | 🔴 high | Direct thesis competitor |
| [Researcher 2] | [Institution] | 🔴 high | Key figure in my area |
| [Researcher 3] | [Institution] | 🟡 medium | Related work |
| [Researcher 4] | [Institution] | 🟢 low | General interest |

### Alert Levels
- **🔴 high**: Immediate notification + auto-ingest
- **🟡 medium**: Include in daily briefing
- **🟢 low**: Weekly summary only

### Adding Researchers
Via OpenClaw: `track researcher [Name]`
Via Claude Code: `/monitor add-researcher [Name]`

---

## Tracked Papers (Citation Monitoring)

Papers whose new citations we monitor.

| Paper | ID | Why Important | Alert Level |
|-------|-----|---------------|-------------|
| Attention Is All You Need | 1706.03762 | Foundation of my work | 🟡 medium |
| [Your key paper 1] | [arXiv/DOI] | [Reason] | 🔴 high |
| [Your key paper 2] | [arXiv/DOI] | [Reason] | 🟡 medium |
| [Seminal paper in field] | [ID] | [Reason] | 🟢 low |

### ID Formats
- arXiv: `2301.12345` or `1706.03762`
- DOI: `10.1234/example.2023.001`
- Semantic Scholar: `abc123def456...` (paperId)

### Adding Papers
Via OpenClaw: `track paper [title or ID]`
Via Claude Code: `/monitor add-paper [ID]`

---

## Tracked Topics

Emerging areas or specific topics to monitor.

| Topic | Keywords | Alert Threshold | Alert Level |
|-------|----------|-----------------|-------------|
| Efficient Attention | flash attention, linear attention, sparse attention | 3 papers/week | 🟡 medium |
| [Your topic 1] | [keyword1, keyword2, keyword3] | [N] papers/week | 🔴 high |
| [Your topic 2] | [keywords] | [N] papers/week | 🟡 medium |

### Keywords
- Comma-separated list
- Case-insensitive matching
- Use quotes for phrases: `"state space model"`

### Alert Threshold
- How many papers/week before alerting
- High threshold = only surge alerts
- Low threshold (1) = every paper alerts

### Adding Topics
Via OpenClaw: `track topic [name] with keywords [k1, k2, k3]`
Via Claude Code: `/monitor add-topic [name]`

---

## arXiv Categories

Which arXiv categories to scan for briefings.

```yaml
categories:
  - cs.LG    # Machine Learning
  - cs.CL    # Computation and Language
  - cs.AI    # Artificial Intelligence
  - cs.CV    # Computer Vision
  - stat.ML  # Statistics - Machine Learning
  # Add more as needed:
  # - cs.NE   # Neural and Evolutionary Computing
  # - cs.IR   # Information Retrieval
  # - q-bio.* # Quantitative Biology
```

---

## Notification Preferences

```yaml
notifications:
  # Channels
  telegram: true
  slack: false
  email: false
  
  # What to notify
  urgent_alerts: always
  daily_briefing: always
  weekly_summary: always
  batch_progress: milestones_only  # or: always, never
  maintenance: issues_only         # or: always, never
  
  # Quiet hours (no notifications)
  quiet_start: "22:00"
  quiet_end: "07:00"
  quiet_exceptions:
    - urgent_alerts  # Still notify for urgent even during quiet hours
```

---

## Relevance Scoring Weights

Customize how papers are scored for relevance.

```yaml
scoring:
  # Keyword matching
  primary_keyword_match: 15
  secondary_keyword_match: 8
  
  # Author/researcher matching
  tracked_researcher_paper: 25
  
  # Wiki connections
  wiki_concept_match: 12
  answers_open_question: 20
  
  # Citation tracking
  cites_tracked_paper: 18
  
  # Recency
  published_today: 10
  published_this_week: 5
  
  # External signals
  high_citation_velocity: 5
  major_venue: 8
  
  # Thresholds
  high_priority_threshold: 40
  medium_priority_threshold: 20
```

---

## Exclusions

Papers/sources to ignore.

```yaml
exclusions:
  # Authors to skip (e.g., known low-quality)
  authors:
    - "[Author to exclude]"
  
  # Keywords that indicate irrelevance
  negative_keywords:
    - "survey"        # Skip survey papers (optional)
    - "review"        # Skip review papers (optional)
    - "[irrelevant keyword]"
  
  # Venues to skip
  venues:
    - "[venue to exclude]"
  
  # Specific paper IDs to never alert on
  paper_ids:
    - "[ID to exclude]"
```

---

## Integration Settings

```yaml
apis:
  arxiv:
    enabled: true
    rate_limit: "1 request per 3 seconds"
    max_results_per_query: 50
  
  semantic_scholar:
    enabled: true
    api_key: ""  # Optional, increases rate limit
    rate_limit: "100 requests per 5 minutes"
  
  pubmed:
    enabled: false  # Enable for biomedical research
    email: ""  # Required for PubMed API
    rate_limit: "3 requests per second"
```

---

## Review Generation Settings

```yaml
reviews:
  # Auto-generate reviews for these topics monthly
  auto_generate:
    - "[Your primary thesis topic]"
    - "[Secondary topic]"
  
  # Review structure preferences
  include_sections:
    - executive_summary
    - historical_development
    - methodological_approaches
    - key_findings
    - open_debates
    - research_gaps
    - thesis_relevance
  
  # Minimum sources to generate review
  min_sources: 10
  
  # Max papers to include in detail
  max_detailed_papers: 30
```

---

## Maintenance

Last updated: YYYY-MM-DD
Next review: YYYY-MM-DD (recommend monthly)

### Checklist
- [ ] Researchers still relevant?
- [ ] Tracked papers still important?
- [ ] Topics need updating?
- [ ] Scoring weights working well?
- [ ] Too many/few alerts?
