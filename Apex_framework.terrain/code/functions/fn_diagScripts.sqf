/*/
File: fn_diagScripts.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Instrument 5, active-script histogram.  Every 60 seconds, group
	diag_activeSQFScripts by script name and write the twenty largest groups
	on one line.  Started by fn_diag.sqf only when
	QS_missionConfig_diagScriptHistogram is exactly TRUE.

	[DIAG SCRIPTS] total=<n> distinct=<n> top=[<name>=<count>, ...]

	Scripts that never called scriptName are grouped under 'unnamed'; T3 of
	the review measures that as 839 of 902 files.
_____________________________________________________________________/*/

scriptName 'QS diag script histogram';
if (!isServer) exitWith {};
for '_i' from 0 to 1 step 0 do {
	uiSleep 60;
	if (!(missionNamespace getVariable ['QS_diag_scriptHistogram',FALSE])) exitWith {};
	private _active = diag_activeSQFScripts;
	private _counts = createHashMap;
	{
		private _name = 'unnamed';
		if (_x isEqualType []) then {
			_name = (_x select {(_x isEqualType '')}) param [0,'unnamed'];
			if (_name isEqualTo '') then {_name = 'unnamed';};
		};
		_counts set [_name,((_counts getOrDefault [_name,0]) + 1)];
	} forEach _active;
	private _rows = [];
	{
		_rows pushBack [_y,_x];
	} forEach _counts;
	_rows sort FALSE;
	diag_log format [
		'[DIAG SCRIPTS] total=%1 distinct=%2 top=%3',
		(count _active),
		(count _rows),
		((_rows select [0,20]) apply {(format ['%1=%2',(_x # 1),(_x # 0)])})
	];
};
