/*
Function: TGC_fnc_serverLockDroneByUID

Description:
    Validate a drone-lock request on the server, publish its owner, and ask
    clients to apply the resulting UAV-connectability state.
*/
if (!isServer) exitWith {};

private _drone = _this param [0, objNull, [objNull]];
private _uid = _this param [1, "", [""]];
if (isNull _drone || {!unitIsUAV _drone} || {(count _uid) > 64}) exitWith {};

private _authorized = !isRemoteExecuted || {remoteExecutedOwner isEqualTo 2};
if (isRemoteExecuted && {remoteExecutedOwner > 2}) then {
    private _requestOwner = remoteExecutedOwner;
    private _requestingPlayer = (
        allPlayers select {
            (owner _x) isEqualTo _requestOwner &&
            {!(_x isKindOf "HeadlessClient_F")}
        }
    ) param [0, objNull];

    if (
        !isNull _requestingPlayer &&
        {_uid isNotEqualTo ""} &&
        {_uid isEqualTo (getPlayerUID _requestingPlayer)} &&
        {
            ((owner _drone) isEqualTo _requestOwner) ||
            {(_drone getVariable ["QS_spawnMenu_spawnedBy", ""]) isEqualTo _uid}
        }
    ) then {
        _authorized = true;
    };
};
if (!_authorized) exitWith {};

_drone setVariable ["TGC_drones_owner", _uid, true];
[_drone, _uid] remoteExec ["TGC_fnc_lockDroneByUID", -2, false];
