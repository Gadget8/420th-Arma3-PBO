/*/
File: fn_diag.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Instrumentation overlay root.  Defines the six local diagnostic gates at
	preInit, then reads their server-only configuration after parameters.sqf
	has loaded.  Default-off: with every key absent all gates remain FALSE and
	no periodic instrument starts.

	Runs twice on the dedicated server.  The first call is preInit on every
	machine and defines FALSE gates.  fn_init.sqf then calls this with
	'SERVER_CONFIG_READY' after '@Apex_cfg\parameters.sqf' has been compiled.
	That explicit call normalizes the real values, stores a server-local,
	versioned HC-safe snapshot, and launches the server instruments.

	Keys (exact Boolean, read once per call):

		QS_missionConfig_diagHeartbeat        -> QS_diag_heartbeat
		QS_missionConfig_diagLoopTiming       -> QS_diag_loopTiming
		QS_missionConfig_diagRpcLog           -> QS_diag_rpcLog
		QS_missionConfig_diagStateSnapshots   -> QS_diag_stateSnapshots
		QS_missionConfig_diagSafePos          -> QS_diag_safePos
		QS_missionConfig_diagScriptHistogram  -> QS_diag_scriptHistogram

	A key is honoured only when its value is exactly TRUE.  Any other value,
	including 1, 'TRUE' and [], leaves the gate FALSE.
_____________________________________________________________________/*/

if (isRemoteExecuted) exitWith {};
params [['_mode','preInit',['']]];
private _serverConfigReady = _mode isEqualTo 'SERVER_CONFIG_READY';
if (_serverConfigReady && {!isDedicated}) exitWith {};
private _serverConfigured = localNamespace getVariable ['QS_diag_serverConfigured',FALSE];
if (
	(!_serverConfigReady) &&
	{isDedicated} &&
	{_serverConfigured}
) exitWith {};
private _gateMappings = [
	['QS_missionConfig_diagHeartbeat','QS_diag_heartbeat'],
	['QS_missionConfig_diagLoopTiming','QS_diag_loopTiming'],
	['QS_missionConfig_diagRpcLog','QS_diag_rpcLog'],
	['QS_missionConfig_diagStateSnapshots','QS_diag_stateSnapshots'],
	['QS_missionConfig_diagSafePos','QS_diag_safePos'],
	['QS_missionConfig_diagScriptHistogram','QS_diag_scriptHistogram']
];
private _fn_exactBoolean = {
	private _value = missionNamespace getVariable [(_this # 0),FALSE];
	((_value isEqualType FALSE) && {_value})
};
{
	localNamespace setVariable [
		(_x # 1),
		([FALSE,([(_x # 0)] call _fn_exactBoolean)] select _serverConfigReady)
	];
} forEach _gateMappings;
if ((!_serverConfigReady) || {!_serverConfigured}) then {
	localNamespace setVariable ['QS_diag_loopState',createHashMap];
	localNamespace setVariable ['QS_diag_rpcState',[diag_tickTime,0]];
	localNamespace setVariable ['QS_diag_hcConfigured',FALSE];
	localNamespace setVariable ['QS_diag_started',FALSE];
};
if (!_serverConfigReady) exitWith {
	if (isServer) then {
		serverNamespace setVariable ['QS_diag_hcConfig',[]];
	};
};
private _hcGates = [
	localNamespace getVariable ['QS_diag_heartbeat',FALSE],
	localNamespace getVariable ['QS_diag_loopTiming',FALSE],
	localNamespace getVariable ['QS_diag_rpcLog',FALSE],
	FALSE,
	localNamespace getVariable ['QS_diag_safePos',FALSE],
	localNamespace getVariable ['QS_diag_scriptHistogram',FALSE]
];
private _hcConfig = [];
if (TRUE in _hcGates) then {
	_hcConfig = [1,_hcGates];
};
serverNamespace setVariable ['QS_diag_hcConfig',_hcConfig];
localNamespace setVariable ['QS_diag_serverConfigured',TRUE];
call (missionNamespace getVariable ['QS_fnc_diagStart',{}]);
