/*/
File: fn_diag.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Instrumentation overlay root.  Reads the six diagnostic keys once and
	starts the periodic instruments that are enabled.  Default-off: with every
	key absent this function defines six FALSE gates and starts nothing.

	Runs twice on the dedicated server.  The first call is preInit on every
	machine and only publishes the gates (FALSE, because the external
	configuration has not been read yet).  The second call is made by
	fn_init.sqf after '@Apex_cfg\parameters.sqf' has been compiled, and is the
	call that sees the real key values and launches the instruments.

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
private _fn_exactBoolean = {
	private _value = missionNamespace getVariable [(_this # 0),FALSE];
	((_value isEqualType FALSE) && {_value})
};
{
	missionNamespace setVariable [(_x # 1),([(_x # 0)] call _fn_exactBoolean),FALSE];
} forEach [
	['QS_missionConfig_diagHeartbeat','QS_diag_heartbeat'],
	['QS_missionConfig_diagLoopTiming','QS_diag_loopTiming'],
	['QS_missionConfig_diagRpcLog','QS_diag_rpcLog'],
	['QS_missionConfig_diagStateSnapshots','QS_diag_stateSnapshots'],
	['QS_missionConfig_diagSafePos','QS_diag_safePos'],
	['QS_missionConfig_diagScriptHistogram','QS_diag_scriptHistogram']
];
if (isNil 'QS_diag_loopState') then {
	missionNamespace setVariable ['QS_diag_loopState',createHashMap,FALSE];
};
if (isNil 'QS_diag_rpcState') then {
	missionNamespace setVariable ['QS_diag_rpcState',[diag_tickTime,0],FALSE];
};
if (!isServer) exitWith {};
if (missionNamespace getVariable ['QS_diag_started',FALSE]) exitWith {};
private _enabled = [
	'QS_diag_heartbeat','QS_diag_loopTiming','QS_diag_rpcLog',
	'QS_diag_stateSnapshots','QS_diag_safePos','QS_diag_scriptHistogram'
] select {(missionNamespace getVariable [_x,FALSE])};
if (_enabled isEqualTo []) exitWith {};
missionNamespace setVariable ['QS_diag_started',TRUE,FALSE];
diag_log format ['[DIAG INIT] enabled=%1',_enabled];
{
	if (missionNamespace getVariable [(_x # 0),FALSE]) then {
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
