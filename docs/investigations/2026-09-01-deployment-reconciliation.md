# 2026-09-01 deployment-to-Git reconciliation

Status: implemented reconciliation record. This document distinguishes the exact live reconstruction from later corrective commits; recording deployed behavior does **not** by itself approve that behavior, its security policy, privileged identities, or operational defaults.

## Scope and immutable evidence

The comparison is the freshly fetched Git baseline against the PBO freshly served/downloaded by joining the server on 2026-09-01. Its frozen bytes establish the mission payload delivered to that joining client; they do not independently prove the selected server-disk file, startup selection, or absence of loose runtime overlays.

| Evidence | Value |
| --- | --- |
| Git baseline | `origin/main` at `149b7b91a1b7a32bf6068a0a30dc0b101faa84da` |
| Frozen served deployment | `Apex_framework_420th_B.Altis.pbo` |
| PBO SHA-256 | `87A87D4A4482C146486033B358510D3551EEC91692390FE3D5F15E9F27256BCC` |
| BankRev content hash | `E7D0663FCB020B069C4398D0A5E58E30CB4BB68C` |
| Git mission root | `Apex_framework.terrain/` |
| Extracted deployment root | `Apex_framework_420th_B.Altis/` |

The frozen served PBO, extracted tree, comparison CSV, and summary JSON are retained outside the worktree under `420th-Arma3-PBO-sync-artifacts-20260901`. They are the mission-source audit evidence; the mutable Arma cache is not. A production cutover still requires a direct server-disk hash comparison and inventory of loose overlays/external inputs.

## Implementation status

| Point | Commit | Result |
| --- | --- | --- |
| Fresh base | `149b7b91a1b7a32bf6068a0a30dc0b101faa84da` | Fetched `origin/main` before reconstruction |
| Exact live reconstruction | `5c1ffb3` | Last commit representing the frozen B deployment, subject only to the documented nonsemantic/source-only exceptions below |
| Cargo lifecycle correction | `5e06631` | Prevents spawn-menu GC from deleting loaded, attached, roped, towed, nonlocal, deployed, or otherwise in-use logistics cargo |
| Garbage-queue correction | `6374357` | Compacts deletion sentinels in reverse so index shifts cannot skip queue entries |
| RPC authorization correction | `677f8de` | Adds the missing staff-weather endpoint and validates server origin/staff authority for team-feature RPCs |
| Workshop-policy correction | `2982ecc` | Makes enforcement default-off and fail-safe, bounds and validates reports/configuration, sanitizes output, and binds delayed kicks to UID plus owner |
| UAV-diagnostics correction | `b7d4907` | Makes imported UAV tracing explicit, default-off, bounded to eight workers, and rate-limited |
| Projectile-tracking correction | `c977817` | Replaces the deployed hard no-op with an explicit default-off, opt-in policy across send and receive paths |
| Source hygiene | `7300403` | Removes imported trailing whitespace without changing behavior |
| Staff-channel RPC correction | `3abd7c0` | Splits and validates the staff request/server apply path; removes forbidden JIP use |
| HC command-whitelist correction | `1095da7` | Routes HC `systemChat` and `setVehicleAmmo` effects through allowed wrappers |
| HC surrender correction | `5820dde` | Preserves surrendered-agent faces through the allowed wrapper and drops ineffective multiplayer `setName` |
| RPC target/JIP correction | `96f19a8` | Constrains spawn and team endpoints to their actual targets and retention requirements |
| Drone RPC correction/current code HEAD | `9f61e06` | Splits request from apply and authenticates UAV lock ownership |

The post-sync parity audit at `5c1ffb3` found no unclassified deployment delta. Only three documented exceptions remained:

- whitespace-only formatting in `code/functions/fn_curatorFunctions.sqf`;
- editor serialization noise in `mission.sqm` after retaining the semantic terminal class additions;
- source-only `media/commissary/README.txt`, intentionally retained in Git and absent from the PBO.

Accordingly, `5c1ffb3` is the exact-live source/behavior checkpoint. Payload comparison establishes its mission-source equivalence to frozen B subject to the documented exceptions; it does not by itself claim deterministic or byte-identical PBO reproduction. The mission-code tip at `9f61e06` intentionally differs from the frozen PBO only through the twelve post-reconstruction commits above. Eleven commits are corrective behavior/security changes; `7300403` is source-only whitespace cleanup. They must be reviewed as post-live changes, not mistaken for evidence copied from production.

The final comparator at `9f61e06` records 1,268 repository mission files against 1,265 deployed files: 697 case+EOL-only, 313 case-only identical, 30 EOL-only, 204 identical, 16 case+text changed, five text changed, and three repository-only, with no deployment-only path. Of the 21 changed paths, `fn_curatorFunctions.sqf` remains whitespace-only and `mission.sqm` remains editor serialization noise; the semantic Ghost Hawk entries are exact. The three repository-only paths are source-only `media/commissary/README.txt` plus corrective `TGC/Functions/Channels/fn_serverSetChannelMasks.sqf` and `TGC/Functions/Drones/fn_serverLockDroneByUID.sqf`. Every other difference maps to the post-live commits above. The final evidence is retained in `420th-Arma3-PBO-sync-artifacts-20260901/audit-final/{inventory.csv,summary.json}`.

