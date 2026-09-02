/*/
File: fn_diagLoop.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Instrument 2, loop pass timing.  Two call sites per instrumented loop.

		['<name>'] call QS_fnc_diagLoop;            // top of the pass
		['<name>',<items>] call QS_fnc_diagLoop;    // bottom of the pass

	The one-argument form opens a pass: it increments the pass counter for
	<name> and records diag_tickTime.  The two-argument form closes it and
	writes one line:

	[DIAG LOOP] <name> pass=<n> ms=<elapsed> items=<count>

	Pass state lives in the hashmap QS_diag_loopState, keyed by <name>, so
	nested loops on the same machine do not interfere.  A close with no
	matching open reports ms=-1.
_____________________________________________________________________/*/

if (!(missionNamespace getVariable ['QS_diag_loopTiming',FALSE])) exitWith {};
params [['_name','',['']],'_items'];
if (_name isEqualTo '') exitWith {};
private _state = missionNamespace getVariable ['QS_diag_loopState',createHashMap];
if (isNil '_items') exitWith {
	private _row = _state getOrDefault [_name,[0,0]];
	_row set [0,((_row # 0) + 1)];
	_row set [1,diag_tickTime];
	_state set [_name,_row];
	missionNamespace setVariable ['QS_diag_loopState',_state,FALSE];
};
private _row = _state getOrDefault [_name,[0,-1]];
private _elapsed = -1;
if ((_row # 1) >= 0) then {
	_elapsed = ((diag_tickTime - (_row # 1)) * 1000);
};
diag_log format [
	'[DIAG LOOP] %1 pass=%2 ms=%3 items=%4',
	_name,
	(_row # 0),
	(_elapsed toFixed 2),
	_items
];
