/*/
File: fn_diagStart.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Local-only, idempotent launcher for periodic diagnostics on a dedicated
	server or headless client.  Human clients never launch collectors.
_____________________________________________________________________/*/

if (hasInterface) exitWith {};
if (localNamespace getVariable ['QS_diag_started',FALSE]) exitWith {};
private _enabled = [
	'QS_diag_heartbeat','QS_diag_loopTiming','QS_diag_rpcLog',
	'QS_diag_stateSnapshots','QS_diag_safePos','QS_diag_scriptHistogram'
] select {(localNamespace getVariable [_x,FALSE])};
if (_enabled isEqualTo []) exitWith {};
localNamespace setVariable ['QS_diag_started',TRUE];
private _role = ['hc','server'] select isServer;
diag_log format ['[DIAG INIT] enabled=%1 role=%2 owner=%3',_enabled,_role,clientOwner];
{
	if (localNamespace getVariable [(_x # 0),FALSE]) then {
		private _fn = missionNamespace getVariable [(_x # 1),{}];
		if (_fn isEqualType {}) then {
			0 spawn _fn;
		};
	};
} forEach [
	['QS_diag_heartbeat','QS_fnc_diagHeartbeat'],
	['QS_diag_scriptHistogram','QS_fnc_diagScripts'],
	['QS_diag_stateSnapshots','QS_fnc_diagState']
];