Client Workshop enforcement remains gated on external `@Apex_cfg` release configuration. It must provide the exact Boolean `QS_missionConfig_clientWorkshopModEnforcementEnabled = true` and a non-empty `QS_missionConfig_allowedClientWorkshopIds` array of canonical decimal Workshop-ID strings (maximum 256 entries). Version and hash this non-secret configuration, verify it is loaded before client reports, and deploy it atomically with the PBO. Missing, empty, malformed, or oversized configuration now disables enforcement and logs the configuration error instead of mass-kicking clients. This remains a cooperative client-report policy, not an anti-cheat boundary.

### RemoteExec compatibility audit

The final static scan found 44 literal function endpoints, 15 absent from the function whitelist, and 26 literal native-command endpoints, 23 absent from the command whitelist. Most apparent omissions are harmless in current call sites because they originate on the dedicated server, which is exempt from CfgRemoteExec restrictions under the engine's server-origin rule. Static classification does not make broad dynamic dispatchers safe and does not replace runtime tests.

The audit did identify concrete `mode = 1` regressions:

| Finding | Disposition |
| --- | --- |
| Staff-channel client request used forbidden JIP retention and an unvalidated apply path | Fixed by the request/server-apply split in `3abd7c0` |
| HC `fn_AIHandleGroup.sqf` directly invoked `systemChat` and `setVehicleAmmo` | Routed through allowed wrappers in `1095da7` |
| Surrender case 21 directly invoked `setFace`/`setName` on an HC/client owner | `setFace` routed through the wrapper and multiplayer-ineffective `setName` removed in `5820dde` |
| Spawn/team entries had broader target/JIP permissions than their actual use | Constrained in `96f19a8` |
| Drone lock used one insufficiently authenticated request/apply endpoint | Split and owner-authenticated in `9f61e06` |

The cargo event-handler omission is server-origin, harmless under this rule, and unrelated to crate admission. The general `QS_fnc_remoteExec`/`QS_fnc_remoteExecCmd` dispatchers remain a design risk because a static endpoint list cannot prove every dynamic case; split them into narrow authenticated endpoints over time.

### Narrowed cargo conclusion

All eight in-scope purpose-built deployables already assign mass `2500` in `origin/main`, frozen B, and current `9f61e06`:

| Preset | Purpose | Container class |
| ---: | --- | --- |
| 6 | Mobile SAM / Defender | `Land_Cargo10_blue_F` |
| 7 | Mobile Radar | `Land_Cargo10_cyan_F` |
| 12 | Forward Operating Base | `Land_Cargo10_grey_F` |
| 13 | Combat Outpost | `Land_Cargo10_military_green_F` |
| 14 | Patrol Base | `Land_Cargo10_light_green_F` |
| 15 | Platform Module | `Land_Cargo10_sand_F` |
| 16 | Mobile Respawn | `Land_Cargo10_white_F` |
| 17 | Terrain Leveler | `Land_Cargo10_yellow_F` |

The generic Cargo20 fallback to mass `5000` is not an active purpose-built deployable preset and is not evidence for changing the eight Cargo10 presets or the HEMTT Flatbed. Therefore this reconciliation includes **no cargo mass, carrier-capacity, or admission rebalance commit**. Corrective commit `5e06631` fixes a separate lifecycle deletion hazard. The exact scope exclusion and any remaining intermittent admission work are recorded in the cargo investigation; capture the staging/runtime transition rather than preemptively masking it with new capacity values.

### Validation evidence

- `CfgConvert -test` passes both `mission.sqm` and `description.ext`.
- `git diff --check origin/main...HEAD` passes.
- An isolated local dedicated-server compile smoke loaded all 20 post-live SQF files: `20/20`, `ScriptError = 0`.
- The smoke-test RPT is `%LOCALAPPDATA%\Temp\codex-420-sync-validation\profile\arma3server_x64_2026-09-01_19-32-07.rpt`, SHA-256 `14F81DF272DD147003C4F9D60831F845262DE0CD89D359D913B0B9E6059C8211`.
- The temporary test mission was removed from Arma `MPMissions` after validation.
- An initial verified packing-mechanics build from the unfiltered `9f61e06` mission tree exposed that source-only `media/commissary/README.txt` would be included by a plain Git archive. That artifact was not promoted.
- The filtered production-form candidate in `prod-pbo-9f61e06-01` pins commit `9f61e0666edde5544c50951bab996b6bde68cb77` and mission-tree object `33ea816ae64ffc907af617f0a45eb40f470f4f19`, excludes exactly that README, and contains 1,267 files. `CfgConvert` passes; BankRev reports no PBO header properties; its listed/extracted inventory and every payload hash match the filtered stage; and a second independent FileBank build is byte-identical. Final PBO SHA-256 is `FBD92C1A6FC5D892459B6F0AA9028E774C80B2C37F3C24D927898FD20C3DC084`; BankRev content SHA-1 is `096890AC180E5191D0F4288F53D30CB57FA304FC`.

These checks establish config parsing, clean-diff hygiene, isolated SQF compilation, filtered package inventory/payload integrity, and repeatable FileBank bytes for the pinned mission tree. The later documentation-only commit does not change that mission tree and therefore does not require a mission rebuild. These checks do not replace multiplayer behavioral, locality, JIP, HC, security, load, external-config, or production-overlay tests.

## Inventory result

The Git mission contains 1,261 files and the deployed mission contains 1,265 files.

