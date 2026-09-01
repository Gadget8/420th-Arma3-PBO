# Combined diagnostics and deployment-reconciliation proposal

Status: reconciliation branch implemented through `9f61e06`; combined diagnostic facility remains proposed, default-off by design, and not implemented
Date: 2026-08-30 (Asia/Bangkok)
Related investigations: [Cargo10 / HEMTT capacity](2026-08-30-cargo-mass.md) and [intermittent server freeze](2026-08-30-server-freeze.md)
Original proposal baseline: `a99001f666975fc7034328c66ac29fce291dca49` on `feat/deployable-air-defense-turrets`
Implemented reconciliation baseline: exact frozen-B checkpoint `5c1ffb3`; reviewed corrective HEAD `9f61e06` on `reconcile/deployment-20260901`
Frozen deployment evidence: `Apex_framework_420th_B.Altis.pbo`, SHA-256 `87A87D4A4482C146486033B358510D3551EEC91692390FE3D5F15E9F27256BCC`

## Decision summary

The two investigations should use one default-off, versioned diagnostic facility and be deployed in one immutable release. They need the same evidence: exact build identity, client/server/HC role and owner, locality, monotonic and server time, object correlation, scheduler/frame health, bounded logging, and production configuration identity.

The source-reconciliation prerequisite is now complete. The exact frozen B behavior is reconstructable at `5c1ffb3`, and reviewed post-live corrections extend through `9f61e06`; see the [as-built reconciliation record](2026-09-01-deployment-reconciliation.md). No shared cargo/freeze diagnostic core or diagnostic endpoint has been added. If approved, implement the facility only from a clean reviewed reconciliation commit (or a reviewed descendant), keep it default-off, and rerun the parity/security/build gates after adding it.

The achievable clean state is:

> The selected production mission PBO is reproducibly built from tagged release commit X, while every external runtime input is bound to that release by a checksummed private manifest/config commit Y.

It cannot mean that every server file literally equals this public mission repository: production `@Apex_cfg`, `server.cfg`, `basic.cfg`, HC launchers, mod inventories, and secret-bearing extDB configuration are separate inputs and are not present locally.

The diagnostic commits themselves should introduce no remediation behavior. Do not add a Cargo10 mass reassertion, authoritative cargo transaction, HC allocator behavior change, private-channel deduplication, friendly-handler rewrite, vehicle-monitor batching, AO-cleanup batching, or database schema change. Those become isolated follow-up canaries after the diagnostic signature identifies a path.

The original one-shot proposal combined reconciliation and diagnostics. Reconciliation is now a completed, separately reviewable commit series, so any diagnostic implementation must remain a later set of default-off commits. A production artifact based on `9f61e06` still differs from frozen B through documented corrections; R0/R1/R2 must therefore distinguish the exact-live checkpoint, corrected branch, diagnostics-off build, and diagnostics-on build. A single rollout cannot attribute a symptom change to instrumentation alone.

## Why the investigations fit together

Forcing at least one affected Cargo10 crate to stock mass `10000` instead of the intended `2500` on the client evaluating `canVehicleCargo` is a proven sufficient reproduction of the reported rejection. A production failure has not yet captured that state, so mass divergence remains the leading runtime hypothesis rather than the established incident cause. The missing evidence is whether that state occurs and, if so, its lifecycle transition: spawn/setup, JIP replication, ownership transfer, carry/pull/winch/placement, recreation, or load transaction.

The freeze matrix proved a different part of an ownership problem. HC transfer/recovery is serialized at approximately one completed group per HC every 6.5-6.9 seconds. Losing one HC returned 22 groups to the pending queue in one manager tick, and a large queue remained roughly 100 seconds later. This reproduces the reported two-to-five-minute gradual recovery timescale without reproducing the hard stall.

A reconciliation audit then found a possible trigger/recovery pairing in the served deployment family:

- both cached A and frozen B contain an unpublished Normal-AO cleanup path that was absent from the freshly fetched `origin/main` baseline, Jul 25/Jul 18, and the older historical trees; it is preserved in the exact-live R19 source checkpoint;
- if the AO does not configure a Defend phase, cleanup begins 30 seconds after Normal-AO deactivation; if the AO configures Defend, teardown starts that script, waits for it to finish, and then waits another 30 seconds;
- it then performs several explicitly unbudgeted scheduled traversals: appending nearby `allDead`, deleting captured objects and attachments, deleting empty groups, and globally unhiding captured terrain objects;
- it can touch objects associated with HC-owned groups;
- the code was present in the A-derived H2 harness, but no complete Normal-AO transition exercised it; it has no incident correlation yet.

That phase could be an unpublished cleanup fix, a high-entity-count trigger, or both. A burst could make server/scheduler/network work late, while HC ownership and reapply queues could account for gradual recovery. The same shared trace clock and ownership identifiers can test that model while also capturing crate mass divergence.

## Source and deployment state

### Historical pre-reconciliation Git topology

The table below records the 2026-08-30 investigation snapshot. It is not the current release topology. Fresh fetch and reconciliation later established `origin/main` at `149b7b91a1b7a32bf6068a0a30dc0b101faa84da`, the exact-live source checkpoint at `5c1ffb3`, and the reviewed mission-code tip at `9f61e06`.

| Ref | Commit | State |
|---|---|---|
| Local HEAD at snapshot / fork feature | `a99001f` | One commit above the then-current `origin/main`; adds deployable air-defense/Cargo20 work |
| Canonical `origin/main` | `933ce8d` | Does not contain the feature commit or server-runner fix branch |
| `origin/fix-donator-skins-and-defend-tweaks` | `41a47d8` | Separate one-commit branch above `933ce8d`; includes DB/PMC/donator/Defend changes |

The refs had not been fetched at the time of this historical snapshot. They were fetched and pinned for the 2026-09-01 reconciliation. A future release still needs a reviewed canonical merge/tag rather than relying on the old feature refs below.

