# Instrumentation overlay (WO-0003)

A default-off diagnostic overlay for the legacy mission. It produces the parity corpus described in
`docs/corpus-format.md` and answers, from a live session, the questions theme T3 could only rank
from source: which loop consumed the frame, whether a stall is a frame block or scheduler
starvation, how often the position sampler hits its 30 second deadline, and how large the
positional records actually get.

Nothing here modifies `legacy/`. The patch set is applied to a copy.

```
tools/instrumentation/
  patches/            seven unified diffs, one per concern, applied in numeric order
  overlay/            authoring source for the seven files the patches add
  apply.ps1           applies the patch set to a copy of the baseline (no git, no patch.exe)
  make-patches.py     regenerates patches/ from overlay/ and the read-only baseline
  verify.py           asserts the applied copy is exactly baseline + 7 new + 8 touched files
  fixture/            the exit test: a dedicated-server fixture mission and its runner
```

---

## 1. Quick start

```powershell
# build an instrumented copy under artifacts/instrumented/Apex_framework.terrain
.\tools\instrumentation\apply.ps1 -Force

# prove it: compile smoke, every line type on, no line at all off, overhead numbers
.\tools\instrumentation\fixture\run-fixture.ps1
```

Everything is off after `apply.ps1`. To switch an instrument on, add rows to the key table in
`@Apex_cfg\parameters.sqf` — the `} forEach [` at `:305` of the upstream copy in
`legacy/upstream-inputs/@Apex_cfg/parameters.sqf`, which is the file's own idiom. The third element
must stay `FALSE`: the source configuration remains private to the dedicated server. HCs receive
only an authenticated, fixed-shape snapshot of the six normalized Boolean gates:

```sqf
{
	missionNamespace setVariable _x;
	diag_log str ([_x # 0,_x # 1]);
} forEach [
	// ... the existing rows ...
	['QS_missionConfig_diagHeartbeat',TRUE,FALSE],
	['QS_missionConfig_diagLoopTiming',TRUE,FALSE],
	['QS_missionConfig_diagRpcLog',FALSE,FALSE],
	['QS_missionConfig_diagStateSnapshots',TRUE,FALSE],
	['QS_missionConfig_diagSafePos',TRUE,FALSE],
	['QS_missionConfig_diagScriptHistogram',TRUE,FALSE]
];
```

A key opens its gate only when its value is **exactly** the Boolean `TRUE`. `1`, `"TRUE"`, `[1]` and
`2` all leave the gate closed; the fixture's `exact` mode asserts that. The keys are additive to
`@Apex_cfg` and rename nothing, so the `docs/invariants.md` rule that the 121 `QS_missionConfig_*`
names may not be renamed is untouched.

When any HC-supported gate is on and an HC reaches mission-ready state, its existing case-98
registration request identifies a live `HeadlessClient_F` target. Arma reports
`isRemoteExecuted = FALSE` and `remoteExecutedOwner = 0` for HC-originated calls, so that request
cannot be sender-bound; it is a readiness signal, not an authorization boundary. A human remote
caller still has a nonzero owner that cannot match a live HC owner. The non-secret reply goes only
to the validated HC owner and uses protocol `[1,[heartbeat,loop,rpc,FALSE,safePos,scripts]]`. The
receiver accepts a non-JIP call only from server owner 2, only on a no-interface non-server process,
and validates all six values before changing any gate. State snapshots remain server-only. This
handshake runs again for every late join or reconnect; it does not use public variables or the JIP
queue.

The deployment's own `@Apex_cfg` is still owner work (`docs/phase-1.md`); the copy under
`legacy/upstream-inputs/` is the upstream reference for the file's shape, not the deployed values.

---

## 2. What the patches do

