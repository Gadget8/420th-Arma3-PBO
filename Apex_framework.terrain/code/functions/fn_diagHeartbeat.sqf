/*/
File: fn_diagHeartbeat.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Instrument 1, server heartbeat.  One RPT line per second.  Started by
	fn_diag.sqf only when QS_missionConfig_diagHeartbeat is exactly TRUE.
	No per-frame handler is registered; this is a scheduled loop whose tail is
	uiSleep 1.

	[DIAG HB] t=<diag_tickTime> frame=<diag_frameNo> fps=<diag_fps>
	          fpsmin=<diag_fpsMin> players=<count allPlayers>
	          units=<count allUnits> vehicles=<count vehicles>
	          scripts=<count diag_activeSQFScripts>
_____________________________________________________________________/*/

scriptName 'QS diag heartbeat';
if (!isServer) exitWith {};
for '_i' from 0 to 1 step 0 do {
	if (!(missionNamespace getVariable ['QS_diag_heartbeat',FALSE])) exitWith {};
	diag_log format [
		'[DIAG HB] t=%1 frame=%2 fps=%3 fpsmin=%4 players=%5 units=%6 vehicles=%7 scripts=%8',
		diag_tickTime,
		diag_frameNo,
		diag_fps,
		diag_fpsMin,
		(count allPlayers),
		(count allUnits),
		(count vehicles),
		(count diag_activeSQFScripts)
	];
	uiSleep 1;
};