| Comparison category | Count | Treatment |
| --- | ---: | --- |
| Case-only plus EOL-only | 701 | Ignore extraction casing and line-ending noise |
| Case-only identical | 276 | Ignore extraction casing |
| EOL-only | 30 | Ignore line-ending noise |
| Identical | 199 | No action |
| Case-only plus text changed | 39 | Material; reconcile semantic hunks |
| Text changed | 6 | Material; reconcile semantic hunks |
| Deployment-only | 14 | Material; import, repair, or hold by group |
| Repository-only | 10 | Material packaging/source disposition |

After case and EOL normalization, 475 paths are identical and 731 are EOL-only. The material set is exactly **69 paths**: 45 changed text files, 14 deployment-only files, and 10 repository-only files.

## Lineage: earlier frozen A versus current frozen B

The earlier cached artifact (`Apex_framework_420th_A.Altis.pbo`, SHA-256 `80AACF333A75BBCE046BA9A41CAB88F78601FF19CC88C3B90C9D8D734C4960F6`) was also extracted and compared with B:

| A to B category | Count |
| --- | ---: |
| Identical | 1,238 |
| Changed text | 20 |
| New in B | 7 |

The seven B-new functions are:

- `code/functions/fn_clientApplyEntityState.sqf`
- `code/functions/fn_clientModKickWarning.sqf`
- `code/functions/fn_serverPublishEntityState.sqf`
- `code/functions/fn_serverSetEntityFeatureType.sqf`
- `code/functions/fn_serverSetPlayerFace.sqf`
- `code/functions/fn_serverValidateClientMods.sqf`
- `TGC/Functions/Channels/fn_refreshStaffChannelAccess.sqf`

The A-to-B changed set is the entity-state caller migration, arsenal preload guard, client-mod reporting, late whitelist/channel repair, spawn-menu handler migration, `fn_core.sqf`, `description.ext`, and the effective RemoteExec policy. The remaining deployed deltas predate B and were already present in A.

None of the 14 deployment-only paths or four PAA names exists in a reachable Git ref. None of the 45 changed deployment blobs exactly matches a historical blob at the same path. These are unpublished deployment edits, not a known historical release. The separate `feat/deployable-air-defense-turrets` tip `a99001f` is also not frozen B and must be rebased/integrated separately after reconciliation.

## Reconciliation rules

1. Preserve canonical Git casing. BankRev lowercases extracted paths; do not mass-rename roughly 1,000 paths to match extraction output.
2. Drop EOL-only differences. The checkout uses Windows `core.autocrlf`; release packaging should stage Git blobs or a Git archive so line endings do not depend on the packer host.
3. Stage semantic hunks from mixed files. In particular, never replace `description.ext`, `security.hpp`, `fn_config.sqf`, `fn_initPlayerLocal.sqf`, `fn_AI.sqf`, `fn_aoDefend.sqf`, `fn_core.sqf`, or `fn_remoteExec.sqf` wholesale in one commit.
4. In `mission.sqm`, retain only the three Assault Ghost Hawk class additions at both pilot terminals. Drop EditorData `nextID`/camera drift and marker-angle float serialization noise.
5. Drop the whitespace-only `fn_curatorFunctions.sqf` difference.
6. Do not edit `420th/userinputmenus/LICENSE`. Its normalized text is legally identical: the Git copy has CRLF and no final LF, while extraction has lowercase path plus LF. The prior binary classification was an extensionless-file artifact.
7. Keep `media/commissary/README.txt` as source documentation, but exclude it through a versioned package manifest before packing. A plain Git archive of the mission subtree contains this file and is not package-equivalent to frozen B.
8. Treat external `@Apex_cfg` values as a separately versioned release input. The PBO alone does not capture the client-mod allowlist or other server-side configuration.

## Logical change map and implementation record

The IDs below preserve the review boundaries used to reconstruct the branch and are also used by the complete path index. R01–R31 are implemented; the displayed boundary titles retain the original review-plan wording rather than necessarily matching the final Git subject exactly. `5c1ffb3` closes the exact-live series, and the later hashes in the implementation-status table are deliberate post-live changes. Only R32 remains proposed. “Import” means a delta was observed in deployment, not that it is safe to release without its stated gate.

### R01 — source and package cleanup

Implemented boundary (original review title): `chore(source): remove obsolete backup and duplicate asset locations`

- Remove `code/functions/fn_aoDefend.sqf.old`.
- Remove the eight obsolete asset locations listed in the repository-only table below. Each is byte-identical to the deployed and referenced asset under `media/images/flags/`; all code references use the correct path.
- Preserve the commissary README as source documentation, but exclude it from the PBO through a versioned package rule.

Risk: low. Verify a clean package contains no stale backup or duplicate payload and that the README remains available to maintainers.

### R02 — live commissary assets

Implemented boundary (original review title): `assets(commissary): import four live purchased skin textures`

Import the four deployment-only PAAs as one data commit. Static references are not expected: `serverGetDonatorSkins` and `serverPMC` construct `media\commissary\%1` from database `fileName`/`texturePathList` values. Omitting these files breaks purchased multi-slot skins.

Risk: low code risk; validate the database rows and asset provenance.

### R03 — player-profile request queue

Implemented boundary (original review title): `fix(profile): validate and bound queued profile requests`

- `420th/playerprofile/fn_processPlayerProfileQueue.sqf`
- `420th/playerprofile/fn_requestPlayerProfile.sqf`