| Patch | Concern | Adds | Touches |
| --- | --- | --- | --- |
| `0001-diag-runtime.patch` | overlay root: reads the six keys once, publishes six gates, launches the enabled periodic instruments | `fn_diag.sqf` | `description.ext` (+1 line), `fn_init.sqf` (+1 line) |
| `0002-heartbeat.patch` | instrument 1, 1 s server heartbeat | `fn_diagHeartbeat.sqf` | `description.ext` (+1) |
| `0003-loop-timing.patch` | instrument 2, pass timing at five loop sites | `fn_diagLoop.sqf` | `description.ext` (+1), `fn_core.sqf` (+6), `fn_AI.sqf` (+2), `fn_aoDefend.sqf` (+2) |
| `0004-rpc-log.patch` | instrument 3, dispatcher decision log | `fn_diagRpc.sqf` | `description.ext` (+1), `fn_remoteExec.sqf` (+1), `fn_remoteExecCmd.sqf` (+2) |
| `0005-safe-position.patch` | instrument 4, safe-position deadline failures | `fn_diagSafePos.sqf` | `description.ext` (+1), `fn_findRandomPos.sqf` (+2) |
| `0006-script-histogram.patch` | instrument 5, 60 s active-script histogram | `fn_diagScripts.sqf` | `description.ext` (+1) |
| `0007-state-snapshots.patch` | instrument 6, 30 s positional-record snapshots | `fn_diagState.sqf` | `description.ext` (+1) |
| `hc-telemetry-follow-up` | validated server-to-HC gate handoff and HC-safe collector startup | `fn_diagConfigureHC.sqf`, `fn_diagStart.sqf` | `description.ext`, `security.hpp`, `fn_diag.sqf`, `fn_init.sqf`, `fn_remoteExec.sqf`, `fn_AI.sqf`, heartbeat/scripts collectors and local gate reads |

The original seven-patch overlay is additive. The HC telemetry follow-up deliberately refactors the
launcher and heartbeat guard, so the integrated mission is no longer insertion-only.

Two design rules the work order sets, and how they are met:

- **No per-frame handler on the server.** Every periodic instrument is a scheduled loop with a
  `uiSleep` tail. `addMissionEventHandler`, `onEachFrame` and `displayAddEventHandler` do not appear
  in the overlay.
- **No collector, message or log output when off.** The process-local gates are defined as `FALSE`
  at preInit on **every** machine (`fn_diag.sqf` is `preInit = 1`), so each hot-path guard is a
  Boolean read and never an undefined-variable error. They live in `localNamespace`, which prevents
  a networked `missionNamespace` variable from changing the diagnostic state. An all-off HC
  registration receives no diagnostic response, starts no diagnostic script and writes no
  `[DIAG ...]` line. Section 4 records the original guard benchmark and its limitation.

### 2.1 Where the loop-timing sites are

The five sites named by `partitions/P01-server-core.md` and theme T3:

| Name | Site in the baseline |
| --- | --- |
| `core.main` | `fn_core.sqf:1370` (top) / `:5769` (bottom, above `sleep 3`) |
| `core.vehicleMonitor` | `fn_core.sqf:3228` / `:3764` — the `QS_v_Monitor` walk, `sleep 0.01` per entry |
| `core.garbage` | `fn_core.sqf:3847` / `:4008` — the `QS_garbageCollector` drain |
| `ai.main` | `fn_AI.sqf:700` (below the head `uiSleep`) / `:2472` |
| `aoDefend.main` | `fn_aoDefend.sqf:427` / `:1483` (above `sleep 1.5`) |

Two lines per site, as the work order requires. `ms` includes the body's own yields, which is the
point: T3's finding is that the realised period, not the declared interval, is the real cadence.

### 2.2 Where the RPC sites are

The work order says "at the entry" of the two dispatchers. The accept/reject verdict does not exist
at statement one — it is produced by the existing validator in the entry prologue — so the log sits
at the earliest point where the verdict is known and **before anything is dispatched**:

