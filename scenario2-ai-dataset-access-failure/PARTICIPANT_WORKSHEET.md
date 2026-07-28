# Participant worksheet — Scenario 2

## Customer report

| Signal | Observation |
|---|---|
| Dataset access | Intermittent “file not found” |
| Browsing | Slow |
| Jobs | Some succeed; others fail |
| Storage utilization | Increasing |

## 1. Define the scope

- Exact failing path/key:
- Successful path/key:
- Client identities:
- View/export/share/bucket:
- First failure in UTC:
- Namespace publisher/lifecycle activity:

## 2. Ranked hypotheses

| Rank | Hypothesis | Evidence required | Result |
|---:|---|---|---|
| 1 |  |  |  |
| 2 |  |  |  |
| 3 |  |  |  |

## 3. Client comparison

| Phase | Client | Mapping | Successes | Not found | Browse P95 |
|---|---|---|---:|---:|---:|
| Baseline |  |  |  |  |  |
| Baseline |  |  |  |  |  |
| Incident |  |  |  |  |  |
| Incident |  |  |  |  |  |
| Recovered |  |  |  |  |  |
| Recovered |  |  |  |  |  |

## 4. Timeline

| UTC | Client read | Publisher operation | Capacity/metadata | Interpretation |
|---|---|---|---|---|
|  |  |  |  |  |
|  |  |  |  |  |
|  |  |  |  |  |

## 5. Classify each observation

| Observation | Direct cause | Contributor | Symptom | Unrelated |
|---|:---:|:---:|:---:|:---:|
| Non-atomic legacy update |  |  |  |  |
| Stale `v7` mapping |  |  |  |  |
| Increasing metadata/capacity |  |  |  |  |
| `FileNotFoundError` |  |  |  |  |

## 6. Root-cause statement

> During [UTC interval], [operation/configuration] caused [mechanism], affecting
> [clients/paths]. [Capacity observation] was [classification]. Recovery was
> proven by [same-operation retest].

## 7. Prevention

- Publishing change:
- Path/key contract:
- Monitoring and alerting:
- Capacity/metadata planning:
- Owner and target date:
