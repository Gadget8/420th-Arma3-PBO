# Cargo10 / HEMTT flatbed intermittent capacity investigation

Status: source/config scope narrowed; no cargo rebalance indicated; runtime transition not yet captured; combined tracing proposed
Date: 2026-08-30 (Asia/Bangkok)
Instrumentation: combined contract specified; not implemented
Coordination: [combined cargo/freeze diagnostics and deployment reconciliation](2026-08-30-combined-diagnostics-release.md)
Original investigation baseline: `a99001f666975fc7034328c66ac29fce291dca49` on `feat/deployable-air-defense-turrets`
Reconciled follow-up baseline: `9f61e06` on `reconcile/deployment-20260901`; exact frozen-B checkpoint `5c1ffb3`
Arma baseline: `2.22.154045`, Steam BuildID `24951143`

## 2026-09-01 reconciliation follow-up

This follow-up supersedes any earlier direction to change HEMTT Flatbed capacity or rebalance the in-scope purpose-built crates. The earlier controlled finding remains valid—forcing one crate to stock mass `10000` is sufficient to reproduce the rejection—but no production failure has yet captured that state, and the completed source/deployment audit shows no configured mass drift to fix.

All eight purpose-built deployable presets assign mass `2500` in all three relevant source states: `origin/main` at `149b7b9`, frozen deployment B, and current branch `9f61e06`.

| Preset | Purpose | Container class | Configured mass in main / B / current |
| ---: | --- | --- | ---: |
| 6 | Mobile SAM / Defender | `Land_Cargo10_blue_F` | `2500 / 2500 / 2500` |
| 7 | Mobile Radar | `Land_Cargo10_cyan_F` | `2500 / 2500 / 2500` |
| 12 | Forward Operating Base | `Land_Cargo10_grey_F` | `2500 / 2500 / 2500` |
| 13 | Combat Outpost | `Land_Cargo10_military_green_F` | `2500 / 2500 / 2500` |
| 14 | Patrol Base | `Land_Cargo10_light_green_F` | `2500 / 2500 / 2500` |
| 15 | Platform Module | `Land_Cargo10_sand_F` | `2500 / 2500 / 2500` |
| 16 | Mobile Respawn | `Land_Cargo10_white_F` | `2500 / 2500 / 2500` |
| 17 | Terrain Leveler | `Land_Cargo10_yellow_F` | `2500 / 2500 / 2500` |

Crates produced by packing arbitrary vehicles are explicitly outside the user-confirmed scope and must not be used to justify a change for these eight presets. The class-wide Cargo20 fallback to `5000` is not an active purpose-built deployable preset. It likewise does not justify changing Cargo10 mass or `B_Truck_01_flatbed_F` capacity.

Conclusion: **no cargo mass, carrier-capacity, or admission rebalance code commit is warranted.** Commit `5e06631` addresses a distinct spawn-menu GC hazard by preserving in-use logistics cargo, but it does not alter admission or configured mass. If the intermittent failure recurs, capture the client/server runtime transition before selecting a remediation.

### Eight-preset staging matrix

Only the eight listed purpose-built presets participate in these cells. For a stable phase, pass means both crate masses are `2500` on the dedicated server and checking client, the second native `canVehicleCargo` result is `[true,true]`, both loads succeed, two native cargo entries remain, and spawn-menu GC does not delete either crate.

