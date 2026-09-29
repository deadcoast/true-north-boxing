extends SceneTree
## godot --headless --path engine/greybox -s tools/drive_automation_audio.gd -- episode
## Rendered invocation must include --audio-driver Dummy. No audible test tones.
const Policy := preload("res://tools/automation_audio.gd")
var failures := 0
var checks := 0

func _initialize() -> void: _run.call_deferred()

func _check(label: String, condition: bool) -> void:
	checks += 1
	if not condition: failures += 1
	print("[%s] %s" % ["PASS" if condition else "FAIL", label])

func _run() -> void:
	for args in [PackedStringArray(), PackedStringArray(["episode"]), PackedStringArray(["club"]), PackedStringArray(["welcome"])]:
		_check("normal player entry keeps its audio choice: " + str(args), not Policy.should_mute([], args))
	for args in [PackedStringArray(["--headless"]), PackedStringArray(["-s", "tools/drive_episode.gd"]), PackedStringArray(["--script", "C:\\game\\tools\\drive_readiness.gd"]), PackedStringArray(["-s", "res://tools/drive_club_journey.gd"])]:
		_check("direct automation recognized: " + str(args), Policy.should_mute(args, []))
	for mode in ["automation", "smoke", "determinism", "geometry", "audit", "faucets", "demo"]:
		_check("automated main-scene mode recognized: " + mode, Policy.should_mute([], [mode]))
	_check("ordinary script path is not a test driver", not Policy.should_mute(["-s", "tools/open_club.gd"], ["club"]))
	var scene: Node = load("res://main.tscn").instantiate()
	root.add_child(scene); scene.set_process(false)
	await process_frame; await process_frame
	_check("new process mutes Master before the title is ready", AudioServer.is_bus_mute(0))
	scene.episode.new_episode("en")
	await process_frame
	_check("archive ambience still plays behind the output mute", scene.episode.staging.ambience.playing and AudioServer.is_bus_mute(0))
	scene.fight_feedback.play("tell", true)
	await process_frame
	_check("sound feedback remains exercised without unmuting output", scene.fight_feedback.played.get("tell", 0) == 1 and AudioServer.is_bus_mute(0))
	print("AUTOMATION AUDIO ", checks, " checks; ", failures, " failures")
	print("DRIVE :: GREEN" if failures == 0 else "DRIVE :: RED")
	quit(0 if failures == 0 else 1)
