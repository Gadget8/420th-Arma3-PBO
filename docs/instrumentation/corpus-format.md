# Parity corpus format

The corpus is the parity oracle for every phase after Phase 1. It is produced by the WO-0003
instrumentation overlay (`tools/instrumentation/`) applied to the legacy mission, recorded from a
live session, and replayed against the rewrite. This document is the contract between the producer
(the overlay) and every consumer (the replay harness, the parity report, any ad-hoc analysis).

A corpus is **one RPT per instrumented process plus one manifest**: the dedicated-server RPT and,
when HCs are enabled, every HC RPT from the same session. The overlay writes only `diag_log` lines;
it opens no file, socket or database and adds no per-frame handler.

---

## 1. What a corpus is

| Part | Produced by | Shape |
| --- | --- | --- |
| `session-server.rpt` | the dedicated server, unmodified | the whole server RPT, verbatim |
| `session-hc-<n>.rpt` | each headless-client process, unmodified | one whole RPT per HC |
| `manifest.json` | the recording operator | provenance: see section 5 |

Each RPT is kept whole and unfiltered on purpose. The overlay's lines are interleaved with the
mission's own diagnostics (`***** DEBUG ***** SAFE POS FAILURE`, the `SERVER REPORT` block at
`fn_core.sqf:1391`, script errors), and the ordering between them is evidence. A filtered copy is a
derived artefact, never the corpus. Never concatenate process RPTs: their local event order and
`diag_tickTime` domains are independent.

---

## 2. Line grammar

Every overlay line is one `diag_log` call, so in the RPT it appears as

```
HH:MM:SS "<line>"
```

where `<line>` is the grammar below. The timestamp and the surrounding quotes are the engine's, not
the overlay's; a parser must strip them. Inner double quotes are doubled by the engine when a
logged string contains an array of strings.

Common rules:

- Every line begins with `[DIAG <TYPE>] `. `<TYPE>` is one of `INIT`, `HB`, `LOOP`, `RPC`,
  `SAFEPOS`, `SCRIPTS`, `STATE`.
- Fields after the tag are `key=value`, space-separated, in the order given below. The order is
  part of the contract; a consumer may parse positionally.
- No value may contain a space except where noted (`[DIAG SCRIPTS] top=` and the `reason=` field,
  which is always last on its line).
- Numbers are SQF `format` output: `%1` of a Number, so `27.3038`, not `27.30`. Millisecond
  durations are `toFixed 2`.
- Booleans are `true` / `false`, lower case, as SQF `format` renders them.
- **No Steam UID appears in any line.** Identity is always the engine's network owner id
  (`remoteExecutedOwner`, `owner`), which is a small integer and is meaningless outside the session.

### 2.1 `[DIAG INIT]`

```
[DIAG INIT] enabled=[<gate name>,...] role=<server|hc> owner=<clientOwner>
```

Written once per process by `QS_fnc_diagStart` when at least one instrument is enabled. Its absence
means the overlay is present but wholly off, which is the default. `owner` is the session-scoped
network owner (2 on the dedicated server). Use this line to identify the RPT and to know which line
types it can contain. HC snapshots always force `QS_diag_stateSnapshots` off.

### 2.2 `[DIAG HB]` — process heartbeat, 1 s

```
[DIAG HB] t=<diag_tickTime> frame=<diag_frameNo> fps=<diag_fps> fpsmin=<diag_fpsMin>
          players=<count allPlayers> units=<count allUnits> vehicles=<count vehicles>
          scripts=<count diag_activeSQFScripts> role=<server|hc> owner=<clientOwner>
          serverTime=<serverTime> localUnits=<locally owned units>
          localGroups=<locally owned groups> humans=<human players> hcs=<headless clients>
```

One line per second from a scheduled loop whose tail is `uiSleep 1`. This is each process's clock
and liveness signal. Arma includes connected HCs in `allPlayers`, so `players` is retained for
compatibility while `humans` and `hcs` provide the population split needed for load analysis.
`localUnits` and `localGroups` measure the simulation load owned by that process. `serverTime`
provides an approximate cross-process alignment point; `t` remains process-local.

Two derived quantities matter and both come from consecutive heartbeats:

- **frame delta / wall delta.** `frame` is `diag_frameNo`, which advances once per local simulation
  frame. A gap in `t` with a proportional gap in `frame` is the process running slowly; a gap in `t`
  with almost no gap in `frame` is a **frame block** — the engine itself was not ticking. Engine fact
  F5 says a non-suspending loop in a *scheduled* script does not block the frame, so a frame block
  points at unscheduled context or a single expensive command, not at a spawned loop.