| Cell | Preset coverage | Transition / load | Required observation |
| --- | --- | --- | --- |
| S1 | Each of 6, 7, 12–17 separately | Fresh same-preset pair at low population | Run the pass criteria once per preset; establishes eight clean baselines |
| S2 | `6+7`, `12+13`, `14+15`, `16+17` | Fresh mixed-purpose pairs | Proves admission is based on actual mass rather than a same-class special case |
| S3 | Each of 6, 7, 12–17 | Carry, drop, then load both | Record locality/owner and mass before/after the carry transition |
| S4 | Representative 6, 7, 12, 13, 16, 17 | Pull/winch/rope/tow transition, then load | Record attachment/rope/tow parent and mass convergence before admission |
| S5 | Each of 6, 7, 12–17 | Load both, move away through one GC pass, return, unload, and reload | Confirms `5e06631` preserves loaded cargo and the queue does not corrupt reuse |
| S6 | Each of 6, 7, 12–17 | Join-in-progress client arrives between first and second load | Compare server and new checking-client mass/state at the same stable phase |
| S7 | Representative pair from 6/7 and 12–17 | Ownership/locality transition with HCs connected, including HC disconnect/recovery | Correlate owner/local changes with the first divergent mass or admission result |
| S8 | Rotate all eight across canary windows | Repeat S1/S2 during low and high population | Compare identical build/config; population is exposure metadata, not assumed cause |

Do not “make the test pass” by reasserting mass immediately before the check: that would hide the transition under investigation. A failed cell should retain the objects and emit the proposed bounded diagnostic snapshot.

## Symptom and scope

Small `Cargo10` deployment containers—particularly the Defender, Radar, Forward Operating Base, and Combat Outpost—historically allowed two crates to be loaded on a `B_Truck_01_flatbed_F`. Intermittently, the second crate is rejected with “No cargo space in current configuration.”

The initial observation associated the regression with recent mission versions. Subsequent testing showed that the same deployed mission and game version can both succeed and fail. Failures were observed during high-population play, while a low-population retest succeeded. Historical playtime was also biased toward low-population periods, so calendar age alone is not a reliable independent variable.

Population is currently treated as a possible exposure multiplier for JIP, ownership transfer, object reuse, and network state—not as a proven direct cause.

## Executive finding

Effective crate mass is a proven sufficient reproduction and the leading runtime state to test; it is not yet the proven cause of a production incident. The controlled matrix ruled out a broad flatbed-geometry or heading failure for the tested two-crate cases, but another hidden carrier or lifecycle state could still produce the same native result.

The current engine reports:

- `B_Truck_01_flatbed_F` `VehicleTransport/Carrier/maxLoadMass`: `10000`
- Stock `Land_Cargo10_*_F` object mass: `10000`
- Intended mission override for the affected deployment crates: `2500`

One stock-mass Cargo10 therefore consumes the HEMTT’s entire ViV mass capacity. In the controlled two-crate matrix, two crates worked only when both objects retained a sufficiently low mission mass override. If either crate was evaluated at its stock mass, the pair exceeded `10000` and the second check returned `[false,true]`, reproducing the reported message.

The unresolved question is whether a production failure actually involves a crate losing—or a loading client failing to observe—the `2500` value, and, if so, where that transition occurs.

## Exact failure path

