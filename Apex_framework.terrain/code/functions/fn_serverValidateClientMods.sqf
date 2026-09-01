/*
File: fn_serverValidateClientMods.sqf

Description:

	Kick clients that report a Steam Workshop mod which is not in the server
	allowlist configured in @Apex_cfg\parameters.sqf.
__________________________________________________*/

if ((!isServer) || {!isRemoteExecuted}) exitWith {};

private _clientOwner = remoteExecutedOwner;
if (_clientOwner <= 2) exitWith {};

params [['_clientWorkshopMods',[],[[]]]];
private _allowedWorkshopIDs = missionNamespace getVariable ['QS_missionConfig_allowedClientWorkshopIds',[]];

private _disallowedMods = [];
{
	if ((_x isEqualType []) && {(count _x) >= 2}) then {
		private _workshopID = _x param [0,'',['']];
		private _modName = _x param [1,'',['']];
		if ((_workshopID in ['','0']) || {!(_workshopID in _allowedWorkshopIDs)}) then {
			_disallowedMods pushBack [_workshopID,_modName];
		};
	};
} forEach _clientWorkshopMods;

if (_disallowedMods isEqualTo []) exitWith {};

private _disallowedLabels = [];
{
	_x params ['_workshopID','_modName'];

	// Only put printable ASCII in a server command and bound each mod name.
	private _safeModName = toString ((toArray _modName) select {
		(_x >= 32) && {_x <= 126} && {_x isNotEqualTo 34} && {_x isNotEqualTo 35}
	});
	_safeModName = _safeModName select [0,80];
	private _fallbackID = [_workshopID,'0'] select (_workshopID isEqualTo '');
	_disallowedLabels pushBack ([_fallbackID,_safeModName] select (_safeModName isNotEqualTo ''));
} forEach _disallowedMods;

diag_log format [
	'***** CLIENT MODS REJECTED ***** owner %1 * mods %2 *****',
	_clientOwner,
	_disallowedMods
];

private _kickReason = format ['Kicked : Mods not allowed: %1',_disallowedLabels joinString ', '];
[_kickReason] remoteExecCall ['QS_fnc_clientModKickWarning',_clientOwner,FALSE];

[_clientOwner,_kickReason] spawn {
	params ['_clientOwner','_kickReason'];
	uiSleep 5;
	(call (uiNamespace getVariable 'QS_fnc_serverCommandPassword')) serverCommand format [
		'#kick "%1" "%2"',
		_clientOwner,
		_kickReason
	];
};
