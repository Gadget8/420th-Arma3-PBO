/*/
File: fn_diagHeartbeat.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Instrument 1, server/HC heartbeat.  One RPT line per second and per
	instrumented process.  Started only when the server-derived heartbeat gate
	is TRUE on that process.
	No per-frame handler is registered; this is a scheduled loop whose tail is
	uiSleep 1.

	[DIAG HB] t=<diag_tickTime> frame=<diag_frameNo> fps=<diag_fps>
	          fpsmin=<diag_fpsMin> players=<count allPlayers>
	          units=<count allUnits> vehicles=<count vehicles>
	          scripts=<count diag_activeSQFScripts> role=<server|hc>
	          owner=<clientOwner> serverTime=<serverTime>
	          localUnits=<locally owned units> localGroups=<locally owned groups>
	          humans=<human players> hcs=<connected headless clients>
_____________________________________________________________________/*/

scriptName 'QS diag heartbeat';
if (hasInterface) exitWith {};
private _role = ['hc','server'] select isServer;
for '_i' from 0 to 1 step 0 do {
	if (!(localNamespace getVariable ['QS_diag_heartbeat',FALSE])) exitWith {};
	private _allPlayers = allPlayers;
	private _allUnits = allUnits;
	private _allGroups = allGroups;
	private _hcCount = {_x isKindOf 'HeadlessClient_F'} count _allPlayers;
	diag_log format [
		'[DIAG HB] t=%1 frame=%2 fps=%3 fpsmin=%4 players=%5 units=%6 vehicles=%7 scripts=%8 role=%9 owner=%10 serverTime=%11 localUnits=%12 localGroups=%13 humans=%14 hcs=%15',
		diag_tickTime,
		diag_frameNo,
		diag_fps,
		diag_fpsMin,
		(count _allPlayers),
		(count _allUnits),
		(count vehicles),
		(count diag_activeSQFScripts),
		_role,
		clientOwner,
		serverTime,
		({local _x} count _allUnits),
		({local _x} count _allGroups),
		((count _allPlayers) - _hcCount),
		_hcCount
	];
	uiSleep 1;
};
