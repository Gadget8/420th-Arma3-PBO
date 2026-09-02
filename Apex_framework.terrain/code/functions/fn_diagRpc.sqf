/*/
File: fn_diagRpc.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Instrument 3, RPC decision log.  Called from the entry prologue of
	QS_fnc_remoteExec and QS_fnc_remoteExecCmd, at the point where the
	existing validator's verdict is known and before any case body runs.

		[<case>,<owner>,<jip>,<accept>,<reason>] call QS_fnc_diagRpc;

	[DIAG RPC] case=<n|verb> owner=<remoteExecutedOwner> jip=<isRemoteExecutedJIP> accept|reject reason=<...>

	<owner> is the engine's network owner id (remoteExecutedOwner).  It is not
	a Steam UID and no UID is read or logged here.

	Rate limited to 200 lines per second across both dispatchers; the counter
	is a two-slot array in QS_diag_rpcState, reset on the first call of each
	new whole second.  Lines dropped by the limiter are not reported, to keep
	the limiter itself free of a per-call write.
_____________________________________________________________________/*/

if (!(missionNamespace getVariable ['QS_diag_rpcLog',FALSE])) exitWith {};
params [['_case',''],['_owner',0,[0]],['_jip',FALSE,[FALSE]],['_accept',FALSE,[FALSE]],['_reason','',['']]];
private _state = missionNamespace getVariable ['QS_diag_rpcState',[0,0]];
private _now = diag_tickTime;
if ((_now - (_state # 0)) >= 1) then {
	_state set [0,_now];
	_state set [1,0];
};
_state set [1,((_state # 1) + 1)];
missionNamespace setVariable ['QS_diag_rpcState',_state,FALSE];
if ((_state # 1) > 200) exitWith {};
diag_log format [
	'[DIAG RPC] case=%1 owner=%2 jip=%3 %4 reason=%5',
	_case,
	_owner,
	_jip,
	(['reject','accept'] select _accept),
	_reason
];
