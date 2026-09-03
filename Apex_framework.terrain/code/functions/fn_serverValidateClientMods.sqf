/*
File: fn_serverValidateClientMods.sqf

Description:

	Validate a client's reported non-official mods against the server's
	Workshop-ID and full-hash allowlists configured in @Apex_cfg\parameters.sqf.

	This is a cooperative-client policy check, not an anti-cheat boundary:
	clients can suppress or falsify self-reported data.
__________________________________________________*/

if ((!isServer) || {!isRemoteExecuted}) exitWith {};

private _clientOwner = remoteExecutedOwner;
if (_clientOwner <= 2) exitWith {};

// Default off. Only the exact Boolean TRUE enables enforcement.
if (
	(missionNamespace getVariable [
		'QS_missionConfig_clientWorkshopModEnforcementEnabled',
		FALSE
	]) isNotEqualTo TRUE
) exitWith {};

private _clientPlayer = objNull;
{
	if ((owner _x) isEqualTo _clientOwner) exitWith {
		_clientPlayer = _x;
	};
} forEach allPlayers;

if (isNull _clientPlayer) exitWith {};

private _clientUID = getPlayerUID _clientPlayer;
if (_clientUID isEqualTo '') exitWith {};

// The normal client path reports once. This also bounds repeated RemoteExec use.
if (_clientPlayer getVariable ['QS_clientWorkshopModReportHandled',FALSE]) exitWith {};
_clientPlayer setVariable ['QS_clientWorkshopModReportHandled',TRUE,FALSE];

// Missing, collectively empty, oversized, or malformed configuration disables
// enforcement. Empty individual lists are valid so either approval mechanism
// can be used by itself.
private _allowedWorkshopIDs = missionNamespace getVariable [
	'QS_missionConfig_allowedClientWorkshopIds',
	objNull
];
private _allowedModHashes = missionNamespace getVariable [
	'QS_missionConfig_allowedClientModHashes',
	objNull
];
private _emptyPayloadSHA1 = 'da39a3ee5e6b4b0d3255bfef95601890afd80709';

private _allowlistInvalid =
	!(_allowedWorkshopIDs isEqualType []) ||
	{!(_allowedModHashes isEqualType [])};
if (!_allowlistInvalid) then {
	_allowlistInvalid =
		(
			((count _allowedWorkshopIDs) isEqualTo 0) &&
			{(count _allowedModHashes) isEqualTo 0}
		) ||
		{(count _allowedWorkshopIDs) > 256} ||
		{(count _allowedModHashes) > 256} ||
		{
			(_allowedWorkshopIDs findIf {
				!(_x isEqualType '') ||
				{(count _x) > 20} ||
				{!(_x regexMatch '^[1-9][0-9]{0,19}$')}
			}) isNotEqualTo -1
		} ||
		{
			(_allowedModHashes findIf {
				!(_x isEqualType '') ||
				{(count _x) isNotEqualTo 40} ||
				{!((toLowerANSI _x) regexMatch '^[0-9a-f]{40}$')} ||
				{(toLowerANSI _x) isEqualTo _emptyPayloadSHA1}
			}) isNotEqualTo -1
		};
};

if (_allowlistInvalid) exitWith {
	if !(
		missionNamespace getVariable [
			'QS_clientWorkshopModPolicyConfigErrorLogged',
			FALSE
		]
	) then {
		missionNamespace setVariable [
			'QS_clientWorkshopModPolicyConfigErrorLogged',
			TRUE,
			FALSE
		];
		diag_log (
			'***** CLIENT MOD POLICY DISABLED ***** ' +
			'Workshop-ID and mod-hash allowlists must be arrays of at most ' +
			'256 canonical values each, with at least one approved value; ' +
			'the empty-payload SHA-1 must not be allowlisted *****'
		);
	};
};

private _normalizedAllowedModHashes = _allowedModHashes apply {toLowerANSI _x};

// Expected RemoteExec argument shape: [ [ [itemID,modName,fullHash], ... ] ].
if !(_this isEqualType []) exitWith {
	diag_log format [
		'***** CLIENT MOD REPORT REJECTED ***** owner %1 * malformed arguments *****',
		_clientOwner
	];
};

if ((count _this) isNotEqualTo 1) exitWith {
	diag_log format [
		'***** CLIENT MOD REPORT REJECTED ***** owner %1 * argument count %2 *****',
		_clientOwner,
		count _this
	];
};