### Historical cached A versus the then-current feature tip

This comparison is retained as historical evidence only. It was superseded for mission-source identity by the freshly served/client-downloaded frozen B PBO used in the 2026-09-01 reconciliation. That download establishes the mission payload served to a joining client; it does not by itself prove the server-disk file, startup selection, or absence of loose runtime overlays.

| Measure | Result |
|---|---:|
| Repository mission files | 1,261 |
| Extracted cached-A files | 1,258 |
| Repository-only paths | 10 |
| Deployment-only paths | 7 |
| Common files differing only by CRLF/LF | 736 |
| Common files with substantive differences after EOL normalization | 40 |

Deployment-only paths include three functions (`fn_clientSetTeamFeature.sqf`, `fn_serverSetTeamFeature.sqf`, and `fn_enemyUAVDiagnostics.sqf`) plus four commissary textures. Repository-only paths include `fn_aoDefend.sqf.old`, a readme, and several flag/insignia images. A blind folder pack is therefore unsafe, and a blind extraction-over-repository copy would introduce case/EOL noise and discard intentional Git work.

Four deployed files exactly match the unmerged `41a47d8` branch after normalization: `fn_dbQuery.sqf`, `fn_dbWhitelistInit.sqf`, `pmc.hpp`, and `fn_serverGetDonatorSkins.sqf`. Four other files touched by that branch contain further deployed edits. The deployment matches `origin/main`, not the current feature commit, for several air-defense files; other files match neither branch.

The direct cargo check/load/event functions matched between cached A and the then-current HEAD after EOL normalization. Three lifecycle files differed in that historical comparison:

- `fn_vSetupContainer.sqf` adds Cargo20 setup in HEAD;
- `fn_spawnMenuServerSpawn.sqf` adds Cargo20 drag/carry classes in HEAD;
- `fn_deployAssetPreset.sqf` contains a substantial preset-6 rewrite that also affects the existing Cargo10 Defender.

This historical comparison is superseded for release identity by the frozen-B reconciliation. The later cargo follow-up also proved that all eight in-scope purpose-built presets (6, 7, 12–17) are already mass `2500` in `origin/main`, frozen B, and `9f61e06`; generic Cargo20 `5000` is not an active purpose-built preset. No cargo rebalance commit is proposed. Runtime diagnostics remain useful only for capturing a future state/locality transition.

### Remaining production inputs

The frozen served/client-downloaded B PBO and its hashes are now retained. The following are still required before a production cutover can claim complete operational parity:

- a direct server-filesystem copy of the selected PBO, confirming the frozen-B SHA-256, plus the resolved mission selection and any loose mission-source overlays;
- complete production `@Apex_cfg`, especially `parameters.sqf`, with secrets handled privately;
- `server.cfg`, `basic.cfg`, selected mission template, and the resolved `MPMissions` directory;
- dedicated-server and every-HC command line, profile, PID/role map, and mod/DLC inventory;
- current server and HC RPTs;
- deployed extDB configuration/SQL version and DB-readiness procedure;
- the server runners' original source for deployed-only edits, if it still exists;
- the current manual build, upload, restart, watchdog, and rollback procedure.

## Target release shape

Use one uniquely named immutable mission artifact, for example:

`Apex_framework_420th_20260830r1.Altis.pbo`

Do not reuse `A`, `B`, or an existing mission filename. A unique name makes server selection, client cache, incident attribution, and rollback unambiguous.

The release consists of four bound artifacts:

1. a Git tag/release commit reachable from freshly fetched `origin/main`;
2. the exact mission PBO built only from that commit;
3. an admin-only external configuration bundle or private config-repository commit;
4. a sidecar release manifest binding source, artifact, configuration, tools, game, mods, server, and HCs.

The build deterministically generates a staged `QS_buildInfo.sqf` after exporting the tagged tree. Its ID contains the release/tag, Git commit/tree, source-inventory identity, diagnostic schema, and `dirty=false`. Define source identity as the tagged mission-tree OID or a normalized inventory that explicitly excludes this generated file; then include the generated file in the staged/PBO inventory and verify it after extraction. This avoids asking a Git commit to contain its own hash. The final PBO SHA-256 also cannot be embedded into the same PBO without self-reference; it belongs in the sidecar. Every server/HC `BOOT` line logs the generated embedded ID and externally supplied manifest ID, and deployment verification compares them with the sidecar.

## Shared diagnostic contract

### Configuration

Source-safe defaults in the sanitized configuration template:

```sqf
QS_missionConfig_diagEnabled = false;
QS_missionConfig_diagDomains = [];
QS_missionConfig_diagLevel = 0;
QS_missionConfig_diagReleaseId = "";
QS_missionConfig_diagIncidentId = "";
QS_missionConfig_diagSampleInterval = 5;
QS_missionConfig_diagCargoMode = 0;
QS_missionConfig_diagCargoSuccessSample = 20;
```

The reviewed canary override in production `@Apex_cfg\parameters.sqf` must deliberately enable the probes and bind the exact release:

```sqf
QS_missionConfig_diagEnabled = true;
QS_missionConfig_diagDomains = ["freeze","cargo"];
QS_missionConfig_diagLevel = 1;
QS_missionConfig_diagReleaseId = "REPLACE_WITH_EXACT_RELEASE_ID";
QS_missionConfig_diagIncidentId = "";
QS_missionConfig_diagSampleInterval = 5;
QS_missionConfig_diagCargoMode = 1;
QS_missionConfig_diagCargoSuccessSample = 20;
```

`diagCargoMode=0` is off, `1` keeps bounded lifecycle/ownership state while making every anomaly/failure eligible for priority output and emitting a deterministic success sample, and `2` is full affected lifecycle for a short lab session. Hard output caps still apply: suppressed anomaly/failure totals must be emitted later. Define `diagCargoSuccessSample` as a denominator: `1` means every affected success and `20` means one in twenty, selected from the attempt correlation rather than global randomness.