- **heartbeat gap.** The heartbeat is itself a scheduled script, so a gap larger than 1 s with
  `frame` still advancing means the scheduler did not get back to it — scheduler starvation, which is
  the other failure mode T3 separates. Distinguishing the two without new instrumentation was
  T3's open question 6; the heartbeat answers it directly.

### 2.3 `[DIAG LOOP]` — loop pass timing

```
[DIAG LOOP] <name> pass=<n> ms=<elapsed> items=<count>
```

Written at the bottom of each pass of an instrumented loop. `<name>` is a stable identifier, not a
file path:

| `<name>` | Site | Nominal cadence | `items` |
| --- | --- | --- | --- |
| `core.main` | `fn_core.sqf` god loop, `:1370`..`:5769` | `sleep 3` tail | `count allUnits` |
| `core.vehicleMonitor` | `fn_core.sqf` `QS_v_Monitor` walk, `:3228`..`:3764` | 5 s gate | `count QS_v_Monitor` after compaction |
| `core.garbage` | `fn_core.sqf` garbage drain, `:3846`..`:4008` | inside the 45 s cleanup | queue length at the top of the drain |
| `ai.main` | `fn_AI.sqf` main loop, `:699`..`:2472` | `uiSleep (random [2.5,3,3.5])` head | `count allUnits` |
| `aoDefend.main` | `fn_aoDefend.sqf` loop, `:427`..`:1483` | `sleep 1.5` tail | `count _allArray`, the Defend entity array |

- `pass` counts from 1 and is per name, per machine. It never resets while the mission runs, so a
  gap in `pass` between two lines of the same name is a lost pass, which for `aoDefend.main` is the
  `QS_defend_terminate` `exitWith` at `fn_aoDefend.sqf:1480` and is expected.
- `ms` is wall-clock milliseconds between the top and the bottom of the pass, `diag_tickTime` based,
  `toFixed 2`. It **includes** every `sleep`/`uiSleep` the body performed, which is the point: T3's
  central measurement is that a per-element yield costs a frame, so `ms` is the realised period and
  the declared interval is fiction. `ms=-1.00` means the bottom fired with no matching top; treat it
  as a defect in the overlay, not as data.
- `items` is the quantity the pass's cost is proportional to, so `ms` against `items` is the
  scaling law the rewrite's budgeted scheduler has to beat.

`ai.main` also runs on a headless client when its server-derived gate is enabled. The name does not
carry the process; `[DIAG INIT]`, `[DIAG HB]` and the RPT filename do. Keep every RPT separate.

### 2.4 `[DIAG RPC]` — dispatcher decision log

```
[DIAG RPC] case=<n|verb> owner=<remoteExecutedOwner> jip=<isRemoteExecutedJIP> accept reason=
[DIAG RPC] case=<n|verb> owner=<remoteExecutedOwner> jip=<isRemoteExecutedJIP> reject reason=<reason>
```

- `case` is the numeric selector for `QS_fnc_remoteExec` and the verb string for
  `QS_fnc_remoteExecCmd`. A consumer distinguishes them by type, not by a separate field.
- `owner` is `remoteExecutedOwner`: `0` for a locally originated call **and for an HC-originated
  remote call because of an engine limitation**, `2` for the server as a remote sender, and a
  per-human-client id above 2 otherwise. In that HC-originated context `isRemoteExecuted` is also
  false. It is **not** a Steam UID and is not stable across sessions.
- The verdict token is the literal `accept` or `reject` and carries no `=`.
- `reason` is empty on accept, and on reject is one of the existing validator's own strings:
  `payload shape`, `payload nodes`, `payload type`, `string length`, `rate limit`, `sender`,
  `batch length`, `batch depth`, `case 39 ownership`, `case 69 ownership`, `case 71 ownership`,
  `setOwner ownership`, `setGroupOwner ownership`, `hideObjectGlobal ownership`. The overlay invents
  no reason of its own. `reason` is last on the line because it contains spaces.

Coverage and its holes:

- The line is written where the validator's verdict exists, which is immediately before
  `fn_remoteExec.sqf:159` and `fn_remoteExecCmd.sqf:176`, and inside the early reject at
  `fn_remoteExecCmd.sqf:111`. Nothing is dispatched before it.
- A **batched** `QS_fnc_remoteExecCmd` call (`_type` is an Array, `fn_remoteExecCmd.sqf:125`) logs
  one line per element and none for the batch itself, because the batch exits before the verdict
  site. Count elements, not batches.
- The sites sit **outside** the validator's `if (_clientToServer)` block, so server-local calls and
  HC-originated calls are both logged with `owner=0`. They share the rate limit with ordinary remote
  traffic and cannot be separated by `owner=` alone.
