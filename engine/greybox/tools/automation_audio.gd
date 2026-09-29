extends RefCounted
## Automated processes must never take over the user's speakers. This is an
## in-process guard for directly launched drivers; runners also select Dummy.
## Nothing is saved to the player's controls, audio settings or Windows mixer.

static func should_mute(engine_args: PackedStringArray, user_args: PackedStringArray) -> bool:
	if "--headless" in engine_args: return true
	for argument in engine_args:
		var path := argument.replace("\\", "/").to_lower()
		if path.get_file().begins_with("drive_") and path.ends_with(".gd"): return true
	for mode in ["automation", "smoke", "determinism", "geometry", "audit", "faucets", "demo"]:
		if mode in user_args: return true
	return false

static func configure() -> bool:
	var silent := should_mute(OS.get_cmdline_args(), OS.get_cmdline_user_args())
	if silent: AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	return silent