The server validates these values, checks that the configured release ID matches the embedded build, and publishes only a sanitized runtime configuration to clients/HCs using one replaceable JIP activation ID. Missing, malformed, or mismatched configuration fails closed. Domain toggles remain independent even though both implementations ship in one PBO.

### Envelope

Every local RPT record starts with one parser-stable prefix and schema:

```text
T420_DIAG|v=1|build=...|session=...|incident=...|domain=freeze|event=...|role=server|owner=2|seq=...|dtt=...|stime=...|utc=...|...
```

Common fields:

- embedded build/release/schema and server-generated session ID;
- optional operator incident ID;
- domain/event/machine role/client owner and per-machine sequence;
- local `diag_tickTime`, `serverTime`, frame number, and UTC wall time;
- JIP/connection epoch where relevant;
- stable, bounded correlations based on server session, counters, owner IDs, and `netId` values;
- emitter elapsed time, line bytes, and suppression counters.

Do not include player names, raw Steam UIDs, arbitrary object variables, full loadouts, unbounded object lists, or arbitrary client-supplied strings.

### Trust boundaries

- A common `fn_diagEmit` writes fixed-shape data only to the local RPT.
- There is no generic client-to-server logger.
- The dedicated server generates the session ID and reconstructs authoritative build/release identity. Client echoes are compared for mismatch evidence but never trusted as authority.
- Cargo uses a dedicated, fixed-shape `serverDiagCargoReport` endpoint with `allowedTargets=2`.
- HC heartbeat uses a separate fixed-shape server endpoint and validates the sender against authoritative HC logic/owner state.
- The reconciled mission has active `mode = 1` CfgRemoteExec policy. A static compatibility audit found 44 literal function endpoints (15 absent from the function whitelist) and 26 literal native-command endpoints (23 absent from the command whitelist). Most omissions are server-origin and therefore exempt, but definite staff-channel, HC-command, surrender-face, target/JIP, and drone-lock regressions were corrected through `9f61e06`. Diagnostic endpoints still require narrow `allowedTargets`, no JIP retention, and independent sender validation; rerun the audit after adding them.
- Every ingress independently validates `remoteExecutedOwner`, mode, array length, types/enums, string lengths, release/session, connection epoch, bounded seen/replay window, per-attempt phase deduplication, and token bucket. Do not reject merely because CHECK and COMMIT reports arrive out of sequence.
- Validation is event-specific. A pre-load report cannot require an existing cargo relationship: require non-null objects, one exact affected child class, a parent eligible for native ViV or an explicitly allowlisted mission custom-attach fallback, an authoritative player sender close to both objects (suggested maximum 25 m), reasonable child-parent proximity, and a valid attempt. An owner-local mass acknowledgement requires a single-use, short-TTL token bound to session, asset/generation, owner at dispatch, operation, and expected mass; validate the sender against dispatch ownership, then record the possibly changed receipt-time owner separately. Engine cargo events are reconstructed server-side.
- Server logs reconstruct authoritative identities and object snapshots rather than trusting client descriptions.
- Diagnostic remote execution is never JIP-persistent; only sanitized activation/config state uses a replaceable JIP ID.

## Freeze instrumentation

Freeze periodic telemetry runs only on the dedicated server and HCs. Normal clients participate only in event-driven Cargo10 tracing.

| Event | Primary hook | Essential evidence |
|---|---|---|
| `BOOT` | Diagnostic init on server/each HC | Build/session, game/mission version, role/owner, `baseLayout`, all Cargo10 switches, carrier/destroyer flags, private-channel state, configured/effective HC caps, selected Normal-AO-cleanup capability/disposition, config/mod fingerprints |
| `HEALTH_SAMPLE` | Independent scheduled loop every five seconds | Scheduled lateness, FPS/min FPS, max frame gap, cached player/unit/group/vehicle/monitor counts, authoritative HC owners, logic owners, heartbeat ages, cached HC queue vector |
| `FRAME_GAP` | Minimal `EachFrame` handler | Gap and frame; 250 ms warning, one-second critical, cooldown/suppressed count |
| `SCHEDULED_GAP` | Five-second heartbeat | Expected/actual interval and lateness; 250 ms warning, one-second critical, cooldown/suppressed count |
| `FREEZE_STATE` | Derived separately for frame and scheduled channels | Enter on a one-second critical gap/lateness; channel, trigger/max gap, start/end, duration, suppressed count; recover after 15 seconds without another critical frame gap and three consecutive scheduled samples below 250 ms lateness |
| `HC_HEARTBEAT` | Each HC to server | Sequence, local FPS/frame/scheduled health, server receipt age |
| `HC_CONNECTION` | Connect/disconnect/case 98 | Manager owner set, logic owners, case-98 group/variable/time counts, observational heartbeat/readiness state; no behavioral gate |
| `HC_CYCLE` / `HC_QUEUE` | Existing `fn_AI.sqf` HC block | Ex-sleep execution time, scans, starts/advances/failures/return bursts, stage vectors, per-owner loads, oldest/percentile age |
| `HC_TRANSITION` / `HC_REAPPLY` | Existing stage/locality paths | Stable group correlation, stage/owner/reason/age/unit count, active reapply workers, completion/failure |
| `VMON_PASS` | Existing `fn_core.sqf` monitor pass | Registry/visited/simple/real/dynamic counts, expensive-branch counters, creates/deletes/respawns/owner changes, scheduled duration |
| `NORMAL_AO_CLEANUP` | Frozen-B/current R19 cleanup path | AO-deactivation/Defend/delay branch timestamps, initial/deferred/`allDead` candidates and scan time, owner/HC-stage distribution, separately timed attachment/object/group/unhide counts, total elapsed |
| `PRIVATE_CHANNEL_SYNC` | Reconcile/publish path | Mode/source, feature state, players/channels/members/lookups, recipients/items/elapsed, duplicate respawn full-sync correlation |
| `FRIENDLY_AI_SUMMARY` | Friendly protection paths | Per-role entity rates, handler add/reuse/remove, validation worker counts/concurrency/elapsed |
| `PHASE` | Objective/cleanup/DB/intel hot paths | Phase, input/output count, elapsed time, slow-threshold reason |