- `fn_remoteExec.sqf`, immediately above `if (_rejectRequest) exitWith {};` at `:159`.
- `fn_remoteExecCmd.sqf`, immediately above the same statement at `:176`, plus one line inside the
  earlier reject-only `exitWith` at `:111` so shape, rate and batch rejections are not lost.

A batched `QS_fnc_remoteExecCmd` call logs one line per element and none for the batch, because the
batch path exits at `:125` before the verdict site.

---

## 3. The exit test

`fixture/run-fixture.ps1` runs a local dedicated server three times against a fixture mission that
stages the eight touched and seven added files out of the instrumented tree (verified by SHA-256),
then asserts on the RPT. It installs the fixture under `MPMissions` and removes it again in a
`finally` block, and it stops the server process before returning.

This committed fixture and the dated results below cover the original seven-patch overlay. They do
not by themselves validate `hc-telemetry-follow-up`; release validation for that follow-up must also
compile every integrated function and exercise a real late-joining HC, an HC reconnect, multiple
concurrent HCs, and an all-off run that produces no diagnostic response or log line.

| Mode | Keys | Must produce |
| --- | --- | --- |
| `on` | all six exactly `TRUE` | every line type: `INIT`, `HB`, `LOOP`, `RPC`, `SAFEPOS`, `SCRIPTS`, `STATE` |
| `off` | absent | no `[DIAG` line at all |
| `exact` | present but `1`, `'TRUE'`, `[1]`, `'true'`, `2`, `[TRUE]` | no `[DIAG` line at all |

It also checks, inside the mission:

- **T-1 compile smoke.** WO-0002 has not shipped, so the fixture uses the review's earlier approach
  (theme T6 section 8): the seven added files, the seven touched `.sqf`
  files and two fixture-only probes are run through `preprocessFileLineNumbers` + `compile` and
  asserted to yield `CODE` -- sixteen files. `description.ext`, the eighth touched file, is covered
  by CfgConvert instead.
- **CfgConvert** over the instrumented `description.ext`, which is the half of T-1 a mission cannot
  test from inside — this is what catches a malformed `CfgFunctions` edit.
- The six gates are `FALSE` at preInit before any key is read, and take their expected value after
  `QS_fnc_diag` runs.
- `_fnc_scriptNameParent` is published by the engine's function framework, which is what
  `[DIAG SAFEPOS] caller=` depends on. Two fixture-only probe functions assert that a callee sees
  its caller's name; the run records `got=QS_fnc_probeParent`.
- The RPC log's 200-lines-per-second limiter drops lines under a 500-call burst.
- `[DIAG STATE]` measures a real self-widening tuple: the fixture seeds `QS_v_Monitor` with a
  16-slot and a 23-slot row and the run asserts the line reads `count=2 arity=[16,23]`.

### Result, 2026-09-02

```
cfgconvert/instrumented-description.ext                     PASS
on     : passes=29 failures=0 scriptErrors=0
         DIAG total=6305 HB=3073 LOOP=3004 RPC=200 SAFEPOS=2 SCRIPTS=1 STATE=24 INIT=1
         (3000 of the HB lines and 3000 of the LOOP lines are the overhead benchmark)
off    : passes=29 failures=0 scriptErrors=0   DIAG total=0
exact  : passes=29 failures=0 scriptErrors=0   DIAG total=0
RESULT: PASS
```

Evidence: `artifacts/instrumented/fixture-runs/20260902-212103/` (all three modes) and
`.../20260902-212341/` (a second `on` run, for benchmark variance). Each run directory holds the
server RPT, the filtered `diag.log`, and `result.txt`. The runner deletes the staged mission and the
server profile after extracting them, because both are verbatim copies of baseline mission files and
`description.ext` carries a Steam UID whitelist.

`apply.ps1` output is verified byte-for-byte against the staged tree and against the baseline by
`verify.py`: 1,273 files, 7 added, 8 modified, 0 removed, every other file identical to
`legacy/baseline/`.

---

## 4. Overhead

