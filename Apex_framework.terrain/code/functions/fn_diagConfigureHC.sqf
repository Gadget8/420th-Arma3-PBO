/*/
File: fn_diagConfigureHC.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Apply the dedicated server's normalized diagnostic gates to one headless
	client.  The fixed protocol is [1,[six exact Booleans]].  It carries no
	external configuration values other than those derived gates.
_____________________________________________________________________/*/

if (
	(!isRemoteExecuted) ||
	{isRemoteExecutedJIP} ||
	{remoteExecutedOwner isNotEqualTo 2} ||
	{isServer} ||
	{isDedicated} ||
	{hasInterface}
) exitWith {};
if (!(_this isEqualType []) || {(count _this) isNotEqualTo 2}) exitWith {};
private _version = _this # 0;
private _gates = _this # 1;
if (!(_version isEqualType 0) || {_version isNotEqualTo 1}) exitWith {};
if (!(_gates isEqualType []) || {(count _gates) isNotEqualTo 6}) exitWith {};
if ((_gates findIf {!(_x isEqualType FALSE)}) isNotEqualTo -1) exitWith {};
if (localNamespace getVariable ['QS_diag_hcConfigured',FALSE]) exitWith {};
{
	localNamespace setVariable [_x,(_gates # _forEachIndex)];
} forEach [
	'QS_diag_heartbeat',
	'QS_diag_loopTiming',
	'QS_diag_rpcLog',
	'QS_diag_stateSnapshots',
	'QS_diag_safePos',
	'QS_diag_scriptHistogram'
];
localNamespace setVariable ['QS_diag_hcConfigured',TRUE];
call (missionNamespace getVariable ['QS_fnc_diagStart',{}]);