Level 1 aggregates HC transitions and logs individual records only for failures, return bursts, owner churn, or slow stage age. Level 2 may log individual transitions/vehicle samples only during a short controlled test.

Do not add new `allPlayers`, `allGroups`, `allUnits`, `allDead`, or monitor traversals to the five-second sampler. Increment counters inside existing work and emit aggregates afterward.

## Cargo10 instrumentation

Trace exactly the eight Cargo10 classes whose current setup assigns intended mass `2500`: blue Defender, cyan Radar, grey FOB, military-green COP, light-green Patrol Base, sand Platform, white Mobile Respawn, and yellow Terrain. Record any parent carrier, marking `Truck_01_flatbed_base_F` as the target case.

### Correlation and snapshots

The primary transaction correlation is a server-authorized attempt ID containing server session + client connection epoch + attempt counter. Pair keys are secondary. The server assigns every traced crate a provisional live-object/asset ID immediately at creation, then binds it to `[session, netId, generation]` once a valid network ID exists. It tracks expected mass, provenance, current owner, and recreation lineage. Empty/invalid/`0:0` network IDs are never map keys; deletion and ID reuse advance generation, and a bounded tombstone retains the old identity long enough to classify late events.

Engine events that cannot carry an attempt ID use a bounded per-pair deque. If more than one attempt is plausible, emit `link=ambiguous` with candidate count and do not manufacture a causal link.

Child snapshots are bounded to class/net ID, owner/local/alive, `getMass`/expected mass, provenance/generation, position/direction, vehicle-cargo/attachment/rope/hidden/simulation state, deploy preset, cargo-parent state, and a server-generated presence/session alias for spawn-menu provenance. Never log raw `QS_spawnMenu_spawnedBy` content.

Parent snapshots include class/net ID, owner/local state, `getMass`, position/direction/vector state, configured carrier `maxLoadMass`, and at most eight native cargo/attached entries with net ID, class, owner, and mass. Always include total-entry and truncated flags when the list is capped.

### Events

| Event group | Checkpoint |
|---|---|
| `CARGO_CREATE`, `CARGO_SETUP_BEGIN`, `CARGO_MASS_APPLY` | Spawn/recreate and before/after intended mass application. Because `setMass` returns no Boolean, the owner-local acknowledgement records token, command path/issued state, observed owner/locality, before/after `getMass`, and `after == expected` |
| `CARGO_RECREATE` | Old/new asset and lineage, preset/path/reason |
| `CARGO_OWNER_REQUEST`, `CARGO_LOCALITY_OBS` | Carry, placement, pull, and winch ownership request/result; temporary `Local` observation only while traced |
| `CARGO_LOAD_CHECK` | The one native `canVehicleCargo` result used by the client behavior path, wrapper/custom fallback result, client check-time snapshot, bypass state |
| `CARGO_LOAD_COMMIT` | Native `setVehicleCargo` return, wrapper final return, custom-fallback branch, resulting attachment/cargo relation, and check-to-commit elapsed time |
| `CARGO_LOADED`, `CARGO_UNLOADED` | Engine event/finish state and parent-child correlation; record that a custom attachment fallback may legitimately produce no `CargoLoaded` event |
| `CARGO_DIVERGENCE`, `CARGO_ANOMALY_PROBE` | Phase-aware stable-state disagreement, mass not `2500` only after the matching setup/apply completion, `[false,true]`, check/commit race, or owner change; bounded follow-ups at 0.1, 1, and 5 seconds |

The client report carries its check-time local `diag_tickTime` and replicated `serverTime` snapshot. At receipt, the server records separate receipt-time state and an approximate observation age derived from `serverTime`. Cross-process `diag_tickTime` origins are not comparable, and the age is not one-way network delay. A mismatch is a divergence only if no intervening setup, commit, mass-apply, or ownership phase is known. If enabled, a distinctly labelled server-local diagnostic `canVehicleCargo` probe is evidence about server state at receipt, not the client's decision at check time.

Do not call native `canVehicleCargo` twice on the actual client behavior path merely for diagnostics. Extend the existing wrapper with optional diagnostic context so that one real result and any custom fallback are reported.

### Cargo hook surface

The reconciled implementation should review these exact areas:

- `fn_clientInteractLoadCargo.sqf`, `fn_canVehicleCargo.sqf`, and `fn_setVehicleCargo.sqf` around check/commit;
- `fn_eventCargoLoaded.sqf`, `fn_eventCargoUnloaded.sqf`, and terminal unload finish functions;
- `fn_vSetupContainer.sqf` and owner-local execution of remote `setMass`;
- spawn menu, purpose-built deploy-preset recreation, and monitored respawn provenance;
- carry case 66, unload placement/detach/owner request, simple pull, and simple winch ownership paths.

Avoid a persistent `Local` handler on every crate/client/HC. Use a temporary handler only around one traced request and remove it on fire or a short timeout. Persistent per-machine entity-handler fanout is already a freeze hypothesis.

Mode 1 tracks setup/provenance/current-owner state for every asset seen by an instrumented path and records every instrumented owner request or observed transition; sampling applies only to routine successful attempt output. Lazily register pre-existing/bypassed assets at first load with `provenance=unknown`, and emit a coverage-gap record when an ownership change is inferred but no hooked transition explains it. Implement explicit hard caps and expiry for live assets, attempts, pair deques, and tombstones (suggested starting bounds: 1,024 live assets, 2,048 recent attempts, 15-minute tombstones), emit eviction/suppression totals, and validate those sizes under the stress matrix.