All figures in this section were measured before `hc-telemetry-follow-up` changed the gate storage
and heartbeat fields. Treat them as a historical baseline; the integrated overlay needs a fresh
populated server/HC benchmark before any figure is used as a current cost claim.

Measured on the fixture, on the dedicated server, in **unscheduled** context (`isNil {...}`) so the
engine's 3 ms time slice (engine fact F5) cannot land inside the measured window and charge
suspension time to the instrument. Each figure is 90,000 calls (off paths) or 3,000 calls (logging
paths) split into repeats, because `diag_tickTime` resolves to about a millisecond. Two independent
runs are shown because run-to-run variance is larger than the quantity being measured for the cheap
paths.

| Measurement | Run A | Run B | Net of the harness floor |
| --- | ---: | ---: | ---: |
| harness floor: `call {}` | 0.267 µs | 0.311 µs | — |
| loop-timing site pair, **gate off** (the two inserted lines) | 0.656 µs | 0.733 µs | **0.39 – 0.42 µs per pass** |
| RPC site, **gate off** (one inserted line) | 0.489 µs | 0.500 µs | **0.19 – 0.22 µs per dispatched call** |
| loop-timing site pair, **gate on** (one logged line) | 43.3 µs | 40.0 µs | **40 – 43 µs per pass** |
| original server-only heartbeat line (`format` + `diag_log`) | 34.0 µs | 37.3 µs | **34 – 37 µs per line** |
| bare `diag_log` of a constant string | 17.3 µs | 22.0 µs | — |

Run A is `artifacts/instrumented/fixture-runs/20260902-212103`, run B is `.../20260902-212341`.

The bare-`diag_log` row is the floor for every instrument. The original heartbeat number predates
the HC follow-up's population/locality fields and must not be used as its current cost: the expanded
heartbeat also walks `allPlayers`, `allUnits` and `allGroups` once per second on each instrumented
process. The gate-off figures also predate the move from direct mission-global reads to
`localNamespace getVariable`; retain them as historical measurements, not current cost claims.

### 4.1 Steady-state cost at production cadence

Line rates from the sites' own nominal cadences (`fn_core.sqf:5769` `sleep 3`, `:509`
`_vRespawn_delay = 5`, the 45 s cleanup gate, `fn_AI.sqf:700` `uiSleep (random [2.5,3,3.5])`,
`fn_aoDefend.sqf:1483` `sleep 1.5`). Realised cadences are slower than nominal (that is the finding
the corpus exists to measure), so these are upper bounds.

| Instrument | Lines/s | CPU per second | Share of wall clock |
| --- | ---: | ---: | ---: |
| heartbeat | 1.0 per process | not yet remeasured; O(players + units + groups) | — |
| loop timing, five sites | ~1.55 | ~65 µs | 0.0065 % |
| state snapshots | 0.4 | ~14 µs + `str` cost, see below | — |
| script histogram | 0.017 | ~1 µs + a walk of `diag_activeSQFScripts` | — |
| safe-position failures | event-driven, expected ≪ 1/s | ~35 µs each | — |
| RPC log, saturated at its cap | 200 | ~6 ms | **0.6 %** |

The expanded heartbeat needs a populated server/HC benchmark before assigning it a production CPU
percentage. At one line per second it adds about 14,400 lines per instrumented process over a
four-hour recording. With every gate off, no instrument thread exists, but the hardened gate-read
cost must be remeasured before assigning it a current number.

Two cautions:

- **The RPC log is the expensive one.** At its 200 lines/s cap it costs 0.6 % of wall clock and
  writes on the order of 250 MB of RPT over a four-hour session. Leave it off for the long recording session
  and switch it on for a bounded window when the endpoint registry (WO-0004) needs live call
  evidence.
