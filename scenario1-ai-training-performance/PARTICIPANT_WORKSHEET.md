# Participant worksheet — Scenario 1

## Customer report

| Signal | Normal | Current |
|---|---:|---:|
| Training duration | 3 hours | 6 hours |
| GPU utilization | 95% | 45% |
| Dataset loading | Normal | Slow |
| Application code | — | No change |

## 1. Scope

- Affected jobs/clients:
- Start time in UTC:
- Dataset protocol and path:
- Is the issue reproducible?
- What remained normal?

## 2. Ranked hypotheses

| Rank | Hypothesis | Evidence required | Result |
|---:|---|---|---|
| 1 |  |  |  |
| 2 |  |  |  |
| 3 |  |  |  |

## 3. Evidence timeline

| UTC time | Layer | Observation | Supports/refutes |
|---|---|---|---|
|  | Application |  |  |
|  | Ubuntu client |  |  |
|  | Protocol/network |  |  |
|  | Storage/VMS |  |  |

## 4. Before and after

| Metric | Baseline | Degraded | Recovered |
|---|---:|---:|---:|
| Elapsed seconds |  |  |  |
| Dataset MiB/s |  |  |  |
| Simulated GPU utilization |  |  |  |
| Actual read seconds |  |  |  |
| Injected loader wait seconds |  |  |  |

## 5. Root-cause statement

Use this structure:

> During [UTC interval], [fault] caused [mechanism], resulting in [business
> impact]. We proved this by [evidence] and confirmed recovery by [same-workload
> retest].

## 6. Prevention

- Monitoring improvement:
- Workload-isolation or QoS improvement:
- Baseline/runbook improvement:
- Owner and due date:
