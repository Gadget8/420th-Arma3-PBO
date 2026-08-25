/*
File: fn_serverGetDonatorSkins.sqf
Author:

	Seathre

Description:

	Returns a player's completed Cosmetic Commissary purchases.
__________________________________________________________*/

if (!isServer || {!isRemoteExecuted}) exitWith {};

params [['_unit',objNull],['_uid','']];

if (
	(isNull _unit) ||
	{!isPlayer _unit} ||
	{(owner _unit) isNotEqualTo remoteExecutedOwner} ||
	{_uid isNotEqualTo (getPlayerUID _unit)} ||
	{(count _uid) isNotEqualTo 17}
) exitWith {};

private _requestOwner = remoteExecutedOwner;

// State per UID: [next request time, query in flight, cache expiry, skins,
// waiting owners]. Reserve the state in this unscheduled RemoteExec handler so
// simultaneous requests cannot all spawn database workers.
private _states = missionNamespace getVariable ['TGC_donatorSkinRequestStates',createHashMap];
missionNamespace setVariable ['TGC_donatorSkinRequestStates',_states,FALSE];
private _now = diag_tickTime;
private _state = _states getOrDefault [_uid,[0,FALSE,0,[],[]]];
_state params ['_nextRequest','_inFlight','_cacheExpiry','_cachedSkins','_waitingOwners'];

if (_cacheExpiry > _now) exitWith {
	['Data',_cachedSkins] remoteExecCall ['QS_fnc_clientMenuDonatorSkins',_requestOwner];
};
if (_inFlight) exitWith {
	_waitingOwners pushBackUnique _requestOwner;
	_states set [_uid,[_nextRequest,TRUE,_cacheExpiry,_cachedSkins,_waitingOwners]];
};
if (_nextRequest > _now) exitWith {};

_waitingOwners pushBackUnique _requestOwner;
_states set [_uid,[_now + 5,TRUE,_cacheExpiry,_cachedSkins,_waitingOwners]];
[_unit,_uid,_requestOwner] spawn {
	params ['_unit','_uid','_requestOwner'];
	private _skins = [];
	private _querySucceeded = FALSE;
	private _fn_slugify = {
		params ['_value'];
		private _slug = '';
		private _lastWasSeparator = FALSE;
		{
			private _isAlphaNumeric = (
				((_x >= 48) && {_x <= 57}) ||
				{((_x >= 65) && {_x <= 90})} ||
				{((_x >= 97) && {_x <= 122})}
			);
			if (_isAlphaNumeric) then {
				_slug = _slug + (toString [_x]);
				_lastWasSeparator = FALSE;
			} else {
				if ((_slug isNotEqualTo '') && {!_lastWasSeparator}) then {
					_slug = _slug + '_';
					_lastWasSeparator = TRUE;
				};
			};
		} forEach (toArray _value);
		if (_lastWasSeparator) then {
			_slug = _slug select [0,(count _slug) - 1];
		};
		if (_slug isEqualTo '') then {
			_slug = 'skin';
		};
		toLowerANSI _slug
	};
	private _fn_isPaaFileName = {
		params ['_fileName'];
		private _normalizedFileName = toLowerANSI _fileName;
		(
			((count _fileName) >= 4) &&
			{_normalizedFileName select [(count _normalizedFileName) - 4,4] isEqualTo '.paa'}
		)
	};
	if (missionNamespace getVariable ['TGC_db_ready',FALSE]) then {
		try {
			private _rows = ['getPlayerCosmeticSkins',[_uid]] call TGC_fnc_dbQuery;
			if (isNil '_rows') then {
				throw format [
					'TGC_fnc_dbQuery returned nil (isServer=%1, isRemoteExecuted=%2, canSuspend=%3). Verify the patched TGC\Functions\Database\fn_dbQuery.sqf is included in the live mission.',
					isServer,
					isRemoteExecuted,
					canSuspend
				];
			};
			if !(_rows isEqualType []) then {
				throw format ['getPlayerCosmeticSkins returned an unexpected value: %1',str _rows];
			};
			{
				_x params [['_displayName',''],['_fileName',''],['_vehicleName',''],['_vehicleClassIds',''],['_texturePathList','']];
				private _fileNames = [];
				{
					if ([_x] call _fn_isPaaFileName) then {
						_fileNames pushBackUnique _x;
					};
				} forEach (_texturePathList splitString (toString [9,10,13,32,34,44,47,91,92,93]));
				if ((_fileNames isEqualTo []) && {[_fileName] call _fn_isPaaFileName}) then {
					_fileNames pushBack _fileName;
				};
				if ((_displayName isNotEqualTo '') && {_fileNames isNotEqualTo []}) then {
					private _textureSlots = _fileNames apply {
						[format ['media\commissary\%1',_x]]
					};
					if ((count _textureSlots) isEqualTo 1) then {
						(_textureSlots # 0) pushBackUnique (format ['media\commissary\%1.paa',[_displayName] call _fn_slugify]);
					};
					_skins pushBack [
						_displayName,
						_textureSlots,
						_vehicleName,
						(_vehicleClassIds splitString ', ') select {_x isNotEqualTo ''}
					];
				};
			} forEach _rows;
			_querySucceeded = TRUE;
		} catch {
			diag_log format ['fn_serverGetDonatorSkins.sqf: Failed to load skins for %1: %2',_uid,_exception];
		};
	};

	// Include every owner that requested this UID while the query was in flight.
	private _states = missionNamespace getVariable ['TGC_donatorSkinRequestStates',createHashMap];
	private _state = _states getOrDefault [_uid,[0,TRUE,0,[],[_requestOwner]]];
	_state params ['_nextRequest','','','', '_waitingOwners'];
	private _cacheDuration = [15,300] select _querySucceeded;
	private _cacheExpiry = diag_tickTime + _cacheDuration;
	_states set [_uid,[_nextRequest,FALSE,_cacheExpiry,_skins,[]]];
	{
		private _ownerId = _x;
		private _matchingPlayer = allPlayers findIf {
			(owner _x isEqualTo _ownerId) && {(getPlayerUID _x) isEqualTo _uid}
		};
		if (_matchingPlayer isNotEqualTo -1) then {
			['Data',_skins] remoteExecCall ['QS_fnc_clientMenuDonatorSkins',_ownerId];
		};
	} forEach _waitingOwners;
};
