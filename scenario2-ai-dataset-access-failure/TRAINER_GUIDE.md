# Trainer guide

## Learning objective

Participants must distinguish:

- direct cause: non-atomic delete/recreate behavior on a stale legacy path;
- configuration contributor: one group still uses `v7` instead of `current`;
- performance contributor: metadata/capacity growth increases browsing work;
- symptom: intermittent `FileNotFoundError` and mixed job outcomes.

## Before class

```bash
cp config.env.example config.env
nano config.env
./scripts/00-install-tools.sh
./scripts/01-preflight.sh
```

For a VAST demonstration, use a new disposable directory on the mounted
training View.

## One-command demonstration

```bash
./run-demo.sh
```

## Evidence-wave delivery

### Wave 0 — customer report

- Intermittent “file not found”
- Slow dataset browsing
- Some jobs fail and others succeed
- Storage utilization is increasing

Ask participants for the exact failing path, identity, protocol and UTC window.
Do not reveal the path difference.

### Wave 1 — client evidence

Reveal:

```text
baseline-current.json
baseline-stale.json
incident-current.json
incident-stale.json
```

Expected observation: both clients are clean at baseline; only the stale
mapping has missing-name errors during the incident.

### Wave 2 — namespace timeline

Reveal `publisher-events.jsonl`. Participants should align delete/create
windows with the stale client's errors and distinguish atomic canonical updates
from non-atomic legacy updates.

### Wave 3 — capacity and browsing

Reveal:

```text
capacity-before.json
capacity-after.json
incident-*-iostat.txt
```

Capacity and entry count increase, and browsing becomes slower for both
clients. Ask why this does not explain client-specific missing names.

### Wave 4 — recovery proof

The recovery script:

1. confirms the publisher is stopped;
2. preserves the stale `v7` namespace;
3. remaps `v7` to the canonical `current` dataset;
4. repeats the same reads from both mappings.

Success requires zero missing-file errors for both representative clients.

## Debrief

Correct root-cause statement:

> A publishing job deleted and recreated the legacy shard non-atomically while
> one client group used the stale `v7` mapping. Requests during the missing-name
> window failed. Metadata growth raised browse latency but was a contributing
> condition, not the direct cause of client-specific failures.

Prevention discussion:

- publish immutable releases and switch one canonical pointer atomically;
- remove undocumented/stale path mappings;
- contract-test exact paths/keys with representative identities;
- alert on namespace-operation failures and metadata/capacity growth;
- maintain sufficient capacity and metadata headroom;
- preserve UTC-aligned client, protocol, publisher and storage evidence.
