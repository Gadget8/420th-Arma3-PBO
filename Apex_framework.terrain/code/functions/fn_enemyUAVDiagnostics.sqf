/*
File: fn_enemyUAVDiagnostics.sqf

Description:

	Log bounded network and motion state for enemy UAVs created while the
	explicit diagnostics switch is enabled. The delay allows spawn
	initialization and createVehicleCrew to finish before state is sampled.
__________________________________________________*/

if (!isServer) exitWith {};
if ((missionNamespace getVariable ['QS_missionConfig_enemyUAVDiagnosticsEnabled',FALSE]) isNotEqualTo TRUE) exitWith {};
if (missionNamespace getVariable ['QS_enemyUAVDiagnostics_initialized',FALSE]) exitWith {};

missionNamespace setVariable ['QS_enemyUAVDiagnostics_initialized',TRUE,FALSE];
missionNamespace setVariable ['QS_enemyUAVDiagnostics_pendingWorkers',0,FALSE];
missionNamespace setVariable ['QS_enemyUAVDiagnostics_throttledCount',0,FALSE];
missionNamespace setVariable ['QS_enemyUAVDiagnostics_nextThrottleLog',0,FALSE];

QS_enemyUAVDiagnostics_entityCreatedEH = addMissionEventHandler [
	'EntityCreated',
	{
		params [['_entity',objNull,[objNull]]];

		if (
			((missionNamespace getVariable ['QS_missionConfig_enemyUAVDiagnosticsEnabled',FALSE]) isNotEqualTo TRUE) ||
			{isNull _entity} ||
			{!(unitIsUAV _entity)}
		) exitWith {};

		private _pendingWorkers = missionNamespace getVariable ['QS_enemyUAVDiagnostics_pendingWorkers',0];
		private _maxPendingWorkers = 8;

		if (_pendingWorkers >= _maxPendingWorkers) exitWith {
			private _throttledCount =
				(missionNamespace getVariable ['QS_enemyUAVDiagnostics_throttledCount',0]) + 1;
			missionNamespace setVariable [
				'QS_enemyUAVDiagnostics_throttledCount',
				_throttledCount,
				FALSE
			];

			if (diag_tickTime >= (missionNamespace getVariable ['QS_enemyUAVDiagnostics_nextThrottleLog',0])) then {
				diag_log text format [
					'QS_ENEMY_UAV_DIAGNOSTICS_THROTTLED dropped=%1 pending=%2 cap=%3',
					_throttledCount,
					_pendingWorkers,
					_maxPendingWorkers
				];
				missionNamespace setVariable ['QS_enemyUAVDiagnostics_throttledCount',0,FALSE];
				missionNamespace setVariable [
					'QS_enemyUAVDiagnostics_nextThrottleLog',
					diag_tickTime + 60,
					FALSE
				];
			};
		};

		missionNamespace setVariable [
			'QS_enemyUAVDiagnostics_pendingWorkers',
			_pendingWorkers + 1,
			FALSE
		];

		[_entity] spawn {
			params ['_uav'];
			uiSleep 1;

			missionNamespace setVariable [
				'QS_enemyUAVDiagnostics_pendingWorkers',
				((missionNamespace getVariable ['QS_enemyUAVDiagnostics_pendingWorkers',1]) - 1) max 0,
				FALSE
			];

			if (
				((missionNamespace getVariable ['QS_missionConfig_enemyUAVDiagnosticsEnabled',FALSE]) isNotEqualTo TRUE) ||
				{isNull _uav}
			) exitWith {};

			private _crew = crew _uav;
			private _liveSide = if (_crew isNotEqualTo []) then {
				side (group (_crew # 0))
			} else {
				side _uav
			};
			private _configSide = [EAST,WEST,RESISTANCE,CIVILIAN,sideUnknown] param [
				getNumber ((configOf _uav) >> 'side'),
				sideUnknown
			];

			if (!((_liveSide in [EAST,RESISTANCE]) || {_configSide in [EAST,RESISTANCE]})) exitWith {};

			diag_log text format [
				'QS_ENEMY_UAV_SPAWN class="%1" netId="%2" owner=%3 position=%4 velocity=%5 orientation=[heading=%6,vectorDir=%7,vectorUp=%8] side=%9 configSide=%10 local=%11',
				typeOf _uav,
				netId _uav,
				owner _uav,
				getPosWorld _uav,
				velocity _uav,
				getDir _uav,
				vectorDir _uav,
				vectorUp _uav,
				_liveSide,
				_configSide,
				local _uav
			];
		};
	}
];
