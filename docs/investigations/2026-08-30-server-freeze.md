# Intermittent server freeze investigation

Status: active investigation; root cause not yet proven
Date: 2026-08-30 (Asia/Bangkok)
Mission-code state: deployment reconciliation and reviewed corrections implemented through `9f61e06`; shared freeze instrumentation not implemented
Instrumentation: temporary local harness only; production patch remains proposed below
Coordination: [combined cargo/freeze diagnostics and deployment reconciliation](2026-08-30-combined-diagnostics-release.md)
Original local-harness baseline: `a99001f666975fc7034328c66ac29fce291dca49` on `feat/deployable-air-defense-turrets`
Reconciled mission-source baseline: exact-live checkpoint `5c1ffb3`; reviewed mission-code tip `9f61e06` on `reconcile/deployment-20260901`
Arma baseline: `2.22.154045`

## 2026-09-01 reconciliation follow-up

The mission payload freshly served to a joining client was frozen as `Apex_framework_420th_B.Altis.pbo`, SHA-256 `87A87D4A4482C146486033B358510D3551EEC91692390FE3D5F15E9F27256BCC`. Its exact-live mission source is reconstructed at `5c1ffb3`, with reviewed post-live corrections through `9f61e06`. This supersedes the old A/feature-tip source state below for release identity.

That evidence identifies the PBO served to clients, but a direct production server-disk hash comparison, resolved mission selection, loose `-filePatching`/mission-source overlays, external `@Apex_cfg`, server/HC launch and mod inventories, and freeze-window server/HC RPTs remain unaudited. Those inputs still block an exact operational-runtime claim and causal diagnosis.

The reconciliation also corrects an important historical conclusion: the deferred Normal-AO cleanup is present in both cached A and frozen B and is preserved in exact-live R19/current source. It was absent from the freshly fetched `origin/main` baseline and older cached trees, so it remains a deployment-family/fork-specific, unbudgeted freeze-risk candidate, but it is not A-only and cannot be treated as an optional hook in R1 testing.

The deployed HC variable whitelists are now reconstructed in Git. The shared cargo/freeze diagnostic facility remains only a proposal. Instrumentation and production incident capture come before any HC heartbeat gate, transfer-queue policy, AO-cleanup budgeting, private-channel change, friendly-handler change, or vehicle-monitor rewrite.

## Executive finding

There is not yet enough production evidence to name a root cause. No production server or headless-client RPT covering a freeze is available locally. The completed local matrix did not reproduce the hard production freeze.

The strongest mission-side load regression found is nevertheless concrete: the historical mission transition associated with the return of freezes expanded the placed-entity layout from 231 to 474 top-level entities and expanded `mission.sqm` vehicle-registration initializers from 97 to 309, while the extracted mission files were otherwise byte-identical. All 97/309 historical registrations are marked protected and their scheduled registration workers evaluate that flag after mission initialization, so the layout selector does not reject them. The current mission has 366 such initializers but only four are protected, making its live production registry highly dependent on the missing `baseLayout` and feature configuration. The local harness observed 100, 366, and 381 live entries; why L1 stopped at 366 while H0/H2 reached 381 remains unresolved. A routine monitor pass scaled from approximately 3.6 seconds at 100 entries to approximately 13.1 seconds at 366 entries. Engine frames and the five-second scheduled heartbeat remained healthy because the pass yields. This proves near-linear scheduled-work scaling and identifies a credible version-linked amplifier, not that the monitor alone produces the 2-5 minute production freeze.

Headless clients remain a serious interaction hypothesis rather than an established sole cause. The allocator scans groups and units and advances ownership-transfer handshakes on an approximately three-second manager cadence. A declared 30-second allocation gate is not used. The local two-HC test proved that transfers are serialized at roughly one completed one-unit group per HC every 6.5-6.9 seconds and that losing one HC can return all of its groups to the pending queue in one manager tick. Roughly 100 seconds after one HC dropped, a large queue still remained. This reproduces a minutes-long recovery/backlog timescale, not the production stall itself: server frames, scheduled heartbeat, and transfer progress remained healthy throughout the post-connect/drop period.

Two current-fork systems absent from both historical trees also scale naturally with population or entity churn: private-channel respawn synchronization duplicates full reconcile/publish work and remote fanout, while friendly-AI protection installs/validates supported Man/UAV handlers on every machine. Both are stronger high-population candidates than minimal HC variable serialization alone, but neither has runtime timing evidence yet.

A post-matrix deployment-reconciliation audit found another deployment-family lead: both cached A and frozen B contain an unpublished delayed Normal-AO forced-cleanup path absent from the freshly fetched `origin/main` baseline, Jul 25/Jul 18, and older history. When the AO does not configure Defend, cleanup starts 30 seconds after AO deactivation; when it does, teardown starts and waits for the Defend script, then waits another 30 seconds. Several unbudgeted scheduled traversals append nearby `allDead`, delete captured objects/attachments and empty groups, and globally unhide captured terrain objects. The code was present in the A-derived H2 harness, but that cell did not exercise a complete Normal-AO transition. It could be an AO-transition trigger while the HC queue explains gradual recovery, but no incident correlation or runtime cost exists yet.

The reported gradual recovery is therefore consistent with an HC recovery queue slowly draining, potentially while the larger vehicle registry and player population add competing work. The matching two-to-five-minute timescale promotes HC churn as a recovery-path lead, but causality remains unproven until the same queue signature is captured during a production freeze. After observation-only instrumentation captures that signature, the safest first behavioral canary would preserve HCs while testing a heartbeat/stability gate and a bounded or time-budgeted transfer queue; oldest-queue-age telemetry belongs in the preceding observation release.

## Symptom and operational observations

The following are operator/player observations, not measurements from a captured server incident:

- The dedicated server can become completely unresponsive server-side.
- Freezes occur around a medium population, approximately 20 players, and much more often in the 40-70 player range.
- A typical freeze lasts about two to five minutes and often recovers gradually rather than snapping back to normal at once.
- Administrators normally restart the server if it remains frozen longer than about five minutes, so the natural duration of longer events is unknown.
- In one test period with headless clients removed, freezes occurred significantly less often.
- A relatively lightly modified Quicksilver I&A mission had a long apparently stable period. Freezes returned after moving to the server maintainers' more extensively modified fork.
- Mission version and player population both appear associated with exposure. Neither has been isolated as an independent cause.

The target outcome is not merely to disable HCs. The investigation should identify the trigger, reproduce or tightly correlate it, and retain HCs with bounded transfer and recovery behavior.

## Confidence labels

This record uses four evidence classes:

- **Proven:** reproduced locally, counted directly, or established by byte/code comparison.
- **Observed:** reported in production by players or administrators but not represented in the local evidence set.
- **Inferred:** a mechanism consistent with proven facts and observations, with explicit tests still required.
- **Unknown:** necessary evidence is absent.

## Evidence inventory and gaps

### Historical pre-reconciliation deployment and working tree

The original 2026-08-30 investigation used this then-current cached candidate:

- PBO: `Apex_framework_420th_A.Altis.pbo`
- Cached: 2026-08-29 13:07 ICT
- SHA-256: `80AACF333A75BBCE046BA9A41CAB88F78601FF19CC88C3B90C9D8D734C4960F6`

The original, unreconciled working tree was:

- Commit: `a99001f666975fc7034328c66ac29fce291dca49`
- Branch: `feat/deployable-air-defense-turrets`
- The repository is not an exact source representation of the deployed PBO.

