extends SceneTree
# Presentation-only framing probe. This does not qualify earned story progression.
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://main.tscn").instantiate(); root.add_child(scene); scene.set_process(false)
	await process_frame; await process_frame
	scene.episode.new_episode("en")
	scene.episode._show_world()
	for bar in scene.episode.bars: bar.hide()
	scene.episode.staging.begin("letter", 11)
	scene.episode.panel.hide()
	for i in 180: scene.episode.staging.frame(1.0 / 60.0)
	await process_frame; await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://letter-pinned-final.png")
	scene.episode.staging.begin("tag", 0)
	for i in 180:
		scene.episode.staging.frame(1.0 / 60.0)
		if i in [18, 59, 161]:
			await process_frame; await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("user://observer-" + str(i) + ".png")
	print("FRAMING PROBE: letter fold/pin presentation only; no progression acceptance")
	quit()