At every mission-owned traced `setMass` hook, record whether execution is remote, `remoteExecutedOwner` where available, and whether the single-use token is expected. Count unexpected or client-origin executions as security anomalies without changing mission behavior in this observation release. The reconciled mission already has active `mode = 1` CfgRemoteExec policy. New diagnostic endpoints must be narrow, non-JIP, and independently authenticate their senders; the broad dynamic `QS_fnc_remoteExec`/`QS_fnc_remoteExecCmd` dispatchers remain a residual attribution and design risk even under the active policy.

## Performance and safety budget

Disabled state requirements:

- no diagnostic loops, event handlers, remote traffic, or RPT lines;
- only cold boolean guards at touched existing paths;
- identical mission behavior and native call count.

Enabled level-1 targets:

| Area | Budget |
|---|---|
| `EachFrame` gap detector | Scalar operations only; average self-time below 0.05 ms |
| Five-second health sample | Median below 2 ms, p99 below 5 ms, hard ceiling 10 ms |
| HC-cycle instrumentation | Below 1 ms incremental and below 5% matched-cycle regression |
| VMON instrumentation | Pass start/end timer and scalar counters only; no per-entry timer |
| Freeze steady output | Independently below both 20 lines/minute and 0.5 MB/hour per server/HC process; measured line bytes determine the lower effective rate |
| Combined emitted-event burst ceiling | 100 RPT lines/minute per mission session across server plus the supported maximum four HCs, enforced through fixed local quotas |
| HC heartbeat | Below 250 bytes/second per HC |
| Combined steady diagnostic traffic | Below 2 KB/second |
| Cargo ingress | At most 30 reports/minute per sender and 240 accepted reports/minute globally |
| Cargo RPT output | Shares the 100-lines/minute global emitted ceiling; failures/divergences prioritized and successes aggregate/sample |

Reserve an independent priority budget for `FRAME_GAP`, `SCHEDULED_GAP`, and incident-boundary records so cargo activity can never suppress freeze evidence. Never build an unbounded in-memory log queue during a freeze.

For level-1 production, the server hard cap is 60 lines/minute: 20 reserved for frame/scheduled/`FREEZE_STATE` critical records, 20 for other freeze aggregates, and 20 for cargo. Each of at most four HCs has a separate 10-lines/minute cap, and normal clients send validated cargo reports but do not write production diagnostic RPT lines. Buckets do not borrow in level 1, so the supported topology cannot exceed 100 session lines/minute. Refuse enabled production configuration with more than four HCs until quotas are reviewed. The 250 ms/one-second values are warning/critical lateness severities; only the one-second severity enters `FREEZE_STATE`.

Matched disabled/enabled cells must keep vehicle-monitor duration and HC transfer interval within 5%, add no 250 ms frame gap, and keep scheduled-heartbeat p95 regression below 250 ms.

## Reconciliation and commit procedure

### 1. Freeze the real production baseline

Before source edits or maintenance, record the live server/HC working directories and complete startup arguments, `-filePatching` state, junctions/symlinks, loose mission folders, and every effective source/config overlay. The 2026-09-01 audit froze the PBO freshly served to a joining client; for a complete operational baseline, confirm that hash against the selected server-disk PBO and archive it with restrictive ACLs plus those overlays and all external inputs listed above. The effective operational baseline is the selected PBO **plus** every active overlay; a client-downloaded PBO alone cannot prove that no loose overlay changes runtime behavior. Hash every artifact and create a `rollback-before` manifest. A read-only file attribute is only an accidental-write guard, not immutability. Preserve current RPTs before log rotation or restart.

Disable automatic watchdog/restart behavior only during the controlled maintenance window, recording who disabled it and how it will be restored.

### 2. Work from a clean, freshly fetched canonical branch

Do not switch the current dirty worktree, which contains these investigation documents. Use a fresh clone or dedicated worktree after reviewing the fetched refs. The release branch should start from the agreed canonical `origin/main`, not the current fork-only feature branch.

Illustrative flow, with release-time hashes substituted:

```powershell
git fetch --all --prune
$CleanPath = 'C:\ArmaBuild\420th-combined-diag-20260830'
git worktree add -b release/combined-diag-20260830 -- $CleanPath origin/main
```

Do not use `git reset --hard`, overwrite the mission tree, or resolve conflicts with blanket "ours"/"theirs."

### 3. Extract and classify the exact live PBO and overlays

Use a pinned BankRev build to record the PBO archive list, properties, content hash, and extraction. Inventory active loose mission-source overlays separately and resolve their effective precedence. Compare exact relative paths and case first, fail on case-fold collisions, and only then use a case-insensitive view as a secondary classification. Normalize CRLF/LF only to identify EOL-only differences. Preserve original bytes in the archive. Secret-bearing external configuration stays in the private manifest/config repository rather than being copied into public mission Git.

Produce a reviewed disposition table for every difference:

- `KEEP_DEPLOYED`: unpublished operational fix/feature to reconstruct in Git;
- `KEEP_REPO`: intentional pending source work;
- `MERGE`: both sides changed and semantics must be combined;
- `REMOVE`: backup/readme/stale asset intentionally excluded;
- `EOL_ONLY`: payload differs only by reviewed text line endings;
- `CASE_ONLY`: path spelling/case differs and one canonical exact path is selected.

The historical cached-A audit's 40 substantive common-file differences, 10 repo-only paths, and seven deployment-only paths were the starting checklist. The completed frozen-B 69-path audit supersedes them for mission-source reconciliation; a future direct server-disk/overlay confirmation still must compare the effective operational inputs rather than assume the PBO alone is complete.

### 4. Reconciled production behavior — implemented

This prerequisite is complete without the proposed shared diagnostics. `5c1ffb3` is the exact frozen-B checkpoint; `9f61e06` adds the documented post-live corrections. The completed review explicitly dispositioned:

