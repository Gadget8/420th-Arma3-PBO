/*
Function: TGC_fnc_lockDroneByUID

Description:
    Apply a server-authorized drone lock on a client.

Parameters:
    Object drone:
        The drone to be locked.
    String uid:
        The player UID to lock the drone to, or "ALL" to lock for all players.
        If an empty string is passed, the drone will be unlocked.

Author:
    thegamecracks

*/
private _drone = _this param [0, objNull, [objNull]];
private _uid = _this param [1, "", [""]];

if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
if (isNull _drone || {!unitIsUAV _drone} || {(count _uid) > 64}) exitWith {};

if (isNull player) exitWith {};

private _locked = !(_uid in ["", getPlayerUID player]);
if (_locked) then {
    player disableUAVConnectability [_drone, false];
} else {
    player enableUAVConnectability [_drone, false];
};