The deployed pair binds the claimed owner to `remoteExecutedOwner`, caps the queue at 64, deduplicates owner/target requests, timestamps work, and drops requests after 60 seconds or requester disconnect. Keep the pair atomic. Residual risk: an Arma owner ID can be reused within the TTL because the queue does not retain the requester's UID.

### R04 — PMC strict-SQL binding

Implemented boundary (original review title): `fix(pmc): bind rank permissions as numeric SQL values`

- `code/functions/fn_serverPMC.sqf`

Convert `_invite`, `_membersPermission`, `_ranksPermission`, and `_skinsPermission` booleans to `0`/`1` before `createPMCRank` and `updatePMCRank` queries. This prevents SQF `true`/`false` strings from reaching numeric MariaDB columns.

### R05 — asynchronous database startup

Implemented boundary (original review title): `fix(db): wait boundedly for asynchronous database startup`

- Server-side hunk of `TGC/Functions/Database/fn_dbWhitelistInit.sqf`

Wait in scheduled context for `TGC_db_ready`, bounded to 60 seconds, rather than dropping PlayerConnected/client retry work; log a timeout. Keep separate from client channel reconciliation.

### R06 — late staff-channel access

Implemented boundary (original review title): `fix(channels): reconcile late staff whitelist access`

- Client-side hunk of `TGC/Functions/Database/fn_dbWhitelistInit.sqf`
- Channel-ready/initial-refresh hunk of `code/functions/fn_initPlayerLocal.sqf`
- New `TGC/Functions/Channels/fn_refreshStaffChannelAccess.sqf`
- Owning CfgFunctions registration in `description.ext`

This coalesces late whitelist responses and refreshes Side VON and the Staff custom channel only after client channel initialization. Test staff and non-staff late DB responses.

### R07 — Defend VTOL classname

Implemented boundary (original review title): `fix(defend): correct Xi'an infantry classname`

- `code/config/QS_data_listVehicles.sqf`

Replace nonexistent `O_VTOL_02_infantry_dynamicLoadout_F` with `O_T_VTOL_02_infantry_dynamicLoadout_F`. This is a standalone typo fix in `defend_helitypes_2`; it is unrelated to vehicle cargo capacity.

### R08 — virtual-sector marker lifecycle

Implemented boundary (original review title): `fix(sector): make completion and marker cleanup idempotent`

- `code/config/QS_data_radioTower_1.sqf`
- Case-73 hunk of `code/functions/fn_remoteExec.sqf`
- `code/functions/fn_scSubObjective.sqf`

Keep Killed/Deleted completion idempotent, delete stale markers, clear marker arrays, and make the client marker path safe to repeat. This prevents a Killed→Deleted double completion.

### R09 — client arsenal preload guard

Implemented boundary (original review title): `fix(arsenal): guard invalid BIS preload data`

- `code/functions/fn_clientArsenal.sqf`

The B-new guard waits at most 10 seconds for a valid 27-entry preload, logs invalid state, and exits without opening a broken UI.

### R10 — friendly-fire and remote-control attribution

Implemented boundary (original review title): `fix(damage): resolve live sides and remote-controlled attackers`

- `code/functions/fn_clientDamageModifier.sqf`
- `code/functions/fn_clientEventHit.sqf`
- `code/functions/fn_clientVehicleEventHandleDamage.sqf`
- Attribution/casualty-text hunks of `code/functions/fn_incapacitated.sqf`
- Initial live-side hunk of `code/functions/fn_initPlayerLocal.sqf`
- `TGC/Functions/Damage/fn_isFriendlyFire.sqf`

Intent is coherent, but current resolvers differ: some use the BIS owner variable while `fn_incapacitated.sqf` also checks `remoteControlled`. Prefer one tested helper. The in-vehicle damage zeroing is a gameplay change and needs PvP/AI/remote-control cases.

### R11 — incapacitated UI handler names

Implemented boundary (original review title): `fix(ui): remove incapacitated handlers by valid event names`

- Two handler-removal hunks in `code/functions/fn_incapacitated.sqf`

Use `ButtonClick` and `ButtonDown` in `ctrlRemoveAllEventHandlers`. Stage separately from attacker attribution.

### R12 — projectile tracking operational mitigation

Implemented boundary (original review title): `ops(projectiles): keep client projectile fan-out disabled by default`

- `code/functions/fn_clientTrackProjectile.sqf`

Deployment has an unconditional early no-op. Main can fan every tracked projectile to every human client, making work scale with population and fire rate. Preserve the deployed-off outcome using an explicit default-off switch, then instrument before re-enabling; do not accidentally restore main behavior during reconciliation.

Risk: high and freeze-relevant, although it does not change Cargo10 load capacity.

Implementation: the hard no-op is preserved at the exact-live checkpoint. Corrective commit `c977817` replaces it with `QS_missionConfig_projectileTrackingEnabled`, whose exact Boolean default is false, and guards the sender, receiver, and map-draw paths. It remains opt-in pending load testing.

### R13 — fuel-transport death effect

Implemented boundary (original review title): `fix(vehicles): limit secondary explosions to fuel transports`

- `code/functions/fn_eventEntityKilled.sqf`

Only configured fuel transports receive the secondary explosion, and parachutes are excluded. Existing death-time vehicle-cargo unloading is otherwise unchanged.

### R14 — bounded headless-client group replication

Implemented boundary (original review title): `fix(hc): whitelist replicated group state and exclude Viper teams`