- deployed HC group/agent variable whitelists and HC exclusion state;
- current security/remote-exec validation;
- DB readiness/protocol and deployed DB/PMC/donator changes;
- team-feature and enemy-UAV functions/registrations;
- UAV spawn gates and deferred-object behavior;
- the frozen-B Normal-AO cleanup, reconstructed as exact-live R19 and explicitly flagged as an unbudgeted freeze-risk path requiring instrumentation/load review before production approval;
- deployed mission/editor and asset differences.

Where server-runner source existed, it was reconciled against the frozen PBO rather than accepted blindly. The full 69-path classification and final comparator are preserved in the as-built reconciliation record.

The post-sync comparator at `5c1ffb3` left only the documented whitespace-only `fn_curatorFunctions.sqf`, editor-noise `mission.sqm`, and source-only commissary README exceptions. The final `9f61e06` comparator maps every additional material difference to a documented correction. Any future diagnostic branch must repeat this comparison and bind active mission-source overlays/private inputs in the release manifest.

### 5. Keep unrelated pending Git work separate

The runner-fix work represented by `41a47d8` reached `origin/main` through the refreshed baseline. The separate air-defense tip `a99001f` was not frozen B and is not part of the reconciliation branch. Rebase and review it in a separate feature PR; do not fold it into the diagnostic commits. If later selected, its preset-6 changes require the updated eight-preset Cargo10 regression matrix.

Suggested reviewable commit sequence:

1. completed exact frozen-B served-payload source reconstruction through `5c1ffb3`;
2. completed reviewed corrections through `9f61e06`;
3. build/release/manifest machinery;
4. proposed shared diagnostics core;
5. proposed cargo diagnostic hooks;
6. proposed freeze diagnostic hooks;
7. config templates, parser, tests, and runbook;
8. unrelated feature branches in later independent PRs.

No database schema or bug-remediation behavior belongs in these diagnostic commits.

Before one production artifact is approved, preserve causal comparison in staging:

| Gate | Artifact | Required comparison |
|---|---|---|
| R0 | Exact-live checkpoint `5c1ffb3` | Extracted payload and approved nonsemantic/source-only dispositions match frozen B |
| R1 | Corrected reconciliation branch `9f61e06`, diagnostics absent | Cargo, AO, HC, DB, channel, RemoteExec, drone, and mission-start matrices identify the documented post-live effects |
| R2 | Final R1 + proposed diagnostic commits | Diagnostics-off matches R1; diagnostics-on differs only in bounded telemetry and stays within budgets |

These gates reduce the confound but cannot make the single production rollout a diagnostics-only causal experiment.

### 6. Merge before building production

Open and review a PR, merge the final release into canonical `origin/main`, then tag that exact clean commit. Production is built only from the tag/commit, never from an uncommitted working tree or an unmerged feature branch.

## Reproducible build and verification

The repository currently has no build/deploy automation, `.gitignore`, `.gitattributes`, workflow, or release metadata. Add reviewed `.gitattributes` rules for mission text/binary files and `.gitignore` rules for build products before a production release so checkout EOL behavior and accidental PBO staging are explicit. A strong FileBank verification script exists locally in the sibling air-defense project; port its mechanics rather than its hardcoded paths and six-file allowlist.

The local official tools used during this audit include:

| Tool | Local identity |
|---|---|
| AddonBuilder | `1.5.152.926`, SHA-256 `FE7426CDE77B2857C62AFE391C712852CE81530DEF652D6B4CD1268B4B6E4671` |
| FileBank | SHA-256 `AD382602848C6AF56385C5E80E8B6CC0D9F13B6C3FB69A000DFE7B9805A28ECB` |
| BankRev | `1.0.0.2`, SHA-256 `80B323473BD2C9306607430DDEEF224AED9EC341376E3ED28377854801048963` |
| CfgConvert | `1.2.0.1`, SHA-256 `B160E83133A8C920AA546BF31BCDD3CC0EC6973950D52203758AA9D613CA1B90` |

Re-hash installed tools on the release machine and either match the lock or intentionally update it in review.

Required build behavior:

1. refuse a dirty source tree;
2. export only `Apex_framework.terrain` from the tagged commit into a clean stage directory;
3. rename the staged mission folder to the immutable `<mission>.<world>` release name;
4. derive the source identity from the tagged mission-tree OID/inventory, generate `QS_buildInfo.sqf` solely from pinned release inputs, and add it to the staged inventory;
5. use a versioned package manifest to exclude source-only `media/commissary/README.txt`, then fail on any other `.old`, `.bak`, `.tmp`, nested PBO, docs, secrets, or unapproved extensions; a test build made from an unfiltered Git archive can verify packing mechanics but is not payload-equivalent to frozen B if it contains that README;
6. set a deterministic file order and all staged timestamps, including the generated file, to a fixed commit/source epoch;
7. run `CfgConvert -test` against `mission.sqm` and `description.ext`;
8. pack with the pinned direct FileBank flow already exercised by the sibling project:

   ```powershell
   Push-Location $StageParent
   try {
       & $FileBank -dst $RawOutput $MissionFolderName
       if ($LASTEXITCODE -ne 0) { throw "FileBank failed: $LASTEXITCODE" }
   }
   finally {
       Pop-Location
   }
   ```

9. remove/verify unwanted FileBank prefix properties as the sibling script does;
10. use BankRev to require the expected empty property set, archive file list, and content hash;
11. extract the candidate and compare every relative path and payload hash, including generated build info, to staged source;
12. build in two independent stage directories and then in a second clean checkout/job; require identical PBO SHA-256 before claiming reproducibility;
13. if pinned FileBank cannot be deterministic after fixed timestamps/order, retain exact payload verification and select/document a deterministic packer in a separate reviewed tooling change;
14. emit the signed/checksummed sidecar manifest, archive it under restrictive ACLs, and also mark the release copy read-only as an accidental-write guard.

