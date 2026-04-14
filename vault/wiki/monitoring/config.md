# Literature Monitoring Configuration

Edit the tables below to customize what the monitoring system tracks.

---

## Tracked Researchers

Researchers whose new papers trigger alerts.

| Name | Institution | Alert Level | Notes |
|------|-------------|-------------|-------|
| [Researcher 1] | [Institution] | high | [Why: e.g., direct thesis competitor] |
| [Researcher 2] | [Institution] | high | [Why: e.g., key figure in my area] |
| [Researcher 3] | [Institution] | medium | [Why: e.g., related work] |
| [Researcher 4] | [Institution] | low | [Why: e.g., general interest] |

### Alert Levels
- **high**: Immediate notification + auto-ingest
- **medium**: Include in daily briefing
- **low**: Weekly summary only

---

## Tracked Papers (Citation Monitoring)

Papers whose new citations we monitor.

| Paper | ID | Why Important | Alert Level |
|-------|-----|---------------|-------------|
| [Seminal paper] | [arXiv/DOI] | [Foundation of my work] | medium |
| [Your key paper 1] | [arXiv/DOI] | [Reason] | high |
| [Your key paper 2] | [arXiv/DOI] | [Reason] | medium |

### ID Formats
- arXiv: `2301.12345` or `1706.03762`
- DOI: `10.1234/example.2023.001`
- Semantic Scholar: `abc123def456...` (paperId)

---

## Tracked Topics

Emerging areas or specific topics to monitor.

| Topic | Keywords | Alert Threshold | Alert Level |
|-------|----------|-----------------|-------------|
| [Your topic 1] | [keyword1, keyword2, keyword3] | 3 papers/week | high |
| [Your topic 2] | [keywords] | 5 papers/week | medium |
| [Your topic 3] | [keywords] | 5 papers/week | low |

---

## arXiv Categories

Which arXiv categories to scan in briefings.

```yaml
categories:
  - cs.LG    # Machine Learning
  - cs.CL    # Computation and Language
  - cs.AI    # Artificial Intelligence
  # Add your field's categories:
  # - cs.CV   # Computer Vision
  # - stat.ML # Statistics - Machine Learning
  # - q-bio.* # Quantitative Biology
```

---

## Relevance Scoring Weights

Customize how papers are scored for relevance during briefings.

```yaml
scoring:
  primary_keyword_match: 15
  secondary_keyword_match: 8
  tracked_researcher_paper: 25
  wiki_concept_match: 12
  answers_open_question: 20
  cites_tracked_paper: 18
  published_today: 10
  published_this_week: 5
  high_citation_velocity: 5
  major_venue: 8

thresholds:
  high_priority: 40
  medium_priority: 20
```

---

## Notification Preferences

```yaml
notifications:
  telegram: true
  slack: false

  urgent_alerts: always
  daily_briefing: always
  weekly_summary: always
  batch_progress: milestones_only
  maintenance: issues_only

  quiet_start: "22:00"
  quiet_end: "07:00"
  quiet_exceptions:
    - urgent_alerts
```

---

## Exclusions

Papers or sources to ignore.

```yaml
exclusions:
  authors: []
  negative_keywords:
    # - "survey"
    # - "review"
  venues: []
  paper_ids: []
```

---

## API Settings

```yaml
apis:
  arxiv:
    enabled: true
    rate_limit: "1 request per 3 seconds"
    max_results_per_query: 50

  semantic_scholar:
    enabled: true
    api_key: ""  # Optional — increases rate limit
    rate_limit: "100 requests per 5 minutes"

  pubmed:
    enabled: false
    email: ""  # Required for PubMed API
```

---

*Last updated: [DATE]*
*Next review: [DATE] (recommend monthly)*