- HC allowlist/transfer hunks of `code/functions/fn_AI.sqf`
- Case-98 hunk of `code/functions/fn_remoteExec.sqf`
- `code/functions/fn_spawnViperTeam.sqf`

This replaces replication of up to 128 arbitrary group variables with roughly 15 named variables and avoids Viper transfer. It is directly relevant to the freeze hypothesis. Validate every HC ownership transition and prove no required variable was omitted.

### R15 — patrol waypoint validation

Implemented boundary (original review title): `fix(ai): validate patrol waypoint indexes`

- `code/functions/fn_AIHandleGroup.sqf`

Validate the PATROL index before dereference. Low risk; test empty and out-of-range waypoint state.

### R16 — hostile-UAV spawning policy

Implemented boundary (original review title): `ops(uav): add an explicit hostile-UAV spawning policy`

- Policy hunk of `code/functions/fn_config.sqf`
- Consumer hunks of `code/functions/fn_AI.sqf`
- Consumer hunk of `code/functions/fn_aoDefend.sqf`
- Consumer hunk of `code/functions/fn_scSpawnUAV.sqf`

Deployment publishes `QS_enemyUAVSpawningEnabled = false`, hard-disabling hostile UAV spawning. That is a gameplay kill switch, not merely diagnostics. Import in isolation and require an owner decision on the production default.

### R17 — enemy-UAV diagnostics

Implemented boundary (original review title): `diagnostics(uav): add bounded default-off UAV spawn logging`

- New `code/functions/fn_enemyUAVDiagnostics.sqf`
- Owning postInit registration in `description.ext`

The deployed A-held version unconditionally installs an EntityCreated handler and schedules a one-second worker for every UAV before logging hostile ones. Gate it default-off and bound/rate-limit it, or replace it with the combined instrumentation facility. Do not silently make temporary logging permanent.

Implementation: corrective commit `b7d4907` removes unconditional postInit, requires the exact Boolean `QS_missionConfig_enemyUAVDiagnosticsEnabled`, caps pending workers at eight, and aggregates throttle logs to at most once per 60 seconds. This narrow UAV tracer is implemented but is not the proposed combined cargo/freeze facility.

### R18 — Defend air-support tuning

Implemented boundary (original review title): `tune(defend): isolate air-support pacing changes`

- Delay, pacing, distance, helicopter, vPara, and jet-cap hunks of `code/functions/fn_aoDefend.sqf`

Review as a gameplay/performance policy. The lower initial jet caps in B are later overwritten when the live loop recomputes main's `1/2/3/4` caps, so that hunk currently has no durable limiting effect.

### R19 — deferred Normal-AO cleanup

Implemented boundary (original review title): `fix(ao): defer Normal-AO object cleanup`

- Deferred-list initialization in `code/functions/fn_config.sqf`
- Deferral hunks in `code/functions/fn_AI.sqf`
- Cleanup instruction in `code/functions/fn_core.sqf`
- Integration in `code/functions/fn_gpsJammer.sqf`

Deployment waits for AO deactivation, or for Defend completion, then another 30 seconds before a full cleanup. The cleanup performs unbudgeted scans and deletion of dead objects, attachments, objects, and groups plus global unhide. Treat as high freeze risk: add timing/count instrumentation or a per-frame budget before release.

### R20 — server unit recycler policy

Implemented boundary (original review title): `ops(recycler): enable server unit recycling`

- One policy hunk in `code/functions/fn_config.sqf`

Deployment changes `QS_recycler_units` from false to true. Isolate and benchmark this lifecycle/load policy; it is independent of deferred AO cleanup.

### R21 — out-of-bounds cleanup safety

Implemented boundary (original review title): `fix(cleanup): avoid deleting attached out-of-bounds objects`

- `code/functions/fn_deleteOutOfBoundsLoop.sqf`

Deployment tightens bounds, scans every 30 seconds, excludes attached objects, and rechecks before deletion. Test loaded vehicle cargo, ropes, attachments, respawn transitions, and boundary jitter.

### R22 — spawn-menu logistics garbage collection

Implemented boundary (original review title): `fix(spawn): manage spawned logistics objects as one lifecycle`

- `code/functions/fn_spawnMenuInit.sqf`
- `SPAWN_MENU_LOGISTICS` instruction in `code/functions/fn_core.sqf`

Never take only one half. Deployment queues spawned `Land_Cargo10_*` objects permanently and excludes them from generic 10-second abandonment deletion, then walks the list every 45 seconds with `uiSleep 0.01` per entry. It has no vehicle-cargo, cargo-parent, attachment, or rope guard, so it can delete an undeployed crate while loaded or parked. Higher population can retain more entries and increase cleanup work.

Risk: high for both the Cargo10 investigation and freeze investigation. Add loaded-cargo exclusions and instrumentation before release. This does not directly change mass, `canVehicleCargo`, `setVehicleCargo`, or HEMTT capacity, so it is not by itself the “no room in current configuration” cause.

Implementation: the exact deployed lifecycle was reconstructed before `5c1ffb3`. Corrective commit `5e06631` adds in-use guards at both queue evaluation and final deletion and stops re-queuing deployed logistics; `6374357` then fixes forward-deletion index skipping while compacting the shared garbage queue. These are intentional post-PBO differences.

### R23 — dynamic-simulation distance