1. [`fn_clientInteractLoadCargo.sqf`](../../Apex_framework.terrain/code/functions/fn_clientInteractLoadCargo.sqf#L44) performs the check on the interacting player’s machine.
2. [`fn_canVehicleCargo.sqf`](../../Apex_framework.terrain/code/functions/fn_canVehicleCargo.sqf#L17) delegates directly to native `canVehicleCargo`.
3. The message is selected when the first element of the result is false and the second is true at [`fn_clientInteractLoadCargo.sqf`](../../Apex_framework.terrain/code/functions/fn_clientInteractLoadCargo.sqf#L51).

Bohemia defines the result as `[willFitIntoCurrentVehicle, willFitIntoEmptyVehicle]`. Thus `[false,true]` means the object could fit in an empty carrier but not in its current loaded state.

Reference: [Bohemia `canVehicleCargo` documentation](https://community.bohemia.net/wiki/canVehicleCargo)

## Controlled reproduction

Tests used an unmodded local dedicated server on Arma `2.22.154045`, `B_Truck_01_flatbed_F`, and `Land_Cargo10_blue_F` instances.

### Mass threshold matrix

| First crate mass | Second crate mass | First load | Second `canVehicleCargo` | Second load | Cargo count |
|---:|---:|:---:|:---:|:---:|---:|
| `10000` (stock) | `10000` (stock) | true | `[false,true]` | false | 1 |
| `2500` | `2500` | true | `[true,true]` | true | 2 |
| `4000` | `4000` | true | `[true,true]` | true | 2 |
| `5000` | `5000` | true | `[true,true]` | true | 2 |
| `5001` | `5001` | true | `[false,true]` | false | 1 |
| `7500` | `7500` | true | `[false,true]` | false | 1 |
| `10000` | `10000` | true | `[false,true]` | false | 1 |
| `2500` | `10000` | true | `[false,true]` | false | 1 |
| `10000` | `2500` | true | `[false,true]` | false | 1 |

This establishes a precise `10000` combined-mass boundary. It also shows that a single incorrectly initialized crate is sufficient to reproduce the symptom regardless of load order.

### Geometry, heading, and timing matrix

With both crates explicitly set to `2500`, all 96 combinations succeeded:

- four source/approach sides;
- eight pre-load headings;
- delays of `0`, `0.1`, and `1` second.

Additional tests applied the mission’s post-load absolute `setDir 270` behavior and waited up to one second before checking the second crate. With the intended mass, this did not cause a failure. Without the mass override, direction changes did not rescue the second load.

Result: a general deck-layout, approach-direction, or `setDir 270` regression is effectively ruled out for these two crates.

## Mission initialization audit

The current repository initializes the affected crates correctly:

- [`fn_spawnMenuServerSpawn.sqf`](../../Apex_framework.terrain/code/functions/fn_spawnMenuServerSpawn.sqf#L222) creates the object on the server.
- It calls `QS_fnc_vSetup` at lines 262–263 and has a direct `QS_fnc_vSetupContainer` fallback at lines 269–274.
- [`fn_vSetup.sqf`](../../Apex_framework.terrain/code/functions/fn_vSetup.sqf#L625) routes containers to `QS_fnc_vSetupContainer`.
- [`fn_vSetupContainer.sqf`](../../Apex_framework.terrain/code/functions/fn_vSetupContainer.sqf#L57) defines the eight active purpose-built cases beginning at lines 57, 76, 133, 154, 175, 196, 218, and 239; each case applies `setMass 2500` locally or through the fixed remote command wrapper.

When the crate is local, the command executes directly. Otherwise, the mission remote-executes it to the entity owner. Spawn-menu crates are created server-local, so their initial setup should use the direct branch.

In-scope recreation paths also restore the intended setup:

- [`fn_deployAssetPreset.sqf`](../../Apex_framework.terrain/code/functions/fn_deployAssetPreset.sqf) reruns setup when recreating a purpose-built deployable container.
- Legacy monitored respawns in [`fn_core.sqf`](../../Apex_framework.terrain/code/functions/fn_core.sqf) rerun `vSetup`.

No in-scope mission path was found that deliberately restores these crates to `10000`. Controlled deploy/recreate and simulation-toggle checks retained `2500`.

## Historical deployed-mission comparison

This 2026-08-30 cached comparison predates and is superseded for release identity by the frozen-B reconciliation above. Its then-current cached candidate was:

- File: `Apex_framework_420th_A.Altis.pbo`
- Cached: 2026-08-29 13:07 ICT
- SHA-256: `80AACF333A75BBCE046BA9A41CAB88F78601FF19CC88C3B90C9D8D734C4960F6`

Known-good historical comparison:

- File: `Apex_framework_420th_20260725v2.Altis.pbo`
- Cached: 2026-07-26 06:12 ICT
- SHA-256: `E7F443FADDA4A48D78E2EE42595FCD8994DD1B994C456C1FAA60BA669B322B6C`

Every directly relevant file was byte-identical between those PBOs:

| File | Shared SHA-256 |
|---|---|
| `fn_canVehicleCargo.sqf` | `42D5391014B00BFEA69250D271B6E455029D0CF74066D0A8265E2FF3FB248627` |
| `fn_setVehicleCargo.sqf` | `84CC1B871CE017846AD22AF4E85309560F1A4BA7FD0978406265A0F75B1176A1` |
| `fn_clientInteractLoadCargo.sqf` | `96A799BFF17B9F08B703F0BE9250613C8BE06999C8E80B9A793C01A81B3C40FB` |
| `fn_eventCargoLoaded.sqf` | `5E9F541669CF4282E2C6156AFCE9E943CBE156503261354FC3559F2E2F763689` |
| `fn_vSetupContainer.sqf` | `A5FA2203F3C5F6D2B9EF360AE079A2AAFA97D99159911E4097600B66AA53BE2F` |
| `QS_data_vehicles.sqf` | `1F8DAB24662240CCC4C064F0C0D9D1E199BFC60FB87C7E0B83BB097061493FA6` |

The same direct cargo functions also match cached July 10 and July 18 versions. In that historical comparison, the direct check/load/event files matched the original investigation tip after line-ending normalization. That tip added Cargo20 handling in `fn_vSetupContainer.sqf` and `fn_spawnMenuServerSpawn.sqf`, and its substantial preset-6 rewrite in `fn_deployAssetPreset.sqf` also changed the existing Cargo10 Defender lifecycle. The separate feature tip is not part of the reconciled branch.

Historical result: no recent edit to the direct loading path explained the intermittent failure. The later frozen-B audit reconciled the deployment/source mismatch and likewise found no configured mass change for the eight in-scope presets.

## Relevant Git history

- `d66ba15a1b0f7e92c4439f23c28eaf33c362b10f` — 2026-07-16, “Fixed Load Disallowed Bug”
  - Adds `QS_logistics = true` only for `B_supplyCrate_F` and `B_CargoNet_01_ammo_F`.
  - Not related to Cargo10 mass or HEMTT capacity.
- `1c2477d62293cbbc105b2a8b5018d275e932facc` — 2026-08-07, “Bulk Update (#53)”
  - Introduces the spawn menu and Cargo10 drag/carry override.
  - This is the strongest recent mission-side lifecycle change because it exposes the crates to more ownership-changing interactions.
- `933ce8d2adf4381cbc38fa7ea08e8309b8df1c51` — 2026-08-24, “New Features & Bug Fixes (#54)”
  - Changes unload finalization and cargo event-handler management.
  - Does not change Cargo10 mass, `canVehicleCargo`, or the loaded-event orientation behavior.
- `a99001f666975fc7034328c66ac29fce291dca49` — 2026-08-28
  - Adds new Cargo20 air-defense containers.
  - Does not change the existing Cargo10 mass cases.

The direct Cargo10 loading functions have no relevant change since their repository restoration in 2025.

## Engine and locality considerations

Steam updated Arma on 2026-08-27 from:

- BuildID `24672225`, engine `2.22.153995`;
- to BuildID `24951143`, engine `2.22.154045`.

The executables and `Dta/bin.pbo` changed. The HEMTT and Cargo10 vehicle-data PBOs did not. The official 2.22 and hotfix notes do not document a related HEMTT, Cargo10, `setMass`, or ViV capacity change.

Bohemia documents numeric `setMass` as local-argument/global-effect: it must be executed where the object is local and then propagates globally. The documentation does not explicitly guarantee that the override is serialized for later JIP clients or preserved through every object ownership/locality transfer.

References:

- [Vehicle-in-Vehicle configuration](https://community.bohemia.net/wiki/Arma_3%3A_Vehicle_in_Vehicle_Transport)
- [`setMass`](https://community.bohemia.net/wiki/setMass)
- [`getMass`](https://community.bohemia.net/wiki/getMass)
- [`setVehicleCargo`](https://community.bohemia.net/wiki/setVehicleCargo)
- [Multiplayer scripting/locality](https://community.bohemia.net/wiki/Multiplayer_Scripting)
- [`remoteExec`](https://community.bohemia.net/wiki/remoteExec)
- [BI developer explanation of ViV dependencies](https://feedback.bistudio.com/T170694)
- [Arma 3 2.22 release notes](https://dev.arma3.com/post/spotrep-00120)
- [2.22 hotfix notes](https://dev.arma3.com/post/spotrep-00121)

## Ownership-changing lifecycle

The August 7 Cargo10 carry override permits the affected crates to enter paths that can transfer ownership:

- [`fn_clientInteractCarry.sqf`](../../Apex_framework.terrain/code/functions/fn_clientInteractCarry.sqf#L122)
- [`fn_unloadCargoPlacementMode.sqf`](../../Apex_framework.terrain/code/functions/fn_unloadCargoPlacementMode.sqf#L192)
- [`fn_simplePull.sqf`](../../Apex_framework.terrain/code/functions/fn_simplePull.sqf#L947)
- [`fn_simpleWinch.sqf`](../../Apex_framework.terrain/code/functions/fn_simpleWinch.sqf#L933)

These paths do not explicitly reset the crate’s mass. Under documented semantics the global `2500` value should survive. They are nevertheless the best targeted checkpoints for a runtime synchronization or ownership regression.

A dedicated plus headless-client JIP/ownership probe was prepared, but the headless client did not finish joining while the normal Arma client was active. No conclusion is drawn from that incomplete test. The temporary mission copies and diagnostic processes were removed afterward.

## Findings by confidence

### Confirmed

- The reported message corresponds to native `[false,true]` from the current-load capacity check.
- The flatbed has a `10000` ViV mass limit.
- A stock Cargo10 has mass `10000`.
- The mission depends on `setMass 2500` to carry two.
- Any one crate at stock mass reproduces the exact rejection.
- Two crates at `2500` work reliably on the current engine.
- The direct files in the historical July/A comparison are identical.
- Orientation and ordinary timing do not explain the failure when mass is correct.

### Leading hypothesis

The leading hypothesis to test is that at least one crate is sometimes `10000` on the machine evaluating `canVehicleCargo`. This state has not been captured during a production failure. If it occurs, possible mechanisms are missed initialization, stale JIP/state replication, ownership-transfer state loss, or another undocumented engine lifecycle reset.

### Plausible contributing factors

- High population increases JIP, ownership transfers, network pressure, and the reuse of crates handled by other players.
- The August 7 carry/drag expansion exposes Cargo10 crates to more ownership-changing paths.
- The August engine update may have changed multiplayer PhysX state synchronization even though no such change is documented.

### Ruled out or low probability

- A direct recent edit to the compared cached `canVehicleCargo`, `setVehicleCargo`, Cargo10 setup cases, or HEMTT capacity.
- The air-defense branch as an explanation for the already observed cached-deployment failure; it is not deployed there. Its Defender preset rewrite still requires a regression matrix before the reconciled release.
- A broad HEMTT deck-geometry or absolute-heading regression.

## Candidate instrumentation contract

The second bug investigation is complete and also requires locality, ownership, scheduler, and HC evidence. Implement these checkpoints through the shared, rate-limited contract in the [combined release proposal](2026-08-30-combined-diagnostics-release.md), using the reconstructed frozen-B served mission source or a reviewed descendant. Confirm the corresponding server-disk PBO and runtime overlays separately before production.

### Checkpoints

For the eight affected Cargo10 classes in mission logistics load/unload paths, accept native ViV parents and explicitly allowlisted mission custom-attach candidates; mark the HEMTT Flatbed as the primary target case:

1. Immediately after crate creation and `vSetupContainer` completion.
2. Immediately before and after carry, pull, winch, and placement ownership changes.
3. On the interacting client immediately before `canVehicleCargo` for both first and second loads.
4. On the server at report receipt, preserving the client check-time snapshot separately from receipt-time state and network/report age.
5. After `setVehicleCargo` and in `CargoLoaded`/`CargoUnloaded` handlers.

### Common fields

- Trace schema version, server-authorized attempt ID, asset generation, phase, check/receipt `diag_tickTime` and `serverTime`, and report age.
- Execution context: `isServer`, `hasInterface`, `didJIP`, `clientOwner`.
- Parent and child: `typeOf`, `netId`, `owner`, `local`, `getMass`, position, and direction.
- Parent state: `getMass`, position/direction/vector state, native/custom capability, and `getVehicleCargo` plus attached entries capped with total/truncated fields and each child’s `netId`, class, owner, and mass.
- Native `canVehicleCargo` result versus wrapper/custom-fallback result, and native `setVehicleCargo` return versus wrapper final return/custom-attach result.
- `isVehicleCargo`, `attachedTo`, and relevant attached-object identities.
- Crate provenance and state variables, including `QS_deploy_preset` and `QS_logistics_cargoParent` where present. Map `QS_spawnMenu_spawnedBy` server-side to a presence/session alias or boolean; never log its raw UID/name/string content.

Do not log per frame. Emit only at the checkpoints above, scope to the affected classes, and rate-limit repeated failures by object pair/correlation ID.

### Diagnostic decision table

| Observation | Interpretation |
|---|---|
| Server sees `2500`; loading client sees `10000` in the same stable phase with no intervening setup/commit/owner change | Consistent with replication/JIP/client-state divergence |
| Both see `10000` after setup/apply completion | Supports setup being bypassed, ineffective, or later reset; stock `10000` during CREATE/SETUP_BEGIN is expected |
| Both see `2500` after setup; first `10000` appears after an observed ownership transfer with no other mass phase | Supports carry/pull/winch/placement or engine ownership lifecycle as the transition |
| Both see `2500`, but `canVehicleCargo` is `[false,true]` | Capture hidden/current cargo and geometry state; mass model alone is insufficient |
| `canVehicleCargo` is true, but `setVehicleCargo` fails | Transactional race or locality change between check and mutation |

## Decision boundary and next step

No production fix should be selected solely from the current evidence. The immediate condition is proven, but the state transition is not.

The server-freeze investigation reached the same instrumentation boundary. The next safe implementation is therefore one shared diagnostic core with fixed cargo-specific and freeze-specific event types, deployed from a reconciled release commit. The diagnostic commits remain observation-only. The corrected reconciliation branch contains documented post-live fixes but excludes the pending air-defense feature branch, so it is still not behavior-neutral relative to frozen B; separate R0/R1/R2 staging gates in the combined proposal are required to expose that confound.

Potential remediation directions after evidence is captured:

Historical note: these are conditional responses to a proven runtime transition, not current implementation directions. The 2026-09-01 follow-up supersedes any interpretation that mass or flatbed capacity should be changed now.

- Reassert the intended class/preset mass on the current owner after relevant locality changes.
- Move the capacity check and load mutation into one authoritative transaction and await mass convergence.
- Add a narrowly scoped `Local` event response for affected containers if ownership transfer is the proven transition.

Do not bypass the native capacity result without first establishing why the effective mass is wrong.

## Follow-up log

- 2026-08-30: Investigation recorded. No mission source or deployed PBO was changed. Instrumentation deferred pending investigation of a second bug that may benefit from the same tracing infrastructure.
- 2026-08-30: Freeze investigation completed and a [combined diagnostics/reconciliation release](2026-08-30-combined-diagnostics-release.md) was proposed. Cargo tracing remains event-driven and uses the shared build/session envelope, while client reports enter only through a fixed-shape, validated server endpoint.
- 2026-09-01: Reconciliation proved presets 6, 7, and 12–17 are already `2500` in `origin/main`, frozen B, and `9f61e06`. Generic Cargo20 `5000` is not an active purpose-built preset. No cargo rebalance commit was made; the eight-preset staging matrix above replaces the stale capacity-change direction.
