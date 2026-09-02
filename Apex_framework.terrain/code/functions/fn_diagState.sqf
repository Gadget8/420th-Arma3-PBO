/*/
File: fn_diagState.sqf
Author:

	420th rewrite programme, WO-0003

Description:

	Instrument 6, state snapshots.  Every 30 seconds, one line per positional
	record named in docs/plan-of-record.md section 1.2 (the nine records of
	the review's theme T2 section 2.5) plus the three further records the work
	order names.  Started by fn_diag.sqf only when
	QS_missionConfig_diagStateSnapshots is exactly TRUE.

	[DIAG STATE] name=<n> count=<elements> arity=<distinct row lengths> hash=<hashValue of str>

	count is -1 when the name is not defined in its store, 1 for a non-array
	value, and the element count for an array.  arity lists the distinct
	lengths of the array elements that are themselves arrays, ascending, so a
	self-widening tuple record shows more than one value.  hash is
	hashValue (str value), which is a content fingerprint, not an identity.

	No Steam UID is read.  QS_system_AI_owners holds engine network owner ids
	and is logged only as a count, an arity and a hash.
_____________________________________________________________________/*/

scriptName 'QS diag state snapshots';
if (!isServer) exitWith {};
private _absent = '##QS_DIAG_ABSENT##';
private _records = [
	['QS_v_Monitor','server'],
	['QS_virtualSectors_data','mission'],
	['QS_virtualSectors_data_public','mission'],
	['QS_managed_hints','mission'],
	['QS_system_deployments','local'],
	['QS_system_AI_owners','mission'],
	['QS_AI_targetsKnowledge_EAST','mission'],
	['QS_ST_X','mission'],
	['QS_garbageCollector','mission'],
	['QS_logistics_deployedAssets','mission'],
	['QS_smSuccess','mission'],
	['QS_deploy_tickets','fobFlag']
];
for '_i' from 0 to 1 step 0 do {
	uiSleep 30;
	if (!(missionNamespace getVariable ['QS_diag_stateSnapshots',FALSE])) exitWith {};
	{
		_x params ['_name','_store'];
		private _value = switch (_store) do {
			case 'server': {serverNamespace getVariable [_name,_absent]};
			case 'local': {localNamespace getVariable [_name,_absent]};
			case 'fobFlag': {
				private _flag = missionNamespace getVariable ['QS_module_fob_flag',objNull];
				if (isNull _flag) then {_absent} else {_flag getVariable [_name,_absent]}
			};
			default {missionNamespace getVariable [_name,_absent]};
		};
		private _count = -1;
		private _arity = [];
		private _hash = 0;
		if (!(_value isEqualTo _absent)) then {
			_hash = hashValue (str _value);
			if (_value isEqualType []) then {
				_count = count _value;
				{
					if (_x isEqualType []) then {
						private _length = count _x;
						if (!(_length in _arity)) then {_arity pushBack _length;};
					};
				} forEach _value;
				_arity sort TRUE;
			} else {
				_count = 1;
			};
		};
		diag_log format [
			'[DIAG STATE] name=%1 count=%2 arity=%3 hash=%4',
			_name,
			_count,
			_arity,
			_hash
		];
		uiSleep 0.05;
	} forEach _records;
};