Implemented boundary (original review title): `tune(simulation): isolate expanded dynamic-simulation radii`

- Dynamic-simulation hunk of `code/functions/fn_core.sqf`

Deployment raises GROUP distance from 1,250 to 4,000 and VEHICLE distance from 1,000 to 4,000. Area exposure grows by about 10.2× and 16× respectively. This is a major load/freeze amplifier and must remain an isolated, benchmarked commit.

### R24 — canonical entity-bound client state

Implemented boundary (original review title): `fix(net): publish one canonical entity-bound client-state snapshot`

Foundation and endpoint files:

- New `code/functions/fn_clientApplyEntityState.sqf`
- New `code/functions/fn_serverPublishEntityState.sqf`
- New `code/functions/fn_serverSetEntityFeatureType.sqf`
- New `code/functions/fn_serverSetPlayerFace.sqf`
- Owning registrations in `description.ext`
- Owning endpoint entries and removal of direct `TGC_fnc_addSpawnMenuVehicleHandlers` entry in `code/config/security.hpp`

Feature-type callers:

- `code/functions/fn_AIXHeliInsert.sqf`
- Feature-state hunk of `code/functions/fn_aoDefend.sqf`
- `code/functions/fn_casRespawn.sqf`
- `code/functions/fn_enemyCAS.sqf`
- `code/functions/fn_scEnemy.sqf`
- `code/functions/fn_scSpawnHeli.sqf`
- Feature-state hunk of `code/functions/fn_scSpawnUAV.sqf`
- `code/functions/fn_uavOperator2.sqf`
- Feature-state hunk of `code/functions/fn_vSetup.sqf`

Face callers:

- `code/functions/fn_clientEventArsenalClosed.sqf`
- `code/functions/fn_clientEventArsenalOpened.sqf`
- `code/functions/fn_clientEventRespawn.sqf`
- `code/functions/fn_clientMenuFace.sqf`

Spawn-handler caller:

- `code/functions/fn_spawnMenuManagedVehicleInit.sqf`

This coherent B-new bundle replaces competing object-keyed JIP payloads with one complete, server-authored snapshot. Import atomically. The entity object is the retained JIP key; cargo/freeze diagnostics must not reuse that same object key or they can overwrite the snapshot.

### R25 — fixed team-map and name-tag RPCs

Implemented boundary (original review title): `fix(team): replace transmitted code with fixed feature endpoints`

- `code/functions/fn_teamMapIcons.sqf`
- `code/functions/fn_teamNameTags.sqf`
- New `code/functions/fn_clientSetTeamFeature.sqf`
- New `code/functions/fn_serverSetTeamFeature.sqf`
- Owning registrations in `description.ext`
- Owning entries in `code/config/security.hpp`

Replacing dynamic code/public-variable transport is a security improvement, but deployed authorization is incomplete. The client receiver does not require `remoteExecutedOwner == 2`, and the server setter has no requester authorization, allowing a client to request a global toggle if exposed. Add both checks in the same group before release.

Implementation: `2be5574` reconstructs the deployed fixed-RPC design. Corrective commit `677f8de` requires server origin on the client receiver, authorizes server-local/server-origin requests, and limits player-originated global toggles to a connected player on the `ALL` whitelist.

### R26 — client Workshop-mod policy

Implemented and corrected boundary (original review title): `feat(policy): validate reported client Workshop mods`

- Client reporting hunk of `code/functions/fn_initPlayerLocal.sqf`
- New `code/functions/fn_clientModKickWarning.sqf`
- New `code/functions/fn_serverValidateClientMods.sqf`
- Owning registrations in `description.ext`
- Owning entries in `code/config/security.hpp`

The frozen-PBO implementation was unsafe to release: it trusted suppressible self-reporting, accepted an unbounded RemoteExec array, failed to sanitize fallback Workshop IDs used in a `serverCommand` reason, and interpreted absent allowlist configuration as `[]`, potentially rejecting every reported non-official mod.

Implementation: `627677a` preserves that deployed policy at the exact reconstruction point. Corrective commit `2982ecc` makes enforcement default-off and fail-safe; resolves the reporting player and binds delayed action to UID plus owner; permits one handled report; bounds the allowlist to 256 and reports to 128 entries; requires canonical decimal Workshop IDs; sanitizes/bounds displayed data; and limits logged and displayed rejections. Enforcement must remain off until `@Apex_cfg` supplies a versioned non-empty allowlist and the exact Boolean enable flag, both are verified loaded before reports, and allowed/disallowed/malformed/suppressed-client cases pass staging. Even then, client self-reporting is cooperative policy rather than an anti-cheat control.

### R27 — corpse and wreck retention

Implemented boundary (original review title): `tune(cleanup): shorten corpse and wreck retention`

- Policy hunks in `description.ext`

Deployment changes corpse limit 30→20, corpse maximum retention 1,200→600 seconds, and wreck maximum retention 1,200→600 seconds. Require runner approval and benchmark independently.

### R28 — pylon blacklist policy

Implemented boundary (original review title): `policy(aircraft): clear the pylon blacklist`

- Policy hunk in `description.ext`

This broadens available pylon choices. It is a gameplay/permissions decision, not a reconciliation necessity; require explicit owner review.

### R29 — debug-console principals

Implemented boundary (original review title): `policy(admin): update debug-console principals`

- Four additional UIDs in `description.ext`
- `BIS_fnc_debugConsoleExec` entry in `code/config/security.hpp`

