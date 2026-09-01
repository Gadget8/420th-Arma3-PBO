/*
Function: TGC_fnc_refreshStaffChannelAccess

Description:
    Reconcile Side VON and Staff custom-channel access with the client's
    current ALL whitelist membership. This may be called after a late
    database whitelist response as well as during normal player setup.

Author:
    420th

*/
if (!hasInterface) exitWith {};
if !(missionNamespace getVariable ["QS_client_channelAccessInitialized", false]) exitWith {};

private _isStaff = (getPlayerUID player) in (["ALL"] call QS_fnc_whitelist);

// Side remains readable by everyone, but only staff may use its VON.
[1, [true, _isStaff]] call TGC_fnc_enableChannel;
[] call TGC_fnc_refreshChannels;

// The first custom radio channel is the Staff channel.
if (_isStaff) then {
    [1, 1] call QS_fnc_clientRadio;
} else {
    [0, 1] call QS_fnc_clientRadio;
};