- `accept` means the call passed the dispatcher's generic prologue validator. A case body can still
  decline it at a later case-specific guard. In particular, case 98 validates mission-ready HC
  ownership after the RPC line has already been written.
- A malformed `QS_fnc_remoteExecCmd` call is **not** logged: `fn_remoteExecCmd.sqf:130` exits for a
  call with fewer than two elements or a non-string verb, above the verdict site.
- The log is **rate limited to 200 lines per second across both dispatchers**. Dropped lines are not
  themselves reported, so a corpus containing exactly 200 `[DIAG RPC]` lines in one second is
  saturated and its RPC counts for that second are a floor, not a total. A consumer computing rates
  must check for saturation before drawing a conclusion.

### 2.5 `[DIAG SAFEPOS]` — safe-position deadline failures

```
[DIAG SAFEPOS] caller=<scriptName or unknown> ms=<elapsed> forceFind=<bool>
```

Written from the two 30 second deadline branches of `fn_findRandomPos.sqf` (`:141`, `:214`) — the
branches that give up and return the terrain's `safePositionAnchor`, a constant. This is the
instrument for T3's top-ranked stall mechanism and for its open question 4.

- `caller` is the BIS function framework's `_fnc_scriptNameParent` read at the call site, so it
  names the function that called `QS_fnc_findRandomPos` (verified on the engine: the fixture's
  `QS_fnc_probeParent`/`QS_fnc_probeChild` pair asserts it). It is `unknown` when the caller was not
  a `CfgFunctions` function.
- `ms` is the search's own elapsed time, derived from `fn_findRandomPos`'s existing `_timeout`
  variable, so it is always slightly above 30000.
- `forceFind` is the ninth argument. T3-C2 measures 48 live call sites passing `TRUE`; the corpus
  says which of them actually time out.

Each `[DIAG SAFEPOS]` line pairs with the mission's own
`***** DEBUG ***** SAFE POS FAILURE * ...` line immediately above it, which carries the search
parameters. Keep both: the overlay line names the caller, the legacy line names the query.

### 2.6 `[DIAG SCRIPTS]` — active-script histogram, 60 s

```
[DIAG SCRIPTS] total=<n> distinct=<n> top=[<name>=<count>,...]
```

`diag_activeSQFScripts` grouped by script name, largest twenty groups, descending. Scripts that
never called `scriptName` group under `unnamed`; T3 measures that as 839 of 902 files, so a large
`unnamed` count is expected and is itself a finding about the legacy tree.

`top` is an SQF array rendered by `format`, so it is the only field containing spaces and commas
inside brackets, and the engine doubles the quotes around each element. Parse it as an array
literal, not by splitting on commas.

A rising `total` across successive lines distinguishes scheduler starvation from frame blocking
without any other evidence — this is exactly what T3's open question 6 asks for.

### 2.7 `[DIAG STATE]` — positional record snapshots, 30 s

```
[DIAG STATE] name=<n> count=<elements> arity=<distinct row lengths> hash=<token>
```

One line per record per round, in the fixed order below. The records are the nine of theme T2
section 2.5, which `docs/plan-of-record.md` section 1.2 names as the entire tuple-to-hashmap
conversion job, plus the three further names the work order calls out.

| Order | `name` | Store | Why it is in the corpus |
| --- | --- | --- | --- |
| 1 | `QS_v_Monitor` | `serverNamespace` | ten producers at four arities, one consumer loop; first record to convert (T2-C3) |
| 2 | `QS_virtualSectors_data` | `missionNamespace` | 28 slots, one producer |
| 3 | `QS_virtualSectors_data_public` | `missionNamespace` | the redacted 28-slot view, read by raw index on clients (T2-C7) |
| 4 | `QS_managed_hints` | `missionNamespace` | 142 producers at two arities, cleared by the server |
| 5 | `QS_system_deployments` | `localNamespace` | 18 slots of which 9 are `CODE` |
| 6 | `QS_system_AI_owners` | `missionNamespace` | the HC owner-id list; the AI replication target set |
| 7 | `QS_AI_targetsKnowledge_EAST` | `missionNamespace` | republished up to 192 rows every 5 s regardless of change |
| 8 | `QS_ST_X` | `missionNamespace` | 87 mixed data/`CODE` slots; registration commented out at `description.ext:574` |
| 9 | `QS_garbageCollector` | `missionNamespace` | 80 producers, one drain; T3 open question 3 asks for exactly this number |
| 10 | `QS_logistics_deployedAssets` | `missionNamespace` | FOB deployable registry |
| 11 | `QS_smSuccess` | `missionNamespace` | side-mission completion, written by a client (`fn_clientInteractSecure.sqf:92`) |
| 12 | `QS_deploy_tickets` | on `QS_module_fob_flag` | the FOB respawn ticket economy, entity-scoped |