Validate all four identities out of band. This is privileged access and must not be accepted merely because it was present in the PBO; validation is merge-blocking.

### R30 — Assault Ghost Hawks at pilot terminals

Implemented boundary (original review title): `content(spawn): add Assault Ghost Hawk variants`

- Semantic terminal-init hunks only in `mission.sqm`

Add `B_CTRG_Heli_Transport_01_Assault_F`, `_Assault_sand_F`, and `_Assault_tropic_F` to both `pilot1` and `pilot2`. Discard editor camera, `nextID`, and marker-float noise.

### R31 — audited RemoteExec whitelist cutover

Implemented exact-live boundary (original review title): `security(remoteexec): activate an audited whitelist policy`

- Final endpoint inventory in `code/config/security.hpp`
- Uncomment the security include in `description.ext`

This was implemented last in the exact-live series as `5c1ffb3`, after all owning endpoint commits. B activates `mode = 1`, but its whitelist demonstrably omitted the legitimate client→server call from `TGC/Functions/Staff/fn_staffWeatherGUI.sqf` to `TGC_fnc_manageWeather`; the exact reconstruction therefore also reproduced that defect. Corrective commits `677f8de`, `3abd7c0`, `1095da7`, `5820dde`, `96f19a8`, and `9f61e06` address the concrete compatibility and authorization findings summarized in the static audit above. Runtime testing must still cover client→server, server→client, JIP, HC, admin, team, mod, and diagnostic endpoints.

### R32 — combined cargo/freeze instrumentation

Proposed follow-up commit, not implemented: `diagnostics: add bounded cargo and server-stall telemetry`

The reconciliation prerequisite is now implemented through `9f61e06`; this facility is still only a design. If approved, add it afterward as separate default-off, rate-limited commits. Cargo telemetry should record each load attempt/result, cargo and carrier class/config values, loaded parent, attachments/ropes, locality, server FPS, player count, and whether spawn-menu GC touched the crate. Freeze telemetry should provide a monotonic heartbeat and timed/count summaries around HC transfer, AO cleanup, logistics GC, dynamic simulation, projectile tracking, and other suspected bursts. Add narrow non-JIP RemoteExec declarations in the owning diagnostic commits and rerun the final static audit. Do not use an entity object as a diagnostic JIP key because R24 owns it.

## Complete material-path index

Mixed files deliberately map to several groups because they must be split by hunk.

### Changed text: 45 paths

| Path | Group(s) / disposition |
| --- | --- |
| `420th/playerprofile/fn_processPlayerProfileQueue.sqf` | R03 |
| `420th/playerprofile/fn_requestPlayerProfile.sqf` | R03 |
| `code/config/QS_data_listVehicles.sqf` | R07 |
| `code/config/QS_data_radioTower_1.sqf` | R08 |
| `code/config/security.hpp` | R24, R25, R26, R29, R31; selective hunks only |
| `code/functions/fn_AI.sqf` | R14, R16, R19; selective hunks only |
| `code/functions/fn_AIHandleGroup.sqf` | R15 |
| `code/functions/fn_AIXHeliInsert.sqf` | R24 |
| `code/functions/fn_aoDefend.sqf` | R16, R18, R24; selective hunks only |
| `code/functions/fn_casRespawn.sqf` | R24 |
| `code/functions/fn_clientArsenal.sqf` | R09 |
| `code/functions/fn_clientDamageModifier.sqf` | R10 |
| `code/functions/fn_clientEventArsenalClosed.sqf` | R24 |
| `code/functions/fn_clientEventArsenalOpened.sqf` | R24 |
| `code/functions/fn_clientEventHit.sqf` | R10 |
| `code/functions/fn_clientEventRespawn.sqf` | R24 |
| `code/functions/fn_clientMenuFace.sqf` | R24 |
| `code/functions/fn_clientTrackProjectile.sqf` | R12 |
| `code/functions/fn_clientVehicleEventHandleDamage.sqf` | R10 |
| `code/functions/fn_config.sqf` | R16, R19, R20; selective hunks only |
| `code/functions/fn_core.sqf` | R19, R22, R23; selective hunks only |
| `code/functions/fn_curatorFunctions.sqf` | Drop: whitespace only |
| `code/functions/fn_deleteOutOfBoundsLoop.sqf` | R21 |
| `code/functions/fn_enemyCAS.sqf` | R24 |
| `code/functions/fn_eventEntityKilled.sqf` | R13 |
| `code/functions/fn_gpsJammer.sqf` | R19 |
| `code/functions/fn_incapacitated.sqf` | R10 and R11; selective hunks only |
| `code/functions/fn_initPlayerLocal.sqf` | R06, R10, R26; selective hunks only |
| `code/functions/fn_remoteExec.sqf` | R08 and R14; selective hunks only |
| `code/functions/fn_scEnemy.sqf` | R24 |
| `code/functions/fn_scSpawnHeli.sqf` | R24 |
| `code/functions/fn_scSpawnUAV.sqf` | R16 and R24; selective hunks only |
| `code/functions/fn_scSubObjective.sqf` | R08 |
| `code/functions/fn_serverPMC.sqf` | R04 |
| `code/functions/fn_spawnMenuInit.sqf` | R22 |
| `code/functions/fn_spawnMenuManagedVehicleInit.sqf` | R24 |
| `code/functions/fn_spawnViperTeam.sqf` | R14 |
| `code/functions/fn_teamMapIcons.sqf` | R25 |
| `code/functions/fn_teamNameTags.sqf` | R25 |
| `code/functions/fn_uavOperator2.sqf` | R24 |
| `code/functions/fn_vSetup.sqf` | R24 |
| `description.ext` | R06, R17, R24–R29, R31; selective hunks only |
| `mission.sqm` | R30 semantic hunks; discard editor serialization noise |
| `TGC/Functions/Damage/fn_isFriendlyFire.sqf` | R10 |
| `TGC/Functions/Database/fn_dbWhitelistInit.sqf` | R05 and R06; selective hunks only |

