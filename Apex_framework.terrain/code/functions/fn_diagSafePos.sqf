/*/
File: fn_diagSafePos.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Instrument 4, safe-position failures.  Called from the two 30 second
	deadline branches of fn_findRandomPos.sqf, the branches that abandon the
	search and return the terrain's safePositionAnchor.

		[_timeout,_forceFind,<caller>] call QS_fnc_diagSafePos;

	[DIAG SAFEPOS] caller=<scriptName or unknown> ms=<elapsed> forceFind=<bool>

	_timeout is fn_findRandomPos's own deadline variable (diag_tickTime + 30 at
	entry), so the elapsed search time is (diag_tickTime - _timeout + 30)
	seconds and no new variable is added to that function.

	<caller> is the BIS function framework's _fnc_scriptNameParent read at the
	call site, which is the name of the function that called
	QS_fnc_findRandomPos.  Where the framework did not set it the site passes
	'unknown'.
_____________________________________________________________________/*/

if (!(missionNamespace getVariable ['QS_diag_safePos',FALSE])) exitWith {};
params [['_timeout',0,[0]],['_forceFind',FALSE,[FALSE]],['_caller','unknown',['']]];
if (_caller isEqualTo '') then {_caller = 'unknown';};
diag_log format [
	'[DIAG SAFEPOS] caller=%1 ms=%2 forceFind=%3',
	_caller,
	((((diag_tickTime - _timeout) + 30) * 1000) toFixed 2),
	_forceFind
];
