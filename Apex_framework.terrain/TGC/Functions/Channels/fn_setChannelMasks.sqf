/*
Function: TGC_fnc_setChannelMasks

Description:
    Set and apply channel masks.
    To clear all channel masks, pass an empty array to this function.

Parameters:
    Array masks:
        An array in the format [[id, [text, von]], ...].

Author:
    thegamecracks

*/
private _masks = _this param [0, objNull];

// This is an apply endpoint. Only the server may send a remote update; the
// staff GUI may still call it locally for immediate feedback.
if (isRemoteExecuted && {remoteExecutedOwner isNotEqualTo 2}) exitWith {};
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

if (!isNil "TGC_channels_masks" && {TGC_channels_masks isEqualTo _masks}) exitWith {};

TGC_channels_masks = _masks;
[] call TGC_fnc_refreshChannels;

diag_log text format ["%1: Updated to %2", _fnc_scriptName, _masks];