private _clientWorkshopMods = _this # 0;
if !(_clientWorkshopMods isEqualType []) exitWith {
	diag_log format [
		'***** CLIENT MOD REPORT REJECTED ***** owner %1 * report is not an array *****',
		_clientOwner
	];
};

private _reportCount = count _clientWorkshopMods;
if (_reportCount > 128) exitWith {
	diag_log format [
		'***** CLIENT MOD REPORT REJECTED ***** owner %1 * entry count %2 exceeds 128 *****',
		_clientOwner,
		_reportCount
	];
};

private _invalidEntryIndex = _clientWorkshopMods findIf {
	!(_x isEqualType []) ||
	{(count _x) isNotEqualTo 3} ||
	{!((_x # 0) isEqualType '')} ||
	{!((_x # 1) isEqualType '')} ||
	{!((_x # 2) isEqualType '')} ||
	{(count (_x # 0)) > 20} ||
	{(count (_x # 1)) > 256} ||
	{(count (_x # 2)) > 40}
};

if (_invalidEntryIndex isNotEqualTo -1) exitWith {
	diag_log format [
		'***** CLIENT MOD REPORT REJECTED ***** owner %1 * malformed entry index %2 *****',
		_clientOwner,
		_invalidEntryIndex
	];
};

private _disallowedMods = [];
{
	_x params ['_workshopID','_modName','_modHash'];
	private _isCanonicalWorkshopID = _workshopID regexMatch '^[1-9][0-9]{0,19}$';
	private _normalizedModHash = toLowerANSI _modHash;
	private _isCanonicalModHash =
		((count _normalizedModHash) isEqualTo 40) &&
		{_normalizedModHash regexMatch '^[0-9a-f]{40}$'} &&
		{_normalizedModHash isNotEqualTo _emptyPayloadSHA1};
	private _workshopAllowed =
		_isCanonicalWorkshopID &&
		{_workshopID in _allowedWorkshopIDs};
	private _hashAllowed =
		_isCanonicalModHash &&
		{_normalizedModHash in _normalizedAllowedModHashes};

	if (
		(!_workshopAllowed) &&
		{!_hashAllowed}
	) then {
		private _safeModName = toString (
			(toArray (_modName select [0,64])) select {
				((_x >= 48) && {_x <= 57}) ||
				{((_x >= 65) && {_x <= 90})} ||
				{((_x >= 97) && {_x <= 122})} ||
				{_x in [32,40,41,43,45,46,64,91,93,95]}
			}
		);
		private _safeWorkshopID = ['invalid-id',_workshopID] select _isCanonicalWorkshopID;
		private _safeModHash = if (_modHash isEqualTo '') then {
			'no-hash'
		} else {
			['invalid-hash',_normalizedModHash] select _isCanonicalModHash
		};

		_disallowedMods pushBackUnique [_safeWorkshopID,_safeModName,_safeModHash];
	};
} forEach _clientWorkshopMods;

if (_disallowedMods isEqualTo []) exitWith {};

private _loggedMods = _disallowedMods select [0,8];
diag_log format [
	'***** CLIENT MODS REJECTED ***** owner %1 * mods %2 * total %3 *****',
	_clientOwner,
	_loggedMods,
	count _disallowedMods
];

private _shownMods = _disallowedMods select [0,4];
private _disallowedLabels = _shownMods apply {
	_x params ['_workshopID','_modName'];
	if (_modName isEqualTo '') then {
		format ['Workshop %1',_workshopID]
	} else {
		format ['%1 [%2]',_modName,_workshopID]
	};
};

private _remainingCount = (count _disallowedMods) - (count _shownMods);
private _remainingSuffix = ['',format [', +%1 more',_remainingCount]] select (_remainingCount > 0);
private _kickReason = format [
	'Kicked: Mods not allowed: %1%2',
	_disallowedLabels joinString ', ',
	_remainingSuffix
];

[_kickReason] remoteExecCall ['QS_fnc_clientModKickWarning',_clientOwner,FALSE];

[_clientOwner,_clientUID,_kickReason] spawn {
	params ['_clientOwner','_clientUID','_kickReason'];
	uiSleep 5;

	// Do not kick a different connection if the original owner disconnected.
	if (
		(allPlayers findIf {
			((owner _x) isEqualTo _clientOwner) &&
			{(getPlayerUID _x) isEqualTo _clientUID}
		}) isEqualTo -1
	) exitWith {};

	(call (uiNamespace getVariable 'QS_fnc_serverCommandPassword'))
		serverCommand format [
			'#kick %1 "%2"',
			_clientOwner,
			_kickReason
		];
};
