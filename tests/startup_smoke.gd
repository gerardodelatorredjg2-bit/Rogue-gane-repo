extends SceneTree

func _initialize() -> void:
	call_deferred("_run_startup_smoke")

func _run_startup_smoke() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		push_error("SMOKE TEST FAILED: main.tscn could not be loaded.")
		quit(1)
		return

	var app := packed_scene.instantiate()
	root.add_child(app)
	await process_frame

	var buttons: Array[Node] = app.find_children("*", "Button", true, false)
	var has_solo_button := false
	for node in buttons:
		var button := node as Button
		if button != null and button.text == "PLAY SOLO":
			has_solo_button = true
			break
	if not has_solo_button:
		push_error("SMOKE TEST FAILED: main menu did not create the PLAY SOLO button.")
		quit(1)
		return

	for map_index in range(3):
		app.set("current_map", map_index)
		app.call("_start_session_world")
		await process_frame
		var generated_world := app.get_node_or_null("GeneratedWorld")
		if generated_world == null:
			push_error("SMOKE TEST FAILED: map %d did not create GeneratedWorld." % map_index)
			quit(1)
			return
		var mesh_nodes: Array[Node] = generated_world.find_children("*", "MeshInstance3D", true, false)
		if mesh_nodes.size() < 65:
			push_error("SMOKE TEST FAILED: map %d is missing its environment geometry (%d meshes)." % [map_index, mesh_nodes.size()])
			quit(1)
			return
		print("MAP SMOKE TEST PASSED: %s (%d 3D meshes)." % [WorldBuilder.MAP_NAMES[map_index], mesh_nodes.size()])

	app.call("_spawn_player", 1, Vector3(0, 0, 17))
	await process_frame
	await process_frame
	if not bool(app.get("session_live")):
		push_error("SMOKE TEST FAILED: a solo session did not start.")
		quit(1)
		return
	if app.get_viewport().get_camera_3d() == null:
		push_error("SMOKE TEST FAILED: no active player camera was created.")
		quit(1)
		return

	print("SMOKE TEST PASSED: menu, all three maps, solo world, player and active camera are ready.")
	quit(0)
