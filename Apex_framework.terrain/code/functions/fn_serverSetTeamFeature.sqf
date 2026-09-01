/*/
File: fn_serverSetTeamFeature.sqf

Description:

	Set the global team-map or name-tag feature state without transmitting code
	through public variables. The fixed JIP IDs retain only the latest state.
__________________________________________________/*/

if (!isServer) exitWith {};

private _authorized = !isRemoteExecuted || {remoteExecutedOwner isEqualTo 2};
if (isRemoteExecuted && {remoteExecutedOwner > 2}) then {
	private _requestOwner = remoteExecutedOwner;
	private _requestingPlayer = objNull;
	{
		if ((owner _x) isEqualTo _requestOwner) exitWith {
			_requestingPlayer = _x;
		};
	} forEach allPlayers;
	if (
		(!isNull _requestingPlayer) &&
		{
			(getPlayerUID _requestingPlayer) in
			(['ALL'] call (missionNamespace getVariable ['QS_fnc_whitelist',{[]}]))
		}
	) then {
		_authorized = TRUE;
	};
};
if (!_authorized) exitWith {};

params [
	['_feature','',['']],
	['_enabled',TRUE,[TRUE]]
];

_feature = toUpperANSI _feature;
private _jipID = switch (_feature) do {
	case 'MAP_ICONS': {'QS_TEAM_FEATURE_MAP_ICONS'};
	case 'NAME_TAGS': {'QS_TEAM_FEATURE_NAME_TAGS'};
	default {''};
};

if (_jipID isEqualTo '') exitWith {};

[_feature,_enabled] remoteExecCall ['QS_fnc_clientSetTeamFeature',-2,_jipID];
