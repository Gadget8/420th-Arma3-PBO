/*
Function: TGC_fnc_serverSetChannelMasks

Description:
    Validate a staff channel-mask request on the server and publish the
    apply-only update to clients, including future JIP clients.
*/
if (!isServer || {!isRemoteExecuted}) exitWith {};

private _requestOwner = remoteExecutedOwner;
if (_requestOwner <= 2) exitWith {};

private _requestingPlayer = (
    allPlayers select {
        (owner _x) isEqualTo _requestOwner &&
        {!(_x isKindOf "HeadlessClient_F")}
    }
) param [0, objNull];
if (
    isNull _requestingPlayer ||
    {!((getPlayerUID _requestingPlayer) in (["ALL"] call QS_fnc_whitelist))}
) exitWith {};

private _masks = _this param [0, objNull];
if !(_masks isEqualType []) exitWith {};
if ((count _masks) > 4) exitWith {};

private _valid = true;
private _seen = [];
{
    if (!(_x isEqualType []) || {(count _x) isNotEqualTo 2}) exitWith {_valid = false};

    private _channel = _x param [0, -1];
    private _mask = _x param [1, objNull];
    if (
        !(_channel isEqualType 0) ||
        {!(_channel in [2, 3, 7, 13])} ||
        {_channel in _seen} ||
        {!(_mask isEqualType [])} ||
        {(count _mask) isNotEqualTo 2} ||
        {!((_mask # 0) isEqualType true)} ||
        {!((_mask # 1) isEqualType true)}
    ) exitWith {_valid = false};

    _seen pushBack _channel;
} forEach _masks;
if (!_valid) exitWith {};

[_masks] remoteExec ["TGC_fnc_setChannelMasks", -2, "TGC_fnc_setChannelMasks"];