Field semantics:

- `count` is `-1` when the name is not defined in its store (and for `QS_deploy_tickets` when
  `QS_module_fob_flag` is null), `1` for a non-array value, and the element count for an array.
  `-1` and `0` are different facts: absent versus present and empty.
- `arity` is the ascending list of distinct lengths of those elements that are themselves arrays.
  `[]` means no element is an array. **More than one value is the self-widening tuple defect**
  (T2 section 2.5): a 16-slot carrier row and a 23-slot registration row in the same
  `QS_v_Monitor` renders as `arity=[16,23]`.
- `hash` is `hashValue (str <value>)`. On the engine in use this is a short opaque token
  (for example `9CaaqqJ/l1U`), **not a number**, so compare it for equality and never order it. The
  literal `0` is reserved for an absent record. Two rounds with the same hash mean the record did not
  change; that is the dirty-check signal the target's publish policy needs
  (`docs/plan-of-record.md` section 1.2).

The round is spread with `uiSleep 0.05` between records, so one round occupies about 0.6 s of wall
clock and its twelve lines carry two adjacent RPT timestamps. Group a round by proximity and by the
fixed record order, not by an exact timestamp.

`str` of a large record is the one place in the overlay whose cost scales with mission state — see
`tools/instrumentation/README.md`. That is why this instrument is 30 s and off by default.

---

## 3. Ordering and interleaving

`diag_log` writes in call order on one machine, so the RPT is a total order of overlay events on
that machine. Two consequences:

- A `[DIAG LOOP] core.main` line and every line written by subsystems inside that pass appear
  **before** it, because the bottom instrument is the last statement of the pass. To attribute a
  `[DIAG SAFEPOS]` to a god-loop pass, take the next `core.main` line below it.
- Heartbeats expose `serverTime` for approximate cross-process alignment. All other lines use the
  enclosing process's event order and `diag_tickTime`; do not compare those local tick values across
  machines or concatenate their logs.

---

## 4. Stability contract

The grammar above is what the replay harness parses. Within Phase 1 and Phase 3:

- A field may be **added** at the end of a line. A consumer must ignore unknown trailing fields.
- A field may not be renamed, reordered, or removed, and a line type may not change its tag.
- A new line type may be added with a new tag and a new gate key.
- `<name>` values for `[DIAG LOOP]` and `name=` values for `[DIAG STATE]` are identifiers; new ones
  may be added, existing ones may not be renamed.

Any other change is a new corpus format version and a new `manifest.json` `format` value.

---

## 5. `manifest.json`

Written by the recording operator, not by the overlay. Minimum shape:

```json
{
  "format": "wo0003-2",
  "recordedAt": "2026-09-02T18:00:00Z",
  "durationSeconds": 14400,
  "missionSha256": "<sha256 of the applied mission tree, per tools/instrumentation/verify.py>",
  "patchSet": ["0001-diag-runtime.patch", "...", "0007-state-snapshots.patch", "hc-telemetry-follow-up"],
  "gates": {
    "diagHeartbeat": true,
    "diagLoopTiming": true,
    "diagRpcLog": false,
    "diagStateSnapshots": true,
    "diagSafePos": true,
    "diagScriptHistogram": true
  },
  "aoType": "<QS_missionConfig_aoType in force>",
  "headlessClients": 0,
  "logs": {
    "server": "session-server.rpt",
    "headlessClients": []
  },
  "peakPlayers": 0,
  "notes": ""
}
```

`gates` must agree with the server `[DIAG INIT] enabled=` line. Each HC line must agree except that
`diagStateSnapshots` is always false there. `logs.headlessClients` must name every HC RPT collected
for the session; its length normally agrees with `headlessClients`. Record a disconnect, reconnect
or missing RPT in `notes` rather than silently omitting it.

`aoType` matters more than any other field: T3's open question 1 records that GRID, SC and CLASSIC
put entirely different stall mechanisms in play, so two corpora recorded under different `aoType`
values are not comparable.

---

## 6. Privacy

The overlay logs no Steam UID, no profile name, no chat text and no payload contents. The only
identity in the corpus is the engine's network owner id, which is assigned per connection and is
meaningless after the session ends. A corpus may therefore be committed and shared without
redaction — but the **RPT as a whole may not**, because the legacy mission's own diagnostics do log
player names, and `description.ext` carries a UID whitelist. Redact the RPT to the overlay's lines
plus the legacy lines a consumer actually needs before a corpus leaves the operator's machine, and
record what was removed in `manifest.json` `notes`.