The 2026-09-01 filtered production-form build validates this packaging path for mission-code commit `9f61e0666edde5544c50951bab996b6bde68cb77` and tree `33ea816ae64ffc907af617f0a45eb40f470f4f19`. It excludes exactly source-only `media/commissary/README.txt`, contains 1,267 verified files, has no PBO header properties, passes CfgConvert and complete BankRev list/extract/payload-hash comparison, and reproduced byte-identically in a second independent FileBank stage. Its PBO SHA-256 is `FBD92C1A6FC5D892459B6F0AA9028E774C80B2C37F3C24D927898FD20C3DC084`; BankRev content SHA-1 is `096890AC180E5191D0F4288F53D30CB57FA304FC`; evidence is retained under `prod-pbo-9f61e06-01`. This qualifies the pinned mission package, not the still-missing production external-config/overlay/HC inputs or multiplayer behavior.

Addon Builder was inventoried but not exercised for this mission, so it is not interchangeable with the qualified FileBank command above without its own validation. [Bohemia's official Addon Builder documentation](https://community.bohemia.net/wiki/Addon_Builder) notes case-sensitive options and a non-binarizing `-packonly` mode. The official [Mission Export documentation](https://community.bohemia.net/wiki/Mission_Export) places multiplayer PBOs in `MPMissions` and uses the `<mission>.<world>.pbo` naming form. Record each installed tool's `-help` output in the build log.

The manifest binds at minimum:

- release/tag/commit/tree/dirty=false and normalized source inventory hash;
- diagnostic schema, embedded build ID, enabled-domain configuration contract;
- PBO filename, bytes, SHA-256, and BankRev content hash;
- packer executable hashes/options and build epoch;
- exact production `@Apex_cfg`, `server.cfg`, and `basic.cfg` hashes;
- Arma build and server/every-HC command-line/mod/DLC fingerprints;
- prior rollback PBO/config names and hashes.

Secret-bearing configuration remains in an admin-only manifest/private config repository. Commit only sanitized templates or non-secret hashes here.

## Validation matrix

### Disabled diagnostics

| Cell | Requirement |
|---|---|
| D0/B0 | Master/domains off: zero `T420_DIAG` loops, event handlers, network messages, or lines |
| D1/L1 | Vehicle-monitor pass and scheduled/frame health match reconciled baseline |
| D2/H2 | HC connect/drop/reconnect throughput and queue timing match baseline |
| D3/Cargo | Existing successful and failing Cargo10 results unchanged; native calls occur once |

### Enabled freeze cells

- Repeat B0, L1, H0, and H2 at level 1 and enforce the performance budget.
- Exercise HC connect, one-HC loss, reconnect, queue drain, and case 98.
- Exercise private-channel respawn duplication and friendly entity-creation waves.
- Because the exact-live and corrected R1 source contains the frozen-B cleanup, complete one Normal AO without configured Defend (30-second delay), one with configured Defend (spawn/wait plus 30 seconds), and the next AO transition; time each cleanup traversal separately. Any later proposal to remove or budget that behavior is a separate R1 behavior change and requires its own comparison.
- Verify server/every-HC BOOT build/session/config fingerprints agree.

### Enabled cargo cells

| Cell | Scenario |
|---|---|
| C0 | Two `2500` crates: both checks/loads succeed and link check/commit/CargoLoaded |
| C1 | Two stock `10000` crates: exact `[false,true]` rejection and anomaly probes |
| C2 | Mixed `2500`/`10000` in both orders |
| C3 | Crate exists before normal-client JIP; compare client/server mass/state |
| C4 | Server-to-client and client-to-client ownership through carry, pull, winch, and placement |
| C5 | Load/unload/reload and out-of-order event/report correlation |
| C6 | Deploy/recreate each purpose-built preset 6, 7, and 12–17 |
| C7 | Cargo activity during H2/vehicle-monitor load; enforce heartbeat/frame/RPT budgets |
| C8 | Malformed/flooded reports prove sender validation, caps, suppression records, and safe behavior under the active `mode = 1` policy with the newly added narrow, non-JIP diagnostic endpoints |
| C9 | Parser proves schema/build/run/sequence/link integrity and absence of raw UID/name |

### Exact production-parity staging

Use the selected production `baseLayout`, all external feature flags, DB connection mode, mod/DLC set, HC count/caps/launch arguments, and mission filename. Pre-render the exact target `server.cfg` and record the resolved `-config`, `-cfg`, `-mod`, `-serverMod`, `-profiles`, `-name`, `-world`, and `MPMissions` paths for server and HCs. Include a safe DB connectivity/read-only check. A local same-host matrix cannot substitute for this stage.

## Single maintenance deployment

### Pre-stage

- Create a sibling/target-volume incoming path for every live target (`-config`, `@Apex_cfg`, `MPMissions`, and any launcher/overlay path). Cross-volume copy only into those staging paths; final activation uses same-volume renames.
- On the `MPMissions` volume, stage the new PBO under a non-loadable temporary extension/name. Hash every staged file on the server and compare with the signed/checksummed manifest.
- Keep the previous uniquely named PBO and versioned copies of every external config. Do not overwrite or delete them.
- Resolve and record the exact live `-config` and `-cfg` targets plus the selected `MPMissions` directory before staging. Fully render the replacement `server.cfg` in its same-volume staging path with the new mission template already selected, then hash it; never edit the activated file after hashing. If `basic.cfg` is unchanged, verify its live hash instead of silently assuming it.
- Use the baseline overlay audit to identify intended versus unintended loose sources. Keep required `@Apex_cfg` and any reviewed overlay operational; this mission compiles loose external configuration, so do not broadly disable `-filePatching`. Hash/archive unintended shadows now and version-rename them only while stopped. Any reviewed startup-argument or launcher change must be staged and bound in both release and rollback manifests.
- Select rollback triggers and an operator before stopping processes.

### Stopped-server cutover (atomic per target file)

1. Disable the watchdog/restart loop for the maintenance operation.
2. Stop the dedicated server, then verify all HC processes are stopped.
3. Version-rename the files at the resolved live `-config` / external-config targets, any approved launcher/startup file, and any unintended loose shadow selected for removal; record their post-rename hashes.
4. Same-volume rename the already verified staged `server.cfg` / external config bundle into those exact resolved paths; verify unchanged `-cfg` / `basic.cfg` by hash.
5. Same-volume rename the non-loadable staged PBO to its final unique `.pbo` name in the selected `MPMissions` directory.
6. Verify that the already rendered `server.cfg` selects the new template without `.pbo`; do not edit it live.
7. Verify live PBO/config/template hashes and the resolved startup arguments again.
8. Start the dedicated server alone.
9. Require a valid server `BOOT` record matching release, commit, session, config, and expected domains.
10. Start HCs one at a time; require each BOOT/heartbeat role, build, config, mod, and owner mapping to match.
11. Join a fresh client and compare its downloaded mission cache hash to the server PBO.
12. Run the short Cargo10 two-crate smoke, HC ownership smoke, and DB readiness check.
13. Re-enable the watchdog only after acceptance evidence is saved.

This is one diagnostic deployment built from the already reconciled/corrected base: both instrumentation domains are inside one tagged PBO, while matching external configuration is activated in the same stopped-server cutover. Unrelated pending feature branches are excluded. The operation is recoverable and atomic per same-volume rename, not a cross-volume/multi-file transaction.

### Production canary

Begin at diagnostic level 1. Run 60-90 minutes at low population with connected HCs, the eight-preset two-crate matrix, and at least one full Normal-AO completion using the selected cleanup behavior. Then observe at least two comparable high-population windows. Success means useful evidence within the overhead budget, not merely one freeze-free session. Because R1 contains documented post-live corrections, any symptom change must be interpreted against R0/R1/R2 rather than attributed to the probes alone.

Preserve five minutes before through ten minutes after each incident/recovery. For the first 60-90 seconds of a freeze, avoid stopping HCs if operationally safe so the natural trigger/recovery signature is captured. If an intervention is necessary, stop exactly one preselected HC and record the time.

## Acceptance and rollback

Production acceptance requires all of the following:

- selected PBO SHA-256/name equals the manifest;
- RPT embedded build/commit equals the tag and manifest;
- the release commit is reachable from canonical `origin/main`;
- external config/server/HC launch/mod fingerprints equal the private manifest;
- every HC reports the same build/session and healthy validated heartbeat;
- fresh client cache matches the server artifact;
- disabled/enabled performance budgets and Cargo10 smoke pass;
- no new init/script/remote-exec/DB errors.

Rollback immediately for initialization or DB failure, release/config/HC mismatch, cargo behavior/state corruption, HC locality instability, excessive diagnostic traffic, a new diagnostic-attributable frame gap, or heartbeat/FPS budget breach.

Rollback procedure:

1. disable watchdog automation;
2. stop server, then remaining HCs;
3. restore the versioned prior `server.cfg`/`@Apex_cfg` selection, prior unique PBO template, every moved loose overlay/shadow, and any changed launcher/startup argument or working-directory state;
4. verify all prior hashes against `rollback-before`;
5. start server, validate the prior PBO hash/template/config and either its release marker or its documented legacy startup signature, then start HCs one by one;
6. retain the failed PBO/config/RPTs/dumps unchanged for analysis;
7. restore watchdog automation after old-release acceptance.

The diagnostic commits are observation-only with respect to mission semantics and are DB-schema-neutral; they still write bounded RPT records, counters, and diagnostic traffic. Exclude any pending change that requires a DB schema migration from this cutover, or give it a separate migration and rollback plan; do not infer that the whole reconciled artifact is automatically DB-neutral.

## Proposal to the server runners

Suggested concise proposal:

> We propose one default-off diagnostics mission release, built on the completed reconciliation branch, covering both the intermittent Cargo10/HEMTT admission failure and the server freezes. `5c1ffb3` is the exact-live frozen-B source/behavior checkpoint; reviewed corrections extend through `9f61e06`; the shared diagnostics themselves are not yet implemented. The diagnostic commits keep HCs enabled and do not change cargo mass/capacity, HC allocation, AO cleanup, channels, vehicle monitoring, or friendly-AI behavior. Cargo tracing compares client check-time with server receipt-time mass/locality through load and ownership checkpoints; freeze tracing separates engine frame stalls, scheduled starvation, HC recovery queues, vehicle-monitor load, and fanout. We will keep unrelated feature branches out, pass R0/R1/R2, build one uniquely named PBO from the final canonical commit, and bind it plus external config/HC/overlay inputs in a private release manifest. Deployment and rollback use one stopped-server, hash-verified cutover. The rollout is unified operationally but is not a diagnostics-only causal experiment because R1 intentionally corrects frozen production behavior.

Requested from the runners:

1. confirmation that the frozen-B artifact still identifies the deployment being replaced; the PBO itself is already frozen and hashed;
2. production config/launch/mod/HC inventory, effective overlays, and recent server/HC RPTs through a private channel;
3. a versioned `@Apex_cfg` release input, including an explicit decision on the default-off Workshop policy;
4. owner approval and PR review for the post-live corrections through `9f61e06`, followed separately by approval for diagnostic implementation;
5. a maintenance/canary window covering one AO completion and a later high-population period;
6. an operator authorized to preserve incident artifacts and execute the pre-agreed rollback.

## Immediate next action

The source prerequisite is satisfied; the diagnostics implementation is not. If server runners approve it, branch from clean reviewed `9f61e06` (or its reviewed PR descendant), implement the shared facility as separate default-off commits, add narrow non-JIP RemoteExec endpoints, and run R0/R1/R2 plus the updated eight-preset cargo matrix. Before any production canary, bind the exact PBO, `@Apex_cfg`, startup/HC/mod inventory, effective overlays, and rollback artifact in the private checksummed release manifest.
