if (!isDedicated) exitWith {};
compileScript ['@Apex_cfg\please_enable_filePatching.sqf',TRUE];
call (compileScript ['@Apex_cfg\parameters.sqf']);
['SERVER_CONFIG_READY'] call (missionNamespace getVariable 'QS_fnc_diag');
0 spawn (missionNamespace getVariable 'QS_fnc_config');