One important historical drift example was HC transfer-variable serialization. The [old feature-tip version of `fn_AI.sqf`](https://github.com/420th-Delta/420th-Arma3-PBO/blob/a99001f666975fc7034328c66ac29fce291dca49/Apex_framework.terrain/code/functions/fn_AI.sqf#L919) serialized `allVariables` for groups and agents, while the extracted deployed candidate already used explicit group and agent variable whitelists. The frozen-B reconciliation has now reconstructed those whitelists in Git. Any instrumentation must use `5c1ffb3` or a reviewed descendant; blindly building the old `a99001f` feature tip would still revert unpublished deployment behavior.

### Healthy low-population client session

The only useful production-session RPT found locally is client-side:

- Path: `%LOCALAPPDATA%\Arma 3\Arma3_x64_2026-08-30_18-35-05.rpt`
- SHA-256: `46F4C0C5F2E1FF497756CC8E9823132C675E8A06EEA8AD9349C0880BB6DB5F37`
- Arma: `2.22.154045`
- Mission: `Apex_framework_420th_A`
- Mission ID: `29320d25c1d3b0a2350a8edf380bb4d97ea5173d`

It contains 70 approximately one-minute client reports from 18:37:42.665 through 19:46:46.050 ICT. Server-time drift relative to wall time remained within 0.118 seconds, and reported server FPS samples ranged from 40 to 246. No freeze occurred in that session.

The file proves only that this mission/game combination can remain healthy during this particular low-population period. Its periodic report does not include player or HC counts, so it cannot define the load threshold.

The same session logged 286,431 `Warning Message` lines, 606 object-not-found lines, and 246 `Cannot create` lines, including unresolved Creator DLC content. This heavy warning volume persisted without a freeze; warning spam by itself is therefore insufficient as an explanation. It remains relevant to an HC content-parity check because an HC that owns AI but lacks required classes could follow a different failure path.

### Client dumps

Two roughly 70 MB client minidumps exist from 2026-05-18, including one named `03-16-04FROZEN0.mdmp`. They are client-side dumps with no matching client RPT, server RPT, HC RPT, or server dump in the local evidence set. They cannot establish the server-side freeze mechanism.

### Missing production evidence

No local artifact currently provides all of the following for a freeze window and complete operational baseline:

- dedicated-server RPT;
- one RPT per HC;
- direct server-filesystem confirmation of the freshly served frozen-B PBO hash and the resolved selected mission/loose overlays;
- production `@Apex_cfg`, including `parameters.sqf` and the selected `baseLayout`;
- production server and HC command lines, config, loopback/local-client settings, and mod/content lists;
- synchronized server/HC resource counters;
- server or HC dump/profile captured while frozen;
- exact player count, AI topology, active objective, and HC ownership state at onset.

This is the principal blocker to proving causation.

## Historical mission comparison

Two cached PBOs were selected as provisional history anchors based on cache date and the reported mission timeline. Their labels are not backed by incident RPT hashes and must remain provisional:

| Provisional role | Cached PBO | SHA-256 prefix | Mission `sourceName` |
|---|---|---|---|
| Apparently stable-era anchor | `Apex_framework_420th_20260213.Altis.pbo` | `E6906997612E8823` | `20251216` |
| Modified/resumed-freeze-era anchor | `Apex_framework_420th_modded_20260303.Altis.pbo` | `D172DBAC72FC353D` | `20260227` |

Each extracted mission tree contains 1,101 files. Of those, 1,100 were byte-identical; the only changed mission-tree file was `mission.sqm`. A zero-byte extraction `.txt` sidecar exists outside each mission tree and is not part of this count.

| Layout characteristic | Stable-era anchor | Modified-era anchor | Change |
|---|---:|---:|---:|
| Top-level mission entities | 231 | 474 | +243 |
| `QS_fnc_registerVehicle` initializers | 97 | 309 | +212 |
| Addon dependencies | 31 | 105 | +74 |

The additions include roughly 217 registered RHS/FIR/USAF vehicles, many initialized with the equivalent of a 30-second monitored respawn and dynamic-vehicle flag, plus terrain-hide modules. The exact difference between the approximate added-vehicle count and initializer delta depends on how the mission entries are classified; the authoritative registration count is 97 versus 309.

All 97 February and 309 March initializers also mark their objects `QS_missionObject_protected`. Although that assignment appears after the `QS_fnc_registerVehicle` call in the Eden init string, the function spawns a worker that waits for mission initialization before checking the flag. The registrations therefore survive the `baseLayout=0` gate as well as the custom-layout path.

The intermediate cached chronology further pins later growth to mission data: Apr 24, May 12, Jun 20, Jun 20 v3, Jul 7, and Jul 18 each had 115 `mission.sqm` registration initializers. Jul 25 jumped to 364, and the current candidate has 366. Only four of the Jul 25/current initializers are protected, while `fn_AI.sqf` and `fn_core.sqf` were unchanged from Jul 18 to Jul 25.

For the current mission, static code arithmetic predicts 100-109 live entries under `baseLayout=0`, depending on the eight Cargo10 feature switches, or 381 after placed-layout/default-table initialization under nonzero `baseLayout`, before later carrier, destroyer, deployable, or FOB paths add anything. The harness observed B0 at 100, L1 at 366, and H0/H2 at 381. L1's missing 15 FOB-ID `-2` table entries despite using `baseLayout=1` is an unresolved harness/startup-state difference, not an established alternate production configuration. The actual production value remains unknown.

### What the comparison proves

- The selected transition materially expanded mission entity and monitored-vehicle state.
- HC code did not change across this particular pair because every file other than `mission.sqm` was identical.
- Mission data alone can amplify existing monitor and scheduler code without a code-file edit.

### What the comparison does not prove

- It does not prove either PBO was running during a specific recorded freeze or freeze-free session.
- It does not prove one of the added object classes is defective.
- It does not prove the vehicle monitor is the only subsystem involved.
- It does not exclude later HC, networking, objective, or security changes from affecting current freezes.

## Static mission audit

### Registered-vehicle monitor

[`fn_registerVehicle.sqf`](../../Apex_framework.terrain/code/functions/fn_registerVehicle.sqf#L57) first rejects an unprotected placed object when `baseLayout=0`. Each accepted non-UAV registration is stored in `serverNamespace` under `QS_v_Monitor`, and its placed editor object is then deleted after configuration capture; accepted UAVs use a separate monitor. Default-table and later runtime systems can also add entries through other paths.

The server core walks `QS_v_Monitor` in [`fn_core.sqf`](../../Apex_framework.terrain/code/functions/fn_core.sqf#L3244). A pass can perform player-distance, pilot, near-entity, crew, locality, hit-point, state, condition, respawn, texture, deletion, creation, and ownership work. It also performs an unconditional `sleep 0.01` for every entry at [`fn_core.sqf`](../../Apex_framework.terrain/code/functions/fn_core.sqf#L3775).

Consequences established by code inspection:

- 100 entries impose at least 1.00 second of explicit scheduled sleep per full pass.
- 309 entries impose at least 3.09 seconds.
- 366 entries impose at least 3.66 seconds.
- Actual scheduled wall time is higher because sleep resumes on scheduler opportunities and each entry performs work.
- A sleeping scheduled script does not itself freeze engine frames, but a long all-entry traversal increases scheduler latency and makes concurrent work easier to backlog.

Dynamic ground entries may initially exist as simple objects, while helicopters and non-dynamic entries become real vehicles. Simple objects remain in the monitor and still incur iteration/sleep cost. Player activity can activate dynamic vehicles and expose the more expensive branches, making population a plausible exposure multiplier rather than a direct linear cause.

The monitor currently performs one monolithic full-array pass. There is no explicit per-frame or per-cycle time budget, no ring cursor, and no separation between fast-state and slow-state entries.

### Headless-client allocator and transfer state machine

Static reading of [`fn_AI.sqf`](../../Apex_framework.terrain/code/functions/fn_AI.sqf#L454) found:

- `_QS_module_hc_delay` is set to 30 seconds.
- `_QS_module_hc_checkDelay` is initialized but not used to gate new allocations.
- The enclosing AI manager cadence allows the HC distributor to revisit allocation work approximately every three seconds.
- Source defaults are `[80,60,40,25]` units and `[20,15,10,5]` agents; at four or more authoritative connected HCs those select 25 units and five agents per HC. Production `@Apex_cfg` can override both arrays, and its values are missing.
- The distributor scans units/groups for each HC and can begin one eligible group and one eligible agent transfer per HC cycle.
- Group transfer is a multistage handshake: the server serializes state, the HC installs locality handling, the server calls `setGroupOwner`, and the new owner reapplies state/loadouts as locality settles.

This mechanism can plausibly create a transfer/reapply backlog, particularly with many one-unit vehicle/static groups, locality churn, or HC reconnect recovery. It also gives a mechanism for gradual recovery after new work stops arriving. That interpretation is not proven without transition ages, per-stage counts, owner changes, and cycle durations from a freeze.

The unused delay is longstanding and appears in at least a May stable-ish mission, so it is not by itself a regression matching the historical transition. It is better treated as an amplifier/control defect and an experiment target.

### Later changes relevant to current incidents

Commit `933ce8d2adf4381cbc38fa7ea08e8309b8df1c51` (2026-08-24) added or changed HC disconnect/recovery, event-handler cleanup, security validation, and AI-intel distribution behavior. Important current paths include:

- sender-rate-limited enemy-intel deltas from HC to server, capped target snapshots, and approximately once-per-second rebroadcasts to AI owners;
- recursive payload validation and sender rate maps on inbound remote execution;
- HC disconnect/recovery handling and event-handler cleanup.

These changes postdate the February/March layout split. Several are bounded or cleanup-oriented and are not currently stronger candidates than the vehicle-monitor/HC interaction. They should still be timed in production instrumentation because a current freeze could have more than one entry condition.

The same commit fixed two literal blocking defects present in older mission versions:

- the towing detach/safe-position path used a non-yielding `for ... step 0` position-search loop with no deadline; current code bounds it to 12 attempts and approximately 25 ms;
- `HandleDisconnect` synchronously traversed `allMissionObjects 'All'` in an unscheduled handler; current code moves registry cleanup into scheduled, yielding work.

Both are proven historical defects and plausible explanations for older incidents, but neither is proven to have caused one. The original feature tip and the served A/B deployment candidates contain the fixes, so they are not current-version leads.

#### Served A/B Normal-AO cleanup

Both the clean cached-A extraction and frozen B contain `QS_normalAO_deferredAIObjects` handling across `fn_AI.sqf`, `fn_config.sqf`, and `fn_core.sqf`; exact-live R19 reconstructs it in the current branch. At Normal-AO deactivation it captures HQ, enemy, reinforcement, civilian, structure, and hidden-terrain state. If the AO does not configure Defend, processing begins 30 seconds later; otherwise teardown starts the Defend script, waits for it to finish, and then waits another 30 seconds. It subsequently appends nearby `allDead` objects, deletes captured objects and attachments, deletes empty groups, and globally unhides terrain objects.

The `allDead` collection, object/attachment deletion, empty-group deletion, and global unhide work have no explicit item or elapsed-time budget. They run in scheduled context, so absence of a sleep does not by itself prove a main-thread freeze, but entity deletion and global effects can still create substantial engine/network/locality work. The path is present in cached A and frozen B but absent from older cached trees and the original `origin/main` baseline. It was present in the H2 harness source but not exercised. Exact-live R19 preserves it as evidence; production approval now requires timing candidate collection, the `allDead` scan, ownership/HC-stage distribution, each delete/attachment/group/unhide phase, and total elapsed through a complete AO transition. Any later budgeting or removal is a separate behavior canary.

### Recent fork-only high-population candidates

Two current systems deserve explicit production timing because they are present in both the cached deployed candidate and repository but absent from both February/March mission trees. Their raw cached-deployment and repository hashes differ because of line endings; after CRLF/LF normalization the compared implementations are semantically identical. Instrumentation must still be applied to reconciled deployed source because many other files contain substantive drift.

| Component | Cached deployed-candidate SHA-256 | Repository SHA-256 | February/March trees |
|---|---|---|---|
| `fn_serverPrivateChannels.sqf` | `3929757B178181E2BF5A2FC37AFF41C08F98DE3A2BF42F3DF61B066F70DE3D79` | `E4E5BC55F0CADC2B493E3954873DEABD1BAE22A09B18085E44540964DB77856D` | Absent |
| `fn_initFriendlyAIProtection.sqf` | `B9DB14DE102FC76A8C0268269BCA449DA75888EB21E748CDFFA29BF296309ABF` | `58441DF426C2D72535500E9D8531707257B9570FC3B9CE20910E791E535B53C5` | Absent |
| `fn_addFriendlyAIHandlers.sqf` | `80792065181DF1D8CEDFDD623A2B929271963F3F230C6A8B8B2D4971AA84D231` | `16F2A4453548412CE8CD9AFFF96B4A053656189C551BDF83125D903B41CAAACB` | Absent |

These are stronger fork/population-specific trigger candidates than the minimal A-derived `case 98` serialization cost alone. They remain unproven: no production mode/count/timing evidence or controlled high-respawn/entity-creation cell exists yet.

#### Private-channel respawn reconciliation and fanout

Static behavior in the repository:

- server [`EntityRespawned`](../../Apex_framework.terrain/code/functions/fn_eventEntityRespawned.sqf#L21) calls private-channel `SERVER_SYNC` for the new player object;
- client [`Respawn`](../../Apex_framework.terrain/code/functions/fn_clientEventRespawn.sqf#L23) independently sends private-channel `SYNC` to the server;
- both modes reach full reconcile/publish behavior in [`fn_serverPrivateChannels.sqf`](../../Apex_framework.terrain/code/functions/fn_serverPrivateChannels.sqf#L243);
- publish loops across all players, then all channels relevant to each target, then channel members, and performs a fresh `allPlayers findIf` for each member before remote-executing a snapshot to every player.

Thus one player respawn can request two full roster reconciliations and publications. Work and remote fanout grow with online players, channels, and channel members. This is a static scaling risk, not proof it is enabled or slow in production; the production value of `QS_privateChannels_enabled` is currently unknown.

Required telemetry:

- request mode/source and a respawn correlation ID;
- whether the feature is enabled;
- player/channel/member counts, nested lookup count, reconcile and publish elapsed time;
- snapshot item/estimated byte count and remote recipients;
- duplicate full-sync requests within a short respawn window.

Candidate correction, after measuring the deployed implementation:

- perform one authoritative server-side respawn delta sync rather than both server and client full syncs;
- build one UID-to-unit/online map per publication instead of repeated `allPlayers findIf` scans;
- publish only affected channels/clients, retaining explicit full sync for JIP/recovery.

#### Friendly-AI protection entity/handler fanout

[`fn_initFriendlyAIProtection.sqf`](../../Apex_framework.terrain/TGC/Functions/Damage/fn_initFriendlyAIProtection.sqf#L28) is a `postInit` on the dedicated server, every client, every HC, and JIP clients. On each machine its global `EntityCreated` handler processes every supported Man/UAV entity, attaches protection handlers, and spawns a zero-sleep validation worker. The friendly-side decision is deferred until the installed `HandleDamage` path in [`fn_addFriendlyAIHandlers.sqf`](../../Apex_framework.terrain/TGC/Functions/Damage/fn_addFriendlyAIHandlers.sqf#L66), rather than gating handler installation itself.

Entity-creation waves can therefore multiply attachment, event-handler inspection, and worker-scheduling work by the server plus every connected client and HC. Locality and handler-ID reconciliation make this more subtle than raw entity count. No measured incident currently links it to a freeze.

Required telemetry per machine role:

- total and supported `EntityCreated` rate;
- local versus remote entity, class/side, and eventual friendly eligibility;
- handler attach/reuse/remove counts and elapsed time;
- spawned validation-worker count, concurrency, and elapsed time;
- `HandleDamage` invocation and early-filter rates.

Candidate correction is to gate attachment by eligible side and locality, handle later ownership changes through a bounded `Local` path, and avoid spawning a validation worker when handler state is already known current. Multiplayer protection semantics must be regression-tested before narrowing where handlers exist.

PMC/database-whitelist synchronization and Spawn Menu loops remain lower-ranked telemetry domains. The current evidence does not show comparable nested population scaling or incident correlation for them.

## Completed local matrix

The local harness is a temporary copy outside the repository. It adds diagnostic logging and synthetic-load controls to an extracted current mission candidate. No result below comes from modified repository mission code.

Same-machine HCs require `loopback=true` plus matching `localClient` authorization. Initial launches without those settings could not connect. Those attempts are harness failures, not mission results. All test server and HC PIDs were stopped after the matrix; the runtime mission copies, profiles, and RPTs remain under `%LOCALAPPDATA%\Temp\codex-420-freeze-runtime` for audit.

### Matrix summary

| Cell | Mission/load | Connected HCs | Duration | Result |
|---|---|---:|---:|---|
| B0 | `baseLayout=0`, no synthetic groups | 0 | approximately 113 s | No freeze; 100-entry monitor pass approximately 3.6 s |
| L1 | `baseLayout=1`, no synthetic groups | 0 | approximately 205 s | No freeze; 366-entry monitor pass approximately 13.1 s |
| H0 | `baseLayout=1`, 100 synthetic one-unit EAST groups | 0 | approximately 139 s | No freeze; 381-entry monitor pass approximately 13.4-13.7 s |
| H2 | `baseLayout=1`, 100 synthetic one-unit EAST groups; drop and reconnect second HC | 2 | approximately 8 min | No hard freeze; reproduced a serialized minutes-long transfer/recovery queue |

### B0: clean lower-layout baseline

Result: completed; no freeze or material frame stall observed.

| Field | Value |
|---|---|
| RPT | `%LOCALAPPDATA%\Temp\codex-420-freeze-runtime\profiles\server-baseline\arma3server_x64_2026-08-30_20-13-23.rpt` |
| RPT SHA-256 | `42ACDF059EE4F492DE91574B0DECCD44CDAA4BDE02499F99DCA5D138C5AEA4C6` |
| Process interval | 20:13:22-20:15:15 ICT, approximately 113 seconds |
| Diagnostic sample interval | 20:13:51-20:15:12 ICT, 17 samples |
| Layout selector | `baseLayout=0` |
| Human players / connected HCs / synthetic groups | `0 / 0 / 0` |
| `QS_v_Monitor` entries | 100 |
| Units | 10 |
| Settled vehicles | 37-40 |
| Server FPS | approximately 27.5-28.3 |
| Five-second sample gap | 5.000-5.033 seconds |
| Unscheduled frame gaps over 250 ms | none logged |
| Typical vehicle-monitor pass | approximately 3.57-3.62 seconds scheduled wall time |
| Startup spawn-wave monitor pass | 5.268 seconds |
| Process snapshot near 109.9 s uptime | 31.92 CPU seconds; 2.64 GB working set; 3.83 GB private memory |

Even with only 100 monitor entries, a routine pass occupied about 3.6 seconds of scheduled wall time. Engine frames and the five-second sampler remained healthy because the pass yields. B0 is too short and lightly loaded to reduce the probability of an intermittent 20-70-player event meaningfully.

### L1: current layout without synthetic groups or HCs

Result: completed; no freeze or material frame stall observed.

| Field | Value |
|---|---|
| RPT | `%LOCALAPPDATA%\Temp\codex-420-freeze-runtime\profiles\server-baseline\arma3server_x64_2026-08-30_20-18-23.rpt` |
| RPT SHA-256 | `F8D5F04AB3980D86A8D7D5094AADBF0914401198E8AD0BE13A4869BC0BC92A60` |
| Diagnostic coverage | at least 34 samples across approximately 205 seconds |
| Layout selector | `baseLayout=1` |
| Human players / connected HCs / synthetic groups | `0 / 0 / 0` |
| Settled monitor state | 366 live entries: 119 simple and 247 real |
| Server FPS | approximately 27.7-28.3 |
| Five-second sample gap | normally 5.000-5.033 seconds; one 5.066-second sample |
| Unscheduled frame gaps over 250 ms | none logged |
| Typical vehicle-monitor pass | approximately 13.070-13.125 seconds scheduled wall time |
| Startup passes | approximately 13.160-13.218 seconds |

The 3.66x entry increase from B0's 100 to L1's 366 produced approximately 3.6x monitor-pass wall time. This near-linear scaling confirms that the unconditional per-entry sleep and traversal dominate elapsed scheduled time. It did not stop frames or the sampler in isolation.

### H0: synthetic topology without HCs

Result: completed; no freeze or material frame stall observed.

| Field | Value |
|---|---|
| RPT | `%LOCALAPPDATA%\Temp\codex-420-freeze-runtime\profiles\server-baseline\arma3server_x64_2026-08-30_20-25-51.rpt` |
| RPT SHA-256 | `06E4F879B89B7416317B6AFE5A0E41A2EF9D3CEEEBDE8AEA7DF99B845171DD22` |
| Process/log interval | approximately 20:25:50-20:28:09 ICT, 139 seconds |
| Layout / synthetic load | `baseLayout=1`; 100 one-unit EAST groups |
| Human players / connected HCs | `0 / 0` |
| Startup monitor profile | 381 entries: 134 dynamic, 247 non-dynamic, 15 FOB-tagged |
| Settled monitor state | 381 live entries: 134 simple and 247 real |
| Units / groups | 110 units; approximately 102-103 groups |
| Server FPS | approximately 28 |
| Five-second sample gap | 5.000-5.037 seconds |
| Unscheduled frame gaps over 250 ms | none logged |
| Typical vehicle-monitor pass | approximately 13.39-13.70 seconds scheduled wall time |

The 15 FOB-tagged entries account for H0's increase from the 366 placed initializers to its 381-entry runtime profile. Their absence from L1 remains unresolved even though both cells selected `baseLayout=1`; synthetic groups do not participate in the table-append condition. The one-unit topology alone did not freeze the server without HCs.

### H2: two HCs, disconnect recovery, and reconnect

Result: completed; no hard freeze. The test reproduced slow, serialized queue recovery on the same two-to-five-minute order as the reported symptom.

| Field | Value |
|---|---|
| Server RPT | `%LOCALAPPDATA%\Temp\codex-420-freeze-runtime\profiles\server-baseline\arma3server_x64_2026-08-30_20-32-39.rpt` |
| Server RPT SHA-256 | `92D1B67C9AB9790D59B0064AA6FA27A60E9E4DDF866AE5CC7FA2493EA63C659C` |
| Approximate server interval | 20:32:39-20:40:46 ICT, about eight minutes |
| Layout / synthetic load | `baseLayout=1`; 100 one-unit EAST groups |
| Initial HCs | owners 4 and 5, connected around 20:34:38 and 20:34:40 after mission download |
| Second HC drop | owner 5 stopped at 20:37:24; detected at 20:37:39 |
| Second HC reconnect | new owner 6 connected at 20:39:48 after an approximately 14-second cached reconnect |
| End counters | `returnTo0=22`, `0to1=91`, `2to3=86`, `failures=0`, `case98=3` |

HC-side audit artifacts:

| Role/run | RPT | SHA-256 |
|---|---|---|
| Owner 4 / HC1 | `profiles\HC01Run\arma3server_x64_2026-08-30_20-33-14.rpt` | `A5EE13AC2F3F3009F413C635F6E80AD68FC5E0B0284A7F0CABA7C71E2EB9D7CC` |
| Owner 5 / first HC2 process | `profiles\HC02Run\arma3server_x64_2026-08-30_20-33-16.rpt` | `4D9B168DFABAF64E3B55AAB175D79333AF2C1565EE448276DDD9AF070D0A161A` |
| Owner 6 / reconnected HC2 process | `profiles\HC02Run\arma3server_x64_2026-08-30_20-39-34.rpt` | `9914ACE4A8F9346B2433ACE75A79F840C90FF5E31AE876E652E3C28FE90CC1D2` |

The current deployed candidate's whitelist snapshot (`case 98`) was cheap in this minimal topology:

- each initial HC snapshot covered 100 groups, 400 variables, and a 15-name whitelist in approximately 0.002 seconds;
- the reconnect snapshot covered 44 groups and 176 variables in approximately 0.002 seconds;
- no ownership-transfer failure was logged.

This demotes whitelist/group snapshot serialization as a standalone explanation in the A-derived harness. Production groups can carry different variables and cause larger network fanout, so only production timing and payload aggregates can close the question.

Observed transfer/recovery behavior:

1. Across 88 matched server handshakes, stage 0-to-1 through stage 2-to-3 latency was 2.779 seconds minimum, 3.374 median, 3.495 mean, and 9.467 maximum.
2. Per-owner intervals between completed stage 2-to-3 transfers were tightly serialized: owner 4 had 54 measured intervals with 6.684 seconds median/6.673 mean; owner 5 had 23 with 6.869 median/6.730 mean; reconnected owner 6 had eight with 6.498 median/6.642 mean. Owner 4 completed 55 groups, owner 5 completed 24 before its drop after starting 29, and owner 6 completed nine.
3. Immediately before owner 5's loss was detected, the stage 0-4 queue was approximately `[50,2,0,2,42]`.
4. Detection returned 22 groups to stage 0 in one manager tick; the next observed queue was approximately `[70,1,0,0,25]`.
5. The remaining HC reclaimed work at its normal serialized rate. Roughly 100 seconds after the drop, about 53 groups were still at stage 0 and about 32 were at stage 4. At the measured rate, 20 queued groups on one HC take roughly 2.2 minutes and 45 take roughly five minutes.
6. Mission cleanup deleted some synthetic groups/units during the run, so stage vectors are not a strict conservation series.
7. Owner 6's reconnect restored two-HC throughput without a transfer failure or material frame gap.

Once loopback clients were active, health remained stable through each phase: post-join/pre-drop had 37 samples with 4.999-5.023-second heartbeat gaps; post-drop/pre-reconnect had 25 with 4.999-5.011-second gaps; post-reconnect had 12 with 4.999-5.009-second gaps. FPS ranges were approximately 107.4-113.5, 106.0-114.3, and 106.7-113.5 respectively. Same-host loopback wakes the server/full cap, so those FPS values are not comparable to B0/L1 or production; heartbeat and frame-gap evidence are the useful measures. Four frame gaps from 0.316 to 0.784 seconds occurred only while the two cold HC processes were starting, before either process actually connected. No post-connect or post-drop frame gap over 250 ms was logged.

The local test therefore demonstrates the timing and shape of a recovery backlog, not a server freeze. It is evidence that an HC loss can create minutes of serialized recovery work and that recovery can be gradual. It is not evidence that an HC drop occurred during any production incident or that this queue stalls the server under real player, AI, mod, and network load.

### Instrumentation caveat discovered by H2

The temporary `SAMPLE` fields named `hcs` and `hcOwners` count HC slot/logic entities, not authoritative connected processes. After owner 5 dropped, those fields briefly showed stale/duplicated logic-owner state such as `[4,4]`. The HC manager's `HC_CYCLE` record correctly reported one connected HC.

Interpret the existing `SAMPLE` fields only as `hcSlots` and `hcLogicOwners`. Production instrumentation must record both slot/logic observations and an independently derived connected-HC count. It should also log stale slot age and the authoritative manager-cycle owner set.

## Remaining comparisons

| Cell | Purpose | Status |
|---|---|---|
| Four-slot HC topology | Measure throughput and churn with all four mission HC slots occupied; production process count is unknown | Pending |
| Infantry-shaped groups | Compare 25 four-unit groups with 100 one-unit groups | Pending |
| V1 stable-era mission | Separate historical mission layout from current engine/harness | Pending |
| P1 stability/new-allocation gate | Test a heartbeat/stability gate and bounded placement causally | Pending |

A single machine cannot reproduce the JIP, mod, bandwidth, remote-exec, and human activity of 20-70 real clients. Repeat any decisive cell and use matched startup/cache conditions. The local matrix is for mechanism isolation, not a substitute for production capture.

## Ranked hypotheses

Rank describes current investigative priority, not final causal confidence.

### 1. HC allocation/locality/recovery backlog interacting with server load

**Confidence:** high for the serialized recovery mechanism and its minutes-long timing; medium as a production freeze component; unproven as the stall trigger.

Supporting evidence:

- One no-HC operational test reportedly reduced freeze frequency.
- Allocation is revisited far more often than the declared 30-second delay implies.
- Transfer is multistage and can reapply variables, properties, and loadouts.
- H2 measured roughly one completed one-unit group per HC every 6.5-6.9 seconds.
- Losing one HC returned 22 groups to stage 0 in a single tick, after which one HC drained the queue slowly; a large pending queue remained about 100 seconds later.
- The observed recovery shape and timing match the reported gradual two-to-five-minute symptom closely enough to justify production queue-age instrumentation and a bounded recovery canary.

Counter-evidence/limits:

- HC code was identical across the provisional stable/resumed historical pair.
- H2 did not freeze: frames, five-second heartbeat, ownership changes, and HC cycles remained healthy.
- There is no production freeze-window stage-age or ownership record.
- Removing HCs also moves AI simulation back to the server and changes many variables at once; it is not a clean mechanism test.

### 2. Served-deployment Normal-AO cleanup burst

**Confidence:** low-to-medium as a causal trigger candidate, but high information priority because it is specific to the served deployment family versus the older/main baselines and remains unmeasured in runtime.

Supporting evidence:

- The path appears in both cached A and frozen B, but not Jul 25/Jul 18, older history, or the freshly fetched `origin/main` baseline; exact-live R19 preserves it.
- It deliberately gathers deferred AO objects, nearby `allDead`, attachments, empty groups, and hidden terrain, then processes the captured sets without an explicit item/time budget.
- Deleting HC-associated entities and applying global terrain changes could create an engine/network/locality burst immediately before HC recovery work.
- This provides a concrete model in which an AO-transition burst is the trigger and the proven serialized HC queue shapes the slow recovery.

Counter-evidence/limits:

- No freeze report has been correlated with AO completion, the no-Defend 30-second boundary, or the wait-for-Defend-plus-30-second boundary.
- Scheduled execution can be time-sliced, and no local elapsed/frame/scheduler measurement exists for this phase.
- It was not exercised by B0/L1/H0/H2, so current priority comes from version specificity and workload shape rather than reproduction.

Required discriminating evidence is a full AO completion with phase timing, input/output counts, owner/HC-stage distribution, frame and scheduled health, and any HC queue reset immediately before/after cleanup.

### 3. Fork-only private-channel and friendly-AI fanout under population/entity churn

**Confidence:** medium as high-population candidates; unproven in runtime; stronger fork-specific leads than group-whitelist snapshot cost.

Supporting evidence:

- Both systems are absent from the February/March trees and present in current cached deployment and repository sources; the compared implementations differ only by line endings after normalization, so there is no known semantic deployment/repository drift in these two paths.
- A player respawn can trigger both server `SERVER_SYNC` and client `SYNC`, each reconciling/publishing the private-channel roster.
- Private-channel publication nests player/channel/member traversal, repeated online-player lookup, and per-player remote fanout.
- Friendly-AI protection runs on every machine and attaches/validates handlers for every created supported Man/UAV before friendly-side filtering occurs in `HandleDamage`.
- Both mechanisms naturally scale with player, respawn, entity-creation, and machine counts.

Counter-evidence/limits:

- Production private-channel enablement, channel/member counts, respawn rate, and elapsed cost are unknown.
- No friendly-protection entity/handler/worker rates have been captured from production.
- Neither completed local matrix load exercised realistic player respawns, private channels, JIP, or distributed entity creation.

Required discriminating evidence is per-mode/per-role counts and elapsed time, duplicate respawn correlation, remote fanout size, and handler/worker rates before and during a production incident.

### 4. Monolithic vehicle-monitor work amplified by mission layout and player activation

**Confidence:** high as a scheduled-work amplifier; low-to-medium as a primary freeze component; disproven as a sufficient cause in the completed zero-HC local cells.

Supporting evidence:

- The suspected historical transition changed only `mission.sqm` in the selected anchors.
- Historical `mission.sqm` registration initializers rose from 97 to 309; the current mission has 366 initializers, and the local cells measured 100, 366, or 381 live entries under different/unresolved startup states.
- Every pass scans every entry and sleeps per entry.
- Measured steady pass time scaled from approximately 3.6 seconds at 100 entries to approximately 13.1 seconds at 366 and 13.4-13.7 seconds at 381.
- More players plausibly activate more dynamic vehicles and trigger expensive proximity, crew, ownership, state, and respawn branches.

Counter-evidence/limits:

- B0, L1, and H0 retained healthy frames and five-second heartbeats despite the long scheduled traversal.
- No zero-HC local cell reproduced even a short hard stall.
- A production interaction may still arise when real objectives, players, HCs, JIP, and network traffic compete for the scheduler.

Required discriminating evidence:

- monitor pass duration, entry-class counts, expensive-branch counts, and scheduler gaps immediately before/during a production freeze;
- an equivalent V1 stable-era local timing;
- a bounded ring-buffer monitor canary under matched production load.

### 5. Population-dependent threshold from combined AI, object, JIP, and networking work

**Confidence:** medium as an exposure model; low as a standalone explanation.

Population likely changes active objectives, AI groups, deployed/activated vehicles, remote requests, JIP state, and ownership churn simultaneously. The 20-player onset and 40-70-player frequency increase are compatible with a threshold. They do not identify which subsystem crosses it.

### 6. HC mod/content/DLC parity failure

**Confidence:** low-to-medium; specific and cheap to test.

The healthy client RPT contains extensive unresolved Creator DLC-class warnings. If HCs launch with a different server-side mod/content set and then receive groups or loadouts referring to absent classes, ownership transfer or state reapplication could fail or churn. Identical resolved addon/class inventories across server and every HC would sharply reduce this hypothesis.

### 7. Current AI-intel, remote-exec validation, or disconnect-recovery hot path

**Confidence:** low-to-medium for present incidents; cannot explain the earlier March transition by itself.

These paths can scale with senders, targets, or churn, but known rate limits and caps make them less immediately compelling than the unbudgeted monolithic full-array monitor. They remain instrumentation targets because present production code differs from the historical anchor.

### 8. Base-game engine regression

**Confidence:** low with present evidence.

No engine-only comparison has reproduced the freeze, and mission-version/HC associations are stronger. An engine interaction cannot be excluded until stable and current missions are compared on the same binary and a failing current cell is tested across engine versions where practical.

### Low-probability standalone explanations

- RPT warning volume alone: a healthy session sustained very high warning volume.
- A-derived group-whitelist snapshot cost alone: H2 processed 100 groups/400 variables in approximately 0.002 seconds with no transfer failure.
- A permanent deadlock: most reported events recover, and often do so gradually.
- HC presence alone: stable-era missions reportedly used the system, and no-HC testing changes more than one variable.

## Causal predictions

| Hypothesis | Expected signature during a freeze | Evidence that would weaken it |
|---|---|---|
| Vehicle-monitor backlog | `VMON_PASS` duration/branch counts rise before scheduled heartbeat gaps; unscheduled frames may remain alive initially | Freeze with short/idle monitor passes, or same incident after bounded monitor canary |
| Engine/main-thread stall | `EachFrame` gaps and external CPU/thread behavior stall together | `EachFrame` remains timely while scheduled heartbeats stop |
| Scheduled-script starvation | `EachFrame` remains alive while scheduled heartbeat, HC stages, and mission timers accrue delay | Both frame and scheduler telemetry remain healthy |
| HC transfer/recovery backlog | Large or old stage 0-4 populations, owner churn, rising oldest-queue age, repeated property/loadout reapply | Freeze with no transfer/recovery work, stable stage ages, and short cycles |
| HC disconnect recovery | HC registration/disconnect precedes a one-tick stage reset and then serialized reclamation | No HC connection event or recovery work near onset; bounded/stability-gated canary has no effect |
| Normal-AO cleanup burst | AO completion reaches either the no-Defend 30-second or wait-for-Defend-plus-30-second cleanup; one of the separately timed candidate/`allDead`/delete/attachment/group/global-unhide traversals shows large counts or health lateness immediately before HC/locality recovery work | Freeze outside AO cleanup with short phase timings; budgeted cleanup canary has no effect |
| Private-channel respawn fanout | Respawn-correlated duplicate `SERVER_SYNC`/`SYNC`, high reconcile/publish time, nested lookups, and remote snapshot fanout rise before lateness | Feature disabled or low/flat elapsed/fanout through a freeze; deduplicated delta canary has no effect |
| Friendly-AI protection fanout | Per-role `EntityCreated`, handler attach, and worker rates surge with entity creation before frame/scheduler gaps | Low/flat rates through a freeze; locality/eligibility-gated canary has no effect |
| Content mismatch | Class/config errors correlate with transfer/reapply on one HC; inventories differ | Server/HC addon, mod, DLC, and config fingerprints match |
| Network/JIP saturation | Queue/bandwidth/desync and JIP events lead scheduler/remote-exec pressure | Freeze in no-client synthetic test with quiet networking |

## Proposed production instrumentation

Instrumentation should be default-off, rate-limited, machine-readable, and identical across server and HCs. The temporary local prefix is `T420_FREEZE`; a production implementation should use a versioned shared contract such as `T420_DIAG|v=1|domain=freeze` so it can coexist with the [Cargo10 investigation](2026-08-30-cargo-mass.md) without creating two incompatible logging systems.

### Core events

1. `BOOT`
   - embedded release/tag/commit/tree/normalized-source identity, externally supplied manifest ID, mission name/id, product version, command-line-safe mod fingerprint, role, owner ID, world, uptime origin, `baseLayout`, all eight `QS_missionConfig_cntnr*` values, carrier/destroyer flags, private-channel enabled state, configured `QS_missionConfig_hcMaxLoad`/`hcMaxAgents` arrays, selected effective HC caps, selected Normal-AO-cleanup capability/disposition, and other relevant feature flags; final PBO SHA-256 stays in deployment tooling and the sidecar manifest;
2. `HEALTH_SAMPLE`, every five seconds
   - `diag_tickTime`, `serverTime`, expected/actual interval and lateness, FPS/min FPS/frame time, human count, `hcSlots`, `hcLogicOwners`, authoritative connected-HC count/owners, and only cached unit/group/vehicle/`QS_v_Monitor`/transfer-stage/queue-age/HC-owned-unit counts maintained by existing work; collect process CPU/memory/IO externally, and reserve active-script enumeration for an operator-triggered level-2 slow path;
3. `FRAME_GAP`
   - unscheduled `EachFrame` gap above 250 ms, rate-limited;
4. `SCHEDULED_GAP`
   - actual heartbeat interval and lateness relative to the five-second target; warning at 250 ms late, critical at one second late, with cooldown and suppressed-count fields;
5. `FREEZE_STATE`
   - separate frame/scheduled boundary state; enter on a one-second critical gap/lateness and record channel, trigger/max gap, start/end, duration, and suppressed count; recover after 15 seconds without another critical frame gap and three consecutive scheduled samples below 250 ms lateness;
6. `VMON_PASS`
   - entry totals by dynamic/non-dynamic/live/simple/real class, pass start/end/duration, entries visited, expensive branch counters, creations/deletions/respawns/ownership changes; per-entry timing is level 2 only for a short controlled test;
7. `HC_CYCLE`
   - authoritative connected owners, cycle elapsed time, groups/units/agents scanned, new transfers started, stages advanced, stage counts and oldest/percentile age, one-tick `returnTo0` count, failed `setGroupOwner` calls, variable/loadout payload sizes, disconnect-recovery work;
8. `HC_TRANSITION`
   - stable group/agent correlation ID, prior/new stage and owner, age in stage, unit count, locality, attempt count, reason;
9. `HC_CONNECTION`
   - slot/logic owner, network owner, heartbeat age, registration/disconnection/reconnect event, observational heartbeat/readiness state, and number of groups returned or made eligible; this does not implement a behavioral stability gate;
10. `PRIVATE_CHANNEL_SYNC`
   - enabled state, request mode/source, respawn correlation ID, players/channels/members/lookups, reconcile/publish elapsed time, snapshot size estimate, recipient count, and duplicate-window count;
11. `FRIENDLY_AI_PROTECTION`
   - machine role, supported/local/friendly entity counts, handler attach/reuse/remove rates, validation-worker starts/concurrency/elapsed time, and `HandleDamage` early-filter counts;
12. `NORMAL_AO_CLEANUP`, required for the frozen-B/current R19 path
   - AO/Defend configuration, which delay branch fired, timestamps for AO deactivation/Defend start/completion/cleanup start, initial/deferred/`allDead` candidate counts and scan time, candidate owners and HC stages, separately timed attachment/object/group/unhide counts, and total elapsed;
13. `PHASE`
   - objective lifecycle, cleanup, remote-exec/intel aggregation, and other candidate hot-path durations only when above a threshold.

### Design requirements

- Do not log every loop item unconditionally; aggregate and emit slow outliers.
- Do not serialize full object/variable payloads into the RPT.
- Use stable correlation IDs that do not depend solely on display names.
- Record stage-entry time, not just current stage, so two-to-five-minute stalls are visible.
- Never treat HC slot/logic entities as connected-process truth; emit slot state and authoritative manager/network state separately.
- Record unscheduled and scheduled health separately. This is essential to distinguish engine frame stall from mission-scheduler starvation.
- Keep diagnostics behind a mission parameter/server flag and measure the diagnostics' own overhead in B0/L1.
- Apply the shared combined-release limits: independently below 20 steady freeze lines/minute and 0.5 MB/hour per server/HC, and 2 KB/second combined steady traffic. The 100-lines/minute session ceiling is enforced locally as 60 on the server (20 freeze-critical, 20 other freeze, 20 cargo) plus 10 for each of at most four HCs; level-1 clients emit no diagnostic RPT. The byte limit can make the effective line rate lower.
- Use the reconstructed frozen-B served mission source, or a reviewed descendant, as the instrumentation base. Give every unpublished difference a reviewed disposition; preserve known HC whitelists unless direct server-source evidence or runner intent shows they should be superseded.

## Production incident collection checklist

For the next event, preserve a common interval from at least five minutes before onset through ten minutes after recovery or restart.

### Before the next session

- Hash and archive the exact deployed PBO.
- Archive the exact production `@Apex_cfg`, record `baseLayout`, and hash `parameters.sqf`.
- Capture repository commit/dirty state used to build it.
- Save server and every HC launch arguments, `server.cfg`, `basic.cfg`, `loopback`/`localClient` settings, profile names, and PID-to-role mapping.
- Fingerprint loaded `-mod`/`-serverMod` sets and resolved addon/class availability on server and every HC.
- Synchronize host clocks and record timezone/NTP state.
- Enable server, each HC, and external process/resource telemetry with adequate retention.
- Make RPT log rotation/collection part of the admin restart procedure.

### At freeze onset

- Record exact wall-clock onset, reporting player(s), perceived symptom, player count, active objective, and whether clients can still chat/move/connect.
- Do not immediately discard HCs; record their authoritative connection/heartbeat state, slot/logic state, FPS, ownership counts, stage-vector/oldest-queue age, and process responsiveness first if operationally safe.
- Capture server and HC CPU by core/thread, working/private memory, handles, disk IO, network throughput/queues, and process uptime.
- Capture a server dump/profile and HC dumps if the processes are responsive enough and the operational procedure permits it.
- Record any HC disconnect/reconnect, mission transition, mass cleanup, objective completion, or large player JIP wave in the preceding five minutes.

### After recovery or restart

- Preserve rather than overwrite all server/HC RPTs and dump/profile artifacts.
- Record whether recovery was gradual, sudden, or caused by restart, and the exact duration.
- Note which metrics recovered first: engine frames/FPS, scheduled heartbeat, HC stage progress, AI movement, networking, or client interaction.
- Hash artifacts and attach a one-line incident ID used across all files.

Existing log markers already available without the proposed patch include the server report at roughly 60 seconds, HC FPS/script diagnostics at roughly 15 seconds, client report at roughly 60 seconds, and HC registration/disconnection messages. They are too coarse alone but should be retained.

## Proposed fix and experiment sequence

Behavior changes should follow evidence collection and be introduced one variable at a time.

### 0. Reconciliation completed; confirm operational inputs

The freshly served/client-downloaded frozen-B PBO is preserved and its mission source is reconstructed at `5c1ffb3`; reviewed corrections extend through `9f61e06`, including the deployed HC whitelists and exact-live Normal-AO cleanup. Before production, confirm the B hash against the selected server-disk PBO and inventory the resolved mission selection, loose overlays, external configuration, and server/HC launch/mod inputs. Record those identities and the output PBO hash in the release manifest.

### 1. Add observation-only diagnostic commits

Implement the instrumentation contract without changing allocation, respawn, or ownership behavior. Repeat B0/L1 against the production-form patch to quantify its overhead, then use a short production canary. The corrected branch contains documented post-live fixes but excludes the pending air-defense feature branch, so use the combined proposal's R0/R1/R2 gates and do not describe the whole cutover as diagnostics-only.

### 2. After diagnostic evidence, stabilize and bound HC transfer/recovery

Only after the observation release captures an HC queue/health signature should the first behavioral experiment preserve HCs while putting explicit backpressure around new placement and recovery:

- require a newly connected/reconnected HC to pass mission-ready plus several consecutive heartbeat/stability checks before it receives groups;
- stop starting new transfers when the server heartbeat is late or an HC heartbeat/locality state is unstable;
- separate immediate safety bookkeeping on HC loss from gradual reassignment work;
- use a persistent fair queue with both a group-count and elapsed-time budget per manager cycle;
- report current depth, oldest and percentile queue age, enqueue reason, completions per minute, retries, and one-tick return bursts;
- keep pending handshake progress responsive while separately rate-limiting new placements;
- retain explicit variable whitelists, sticky ownership, disconnect/reconnect cooldown, and bounded state/loadout reapplication;
- do not permanently reduce HC capacity or route all AI back to the dedicated server.

P1 should compare the same H2 disconnect/reconnect workload with and without the stability/budget policy. It must show bounded heartbeat/frame cost and finite queue service time; merely making recovery slower is not success. Production canarying still requires a real incident signature because H2 reproduced queue timing but not the freeze.

### 3. Deduplicate and gate fork-only high-population work

Time both deployed systems before changing semantics. If private-channel timings confirm duplicate respawn work, make the server `EntityRespawned` path authoritative, replace the second client full sync with a correlated acknowledgement/delta, cache one UID-to-unit map, and publish only affected recipients. Preserve explicit full sync for JIP or state recovery.

If friendly-protection timings show per-machine attachment/worker pressure, gate handler installation by eligibility and locality, use a bounded `Local` transition path for ownership changes, and skip validation workers when tracked handler state is already current. Test damage/collision protection across server, clients, HCs, JIP, respawn, and ownership migration before canarying.

Apply these as separate experiments. Their absence from the historical trees makes them valuable current-fork candidates, but neither has yet been linked to a freeze.

### 4. Bound the vehicle monitor

If production traces show that the live registry—whether the approximately 100-109 lower-layout path, the 381-entry placed-layout initialization, or a later-expanded state—competes materially during an incident, replace the monolithic full sweep with a persistent ring cursor and an explicit entry/time budget per tick. Candidate shape:

- process at most a small batch, such as 16-32 entries, before yielding;
- separate fast due/active entries from slow dormant/simple-object checks;
- cache `allPlayers`, pilot lists, and other invariant per-pass data once;
- avoid proximity/crew/hitpoint work until a cheap due-state predicate passes;
- preserve maximum respawn latency with a bounded full-cycle service target;
- measure backlog depth and oldest-entry service age.

This change must preserve vehicle respawn, FOB rules, state restoration, textures, tickets, wreck behavior, carrier behavior, and spawn-menu ownership. B0/L1/H0 show strong scaling but no stall, so this should remain an amplifier-hardening change unless production timing elevates it.

### 5. Enforce server/HC content parity

Make startup fail or warn loudly when server/HC mod, addon, or required-class fingerprints differ. This is valuable operational hardening even if it does not reproduce the freeze.

### 6. Canary and rollback criteria

Compare the same mission/layout, HC count, AI topology, and load window. Roll back if any of the following regress:

- monitor oldest-entry service age or vehicle respawn latency;
- AI locality stability or HC utilization;
- server scheduled heartbeat and frame gaps;
- network traffic or RPT volume;
- vehicle/FOB/spawn-menu state correctness.

Success requires more than one freeze-free session. Track incident rate per player-hour and per high-population hour across matched mission versions.

## Current conclusions by evidence class

### Proven

- Frozen B and the old `origin/main`/feature-tip sources were materially out of sync; the exact-live mission source is now reconstructed at `5c1ffb3`, but canonical main and production have not yet been updated from this branch.
- Frozen B includes HC variable-whitelist behavior that was absent from the old feature tip; it is now present in the reconciled source.
- Private-channel and friendly-AI protection source files are absent from both historical trees and present in cached current deployment/repository; their compared current implementations are identical after line-ending normalization.
- Cached A and frozen B contain the deferred/forced Normal-AO cleanup path; it is absent from Jul 25/Jul 18, older history, and the original `origin/main` baseline, and is reconstructed as exact-live R19.
- Current static respawn paths can request both server `SERVER_SYNC` and client `SYNC`; each private-channel path performs full reconcile/publish work.
- Current private-channel publish code nests players, channels, members, repeated `allPlayers` lookups, and per-player remote fanout.
- Friendly-AI protection post-init runs per machine and its `EntityCreated` path installs/validates supported Man/UAV handlers before friendly-side filtering in `HandleDamage`.
- Each selected historical mission tree contains 1,101 files; 1,100 are byte-identical and only `mission.sqm` differs.
- Their entity count rose from 231 to 474 and `mission.sqm` vehicle-registration initializers from 97 to 309.
- The current mission has 366 `mission.sqm` registered-vehicle initializers, only four protected; local runtime profiles measured 100, 366, and 381 live entries. Static initialization predicts 100-109 for `baseLayout=0` or 381 for nonzero `baseLayout`, before later runtime additions; L1's 366 state remains unexplained.
- The vehicle monitor performs an all-entry traversal with `sleep 0.01` per entry.
- The declared 30-second HC allocation delay does not gate the observed allocation block in static code.
- B0 did not freeze or log a frame gap over 250 ms in approximately 113 seconds.
- B0 ordinary 100-entry monitor passes consumed approximately 3.57-3.62 seconds of scheduled wall time.
- L1 ordinary 366-entry monitor passes consumed approximately 13.070-13.125 seconds but did not stall frames or the five-second heartbeat.
- H0 sustained 100 one-unit synthetic groups and 381 runtime monitor entries without a freeze or frame gap over 250 ms.
- H2 measured approximately one completed one-unit group per HC every 6.5-6.9 seconds.
- H2 returned 22 groups to stage 0 in one manager tick after one HC disappeared, then retained a large pending queue about 100 seconds later.
- H2 did not reproduce a hard freeze; its post-connect/drop frames, heartbeat, transfer progress, and ownership calls remained healthy, with zero transfer failures.
- A-derived minimal group-whitelist snapshots were approximately 0.002 seconds in H2.
- A healthy low-population client session can sustain extensive warning spam without a freeze.

### Observed but not captured

- Freeze frequency rises materially around 40-70 players and can begin near 20.
- Typical events last two to five minutes and recover gradually.
- Removing HCs substantially reduced events in one test period.
- The heavily modified mission family is associated with the return of freezes.
- Calendar age and population exposure are confounded; neither version nor population correlation has been isolated causally.

### Inferred

- Mission layout expansion is a likely server/scheduler load amplifier.
- Population likely exposes expensive monitor/AI/ownership branches rather than acting as a simple direct cause.
- HC transfer/recovery can create minutes of serialized work and may amplify an already stressed production server.
- The H2 recovery shape is consistent with the reported gradual recovery, but matching timescale is not proof that the production stall starts in the HC queue.
- Duplicate private-channel respawn publication and per-machine friendly-protection entity work are plausible current-fork population multipliers, but static scaling shape is not runtime causation.
- The served-deployment Normal-AO cleanup is a plausible fork/deployment-family trigger and could interact with HC ownership recovery, but its cost and incident timing have not been measured.

### Unknown

- Whether engine frames stop during the production event or only scheduled mission/network progress stops.
- Which script/engine subsystem first becomes late.
- HC stage distribution and stage age at onset.
- Whether an HC disconnect, JIP wave, objective event, cleanup, or vehicle activation precedes the freeze.
- Whether a production incident aligns with Normal-AO completion, the no-Defend 30-second delay, the wait-for-Defend-plus-30-second delay, or one specific forced-cleanup traversal present in the served frozen-B payload.
- Whether every HC has exact content/config parity.
- Whether private channels are enabled in production and what their respawn-correlated reconcile/publish/fanout cost is.
- Whether friendly-protection handler/worker rates spike before a production event.
- Whether production-only vehicle activation/proximity/respawn branches make the registry materially more expensive than L1/H0.
- Whether the actual production `baseLayout`, Cargo10/carrier/destroyer flags, later runtime additions, and live registry correspond to the approximately 100-109 lower-layout path, the 381-entry placed-layout initialization, or another state.
- Whether the provisional historical PBO labels match actual incident deployments.

## Immediate next steps

1. Confirm the frozen-B hash against the direct server-disk PBO and inventory production `@Apex_cfg`, mission selection, loose overlays, launch arguments, HC topology, and mod/content parity; the mission-source reconciliation itself is complete.
2. Implement the default-off shared diagnostic contract described in the [combined release proposal](2026-08-30-combined-diagnostics-release.md), preserving approved reconciliation dispositions and correcting the slot-versus-connected-HC fields; include the required frozen-B/current Normal-AO cleanup hook plus private-channel mode/fanout and per-role friendly-protection timing.
3. Prepare the server/every-HC incident bundle and admin checklist before the next high-population session.
4. Run the remaining four-HC, infantry-topology, stable-era, respawn-fanout, and entity-creation comparison cells as supporting mechanism tests. Run full Normal-AO-cleanup timing on the frozen-B/current path.
5. After diagnostic evidence identifies the HC signature, test the heartbeat/stability gate and time-budgeted transfer/recovery queue against H2 on a separate behavioral experiment branch; it neither enters nor blocks the initial observation canary.
6. Use production signatures to choose independent private-channel, friendly-handler, and vehicle-monitor canaries rather than combining unproven behavior changes.

All local test PIDs are stopped and the hashed runtime artifacts are retained. The current evidence supports a focused instrumentation patch and a bounded HC-recovery experiment; it does not support declaring either HCs or the vehicle monitor the sole cause of the hard production freeze.