- **State snapshots and the expanded heartbeat scale with mission state.** The heartbeat performs
  bounded linear counts over players, units and groups once per second. For state, `hashValue (str
  <record>)` is linear in the record's size, and on a populated server `QS_v_Monitor` holds 366 rows
  from `mission.sqm` and `QS_ST_X` holds 87 mixed data/`CODE` slots. The fixture's records are two
  rows, so the 14 µs/s above is a floor. It is why the instrument is 30 s, spreads its twelve
  records with `uiSleep 0.05`, and is off by default. During the recording session, watch
  `[DIAG LOOP] core.main ms=` for a step change at each 30 s boundary; if there is one, drop the two
  largest records from `fn_diagState.sqf`'s table.

Without an in-engine baseline of the un-instrumented mission's god-loop pass time, these are costs
in isolation rather than a measured delta on the real mission. WO-0002's compile smoke and the
recording session together give the delta; that is the next measurement, not this one.

---

## 5. Regenerating and reviewing the patches

`patches/` is generated. `overlay/` is the authoring source for the seven added files; the twenty-three
inserted lines live in `make-patches.py` as anchored insertions, each asserting the exact text of the
line it inserts after, so a drift in the baseline fails loudly instead of patching the wrong place.

```powershell
python .\tools\instrumentation\make-patches.py    # overlay/ + baseline -> patches/
.\tools\instrumentation\apply.ps1 -Force          # patches/ -> artifacts/instrumented/
python .\tools\instrumentation\verify.py          # byte-for-byte check against the baseline
```

The series is **cumulative**: patch N is a diff against the tree after patch N-1, because several
patches insert adjacent lines in `description.ext`'s alphabetical `CfgFunctions` list. Apply them in
numeric order. `apply.ps1 -Only '000[12]-*'` builds a copy carrying only the heartbeat, which is the
useful subset for a first recording.

`apply.ps1` is a self-contained unified-diff applier: it verifies every hunk's context and computes
every result before it writes anything, so a context mismatch leaves the destination untouched
rather than half-patched. It does not shell out to git or `patch.exe`.

---

## 6. Known limitations

1. **`caller=` degrades to `unknown`** when `QS_fnc_findRandomPos` is called from something that is
   not a `CfgFunctions` function — for example directly from a `mission.sqm` init string or from a
   `spawn`ed code block. The fixture proves the mechanism works; it cannot prove every one of the 77
   call sites is a function.
2. **A batched `QS_fnc_remoteExecCmd` call is logged per element, not per batch.** Rates computed
   from `[DIAG RPC]` count elements.
3. **`[DIAG LOOP] aoDefend.main` skips a pass on cancellation**, because `fn_aoDefend.sqf:1480`'s
   `exitWith` fires above the bottom instrument. The gap is visible in the `pass=` counter and is
   expected, not a defect.
4. **HC telemetry is process-local.** Heartbeats, `ai.main`, script histograms, RPC decisions and
   safe-position failures can write to each HC's own RPT; state snapshots remain server-only.
   Collect every process RPT and keep them as separate files in one session bundle.
5. **The RPC limiter's dropped lines are not counted.** Counting them would need a write on the
   dropped path, which is the path that has to stay cheap. A second saturated at exactly 200 lines
   is a floor, not a total.
6. **`hashValue` returns an opaque token, not a number**, on the engine in use. Compare it for
   equality; never order it.
7. **The log covers server-local dispatcher calls as well as remote ones**, because the sites sit
   outside the validator's `if (_clientToServer)` block. Local calls and HC-originated remote calls
   both carry `owner=0` because of an engine limitation; they share the 200 lines/s budget with
   ordinary remote traffic and cannot be separated by `owner=` alone.
8. **A malformed `QS_fnc_remoteExecCmd` call is not logged.** `fn_remoteExecCmd.sqf:130` exits for a
   call with fewer than two elements or a non-string verb, above the verdict site.
9. **The overhead figures are costs in isolation.** They are not a measured delta against the
   un-instrumented mission under load, which needs WO-0002 plus a recording session.