### Deployment-only: 14 paths

| Path | Group / disposition |
| --- | --- |
| `code/functions/fn_clientApplyEntityState.sqf` | R24, B-new; import atomically |
| `code/functions/fn_clientModKickWarning.sqf` | R26, B-new; hold pending repair/config |
| `code/functions/fn_clientSetTeamFeature.sqf` | R25, A-held; import with authorization repair |
| `code/functions/fn_enemyUAVDiagnostics.sqf` | R17, A-held; default-off/bound before release |
| `code/functions/fn_serverPublishEntityState.sqf` | R24, B-new; import atomically |
| `code/functions/fn_serverSetEntityFeatureType.sqf` | R24, B-new; import atomically |
| `code/functions/fn_serverSetPlayerFace.sqf` | R24, B-new; import atomically |
| `code/functions/fn_serverSetTeamFeature.sqf` | R25, A-held; import with authorization repair |
| `code/functions/fn_serverValidateClientMods.sqf` | R26, B-new; hold pending repair/config |
| `TGC/Functions/Channels/fn_refreshStaffChannelAccess.sqf` | R06, B-new; import with callers/registration |
| `media/commissary/1787928938194-587ada75f25d7d98.paa` | R02, A-held; import |
| `media/commissary/1787928938195-9d416e3a41ab6973.paa` | R02, A-held; import |
| `media/commissary/1787936201274-47fbef394384e281.paa` | R02, A-held; import |
| `media/commissary/1787936201279-6234adea6f423a05.paa` | R02, A-held; import |

### Repository-only: 10 paths

| Path | Group / disposition |
| --- | --- |
| `code/functions/fn_aoDefend.sqf.old` | R01; remove stale unreferenced backup |
| `media/commissary/README.txt` | R01; preserve as source docs, relocate or exclude from package |
| `media/images/general/flag_australia.jpg` | R01; remove obsolete duplicate |
| `media/images/general/flag_gadsden.jpg` | R01; remove obsolete duplicate |
| `media/images/general/flag_kekistani.jpg` | R01; remove obsolete duplicate |
| `media/images/general/flag_lego.jpg` | R01; remove obsolete duplicate |
| `media/images/general/flag_new_zealand.jpg` | R01; remove obsolete duplicate |
| `media/images/general/flag_pride.jpg` | R01; remove obsolete duplicate |
| `media/images/general/flag_south_africa.jpg` | R01; remove obsolete duplicate |
| `media/images/insignia/aleksy/82nd_AB.paa` | R01; remove obsolete duplicate of correct flag asset |

## Review and release gates

Before this PR can be treated as deployable rather than evidentiary:

1. Preserve the completed 69-path audit and final `audit-final` comparator as release evidence; rerun the comparator if the mission tree changes after `9f61e06`. A documentation-only commit does not invalidate the mission-payload comparison.
2. Preserve the passing config-parse, diff-check, and 20/20 compile-smoke evidence above. The static RemoteExec inventory is complete; runtime-test the corrected staff-channel, HC-command, surrender-face, spawn/team, and drone-lock paths, plus representative server-origin omissions and JIP reconnect behavior.
3. Runtime-test `677f8de` and the `2982ecc` mod validator. Keep Workshop enforcement disabled unless the versioned external `@Apex_cfg` enable flag and non-empty allowlist are present, validated, hashed, and deployed with the same release.
4. Validate every one of the four added debug-console UIDs with the server owner through a private channel; this is a merge-blocking privileged-access decision. Explicitly review the pylon-policy and other gameplay/operations changes rather than approving them merely because they were deployed.
5. Benchmark R12, R14, R18–R23 at low and high player/AI/HC load. Capture timings and counts, not only server FPS.
6. Run the eight-preset staging matrix from the cargo investigation. Assert mass `2500` and two-crate admission without changing mass/capacity code; confirm GC never deletes in-use cargo.
7. The combined diagnostics facility is still proposed and unimplemented. If approved, add it as separate default-off commits on top of `9f61e06` so cargo failures and freezes share one build ID/time base.
8. Build from a clean Git-object staging tree, not a CRLF-mutated checkout, and apply the recorded source-only README exclusion before packing. Record source commit, package manifest/rule, external-config manifest hash, packer/tool version, PBO SHA-256, and normalized extracted-tree hash. Do not promote the verified interim build that included the README.
9. Deploy PBO and external configuration together, retain the prior artifact for rollback, and verify the server advertises/logs the expected source commit before reopening untracked edits.

The resulting PR should initially be draft. Commit `5c1ffb3` preserves exact deployment evidence; commits `5e06631` through `9f61e06`, individually listed above, are documented post-deployment changes. Exact deployment parity is evidence of what ran, not evidence that each deployed change is correct or approved.
