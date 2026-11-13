extends RefCounted
class_name WorldBuilder

const LootScript = preload("res://scripts/loot.gd")

const MAP_NAMES := [
	"01  //  THE DEAD FOUNDRY",
	"02  //  LUNAR RELAY",
	"03  //  BLACKSITE 09",
	"04  //  THE SUNKEN LINE",
	"05  //  DRIFTING HULL",
	"06  //  REACTOR WASTE"
]
const ACCENTS := [
	Color(0.16, 0.91, 0.78),
	Color(0.36, 0.68, 1.0),
	Color(0.82, 0.39, 0.96),
	Color(0.96, 0.56, 0.26),
	Color(0.34, 0.92, 0.96),
	Color(1.0, 0.33, 0.22)
]
const FLOOR_COLORS := [
	Color(0.095, 0.13, 0.15), Color(0.085, 0.12, 0.17),
	Color(0.12, 0.095, 0.15), Color(0.12, 0.105, 0.09),
	Color(0.075, 0.12, 0.14), Color(0.13, 0.085, 0.075)
]

var root: Node3D
var rng := RandomNumberGenerator.new()
var accent: Color
var dark: Color

func build(parent: Node, map_index: int, seed: int) -> Dictionary:
	rng.seed = seed
	accent = ACCENTS[map_index % ACCENTS.size()]
	dark = FLOOR_COLORS[map_index % FLOOR_COLORS.size()]
	root = Node3D.new()
	root.name = "GeneratedWorld"
	parent.add_child(root)
	_add_environment(map_index)
	_make_box("MainFloor", Vector3(0, -0.55, 0), Vector3(48, 1.0, 48), _mat(dark, 0.78, 0.9))
	_make_box("NorthBulkhead", Vector3(0, 2.2, -24), Vector3(48, 5.5, 0.8), _mat(Color(0.14, 0.18, 0.2), 0.65, 0.5))
	_make_box("SouthBulkhead", Vector3(0, 2.2, 24), Vector3(48, 5.5, 0.8), _mat(Color(0.14, 0.18, 0.2), 0.65, 0.5))
	_make_box("WestBulkhead", Vector3(-24, 2.2, 0), Vector3(0.8, 5.5, 48), _mat(Color(0.14, 0.18, 0.2), 0.65, 0.5))
	_make_box("EastBulkhead", Vector3(24, 2.2, 0), Vector3(0.8, 5.5, 48), _mat(Color(0.14, 0.18, 0.2), 0.65, 0.5))
	_build_corridors()
	_build_props(map_index)
	_build_lights()
	var exit_pos := Vector3(0, 0, 10.5)
	_build_extraction(exit_pos)
	_build_ship(Vector3(0, 0, 17))
	_build_hazard_details(map_index)
	var loot_points := [
		Vector3(-13, 0, -10), Vector3(12, 0, -12), Vector3(-15, 0, 7),
		Vector3(15, 0, 8), Vector3(-5, 0, -1), Vector3(6, 0, 3),
		Vector3(10, 0, 18), Vector3(-11, 0, 18), Vector3(2, 0, 5),
		Vector3(17, 0, -1), Vector3(-18, 0, -17), Vector3(1, 0, 20)
	]
	var loot_ids: Array[String] = []
	for i in range(loot_points.size()):
		var item := LootScript.new()
		item.name = "Salvage_%02d" % i
		item.item_id = "salvage_%02d" % i
		item.credit_value = 15 + ((i * 7) % 23)
		item.item_kind = i % 4
		root.add_child(item)
		item.position = loot_points[i]
		loot_ids.append(item.item_id)
	var enemy_spawns := [
		Vector3(-17, 0, -16), Vector3(17, 0, -15), Vector3(16, 0, 15),
		Vector3(-17, 0, 16)
	]
	return {
		"spawn": Vector3(0, 0, 17),
		"exit": exit_pos,
		"enemy_spawns": enemy_spawns,
		"loot_ids": loot_ids,
		"map_name": MAP_NAMES[map_index % MAP_NAMES.size()]
	}

func _add_environment(map_index: int) -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.012, 0.019, 0.027)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.46, 0.52)
	env.ambient_light_energy = 0.54
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.055, 0.085, 0.10)
	env.fog_density = 0.024
	env_node.environment = env
	root.add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, 28, 0)
	sun.light_energy = 0.42
	sun.light_color = Color(0.55, 0.68, 0.72)
	sun.shadow_enabled = false
	root.add_child(sun)

func _build_corridors() -> void:
	var wall_mat := _mat(Color(0.16, 0.20, 0.22), 0.78, 0.55)
	for x in [-10.0, 0.0, 10.0]:
		_make_box("SupportColumn", Vector3(x, 2.0, -1), Vector3(0.75, 4.0, 0.75), wall_mat)
	for z in [-11.0, 0.0, 11.0]:
		_make_box("CrossBeam", Vector3(0, 4.25, z), Vector3(42, 0.35, 0.35), _mat(Color(0.24, 0.28, 0.29), 0.78, 0.45))
	_make_box("InnerWallA", Vector3(-20, 1.8, 0), Vector3(0.55, 3.6, 25), wall_mat)
	_make_box("InnerWallB", Vector3(20, 1.8, 0), Vector3(0.55, 3.6, 25), wall_mat)
	_make_box("DividerNorth", Vector3(-11, 1.45, -14), Vector3(15, 2.9, 0.55), wall_mat)
	_make_box("DividerSouth", Vector3(11, 1.45, 14), Vector3(15, 2.9, 0.55), wall_mat)

func _build_props(map_index: int) -> void:
	var crate_mat := _mat(Color(0.19, 0.25, 0.27), 0.5, 0.72)
	var accent_mat := _mat(accent, 0.45, 0.35, true)
	for i in range(30):
		var x := rng.randf_range(-18.0, 18.0)
		var z := rng.randf_range(-17.0, 17.0)
		if Vector2(x, z).length() < 5.0 or (Vector2(x, z) - Vector2(0, -19)).length() < 5.5:
			continue
		var size := Vector3(rng.randf_range(1.0, 2.2), rng.randf_range(0.9, 1.8), rng.randf_range(1.0, 2.0))
		_make_box("Cargo_%02d" % i, Vector3(x, size.y * 0.5 - 0.02, z), size, crate_mat)
		if i % 3 == 0:
			_make_box("CargoMark_%02d" % i, Vector3(x, size.y + 0.03, z), Vector3(size.x * 0.45, 0.045, 0.08), accent_mat, false)
	for i in range(8):
		var x := -17.0 + float(i % 4) * 11.0
		var z := -17.0 + float(i / 4) * 32.0
		_make_cylinder(Vector3(x, 0.65, z), 0.42, 1.3, _mat(Color(0.29, 0.31, 0.31), 0.82, 0.35))
	if map_index == 1:
		_make_box("Airlock", Vector3(0, 2.3, 8), Vector3(7, 4.6, 0.35), _mat(Color(0.19, 0.26, 0.33), 0.7, 0.45))
	elif map_index == 2:
		for i in range(5):
			_make_cylinder(Vector3(-16 + i * 8, 0.28, -5), 0.22, 0.56, _mat(Color(0.37, 0.25, 0.42), 0.65, 0.4))
	elif map_index == 3:
		for i in range(5):
			_make_box("TrackRail", Vector3(-18 + i * 9, 0.18, 0), Vector3(0.18, 0.36, 36), _mat(Color(0.34, 0.26, 0.16), 0.78, 0.45))
	elif map_index == 4:
		_make_box("CargoBay", Vector3(0, 3.4, 0), Vector3(13, 0.25, 12), _mat(Color(0.12, 0.24, 0.27), 0.7, 0.35))
	elif map_index == 5:
		for i in range(6):
			_make_cylinder(Vector3(-17 + i * 6.8, 0.8, 4), 0.66, 1.6, _mat(Color(0.31, 0.15, 0.12), 0.65, 0.4))

func _build_lights() -> void:
	for p in [Vector3(-16, 3.0, -14), Vector3(16, 3.0, -14), Vector3(-16, 3.0, 14), Vector3(16, 3.0, 14), Vector3(0, 3.0, 0)]:
		var lamp := OmniLight3D.new()
		lamp.position = p
		lamp.light_color = accent
		lamp.light_energy = 0.78
		lamp.omni_range = 9.5
		lamp.shadow_enabled = false
		root.add_child(lamp)
		var fixture := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(1.0, 0.09, 0.28)
		fixture.mesh = box
		fixture.position = p
		fixture.material_override = _mat(accent, 0.2, 0.3, true)
		root.add_child(fixture)

func _build_extraction(pos: Vector3) -> void:
	var frame_mat := _mat(Color(0.22, 0.29, 0.31), 0.82, 0.3)
	_make_box("ExitFrameLeft", pos + Vector3(-2.2, 2.0, 0), Vector3(0.32, 4.0, 0.45), frame_mat)
	_make_box("ExitFrameRight", pos + Vector3(2.2, 2.0, 0), Vector3(0.32, 4.0, 0.45), frame_mat)
	_make_box("ExitHeader", pos + Vector3(0, 4.0, 0), Vector3(4.7, 0.32, 0.45), frame_mat)
	_make_box("ExitPad", pos + Vector3(0, 0.04, 1.9), Vector3(4.2, 0.12, 4.0), _mat(accent, 0.35, 0.45, true), false)
	var lamp := OmniLight3D.new()
	lamp.position = pos + Vector3(0, 2.8, 1.0)
	lamp.light_color = accent
	lamp.light_energy = 1.8
	lamp.omni_range = 10
	lamp.shadow_enabled = false
	root.add_child(lamp)
	_make_box("ExitSign", pos + Vector3(0, 3.2, -0.35), Vector3(2.0, 0.42, 0.16), _mat(accent, 0.25, 0.4, true), false)


func _build_ship(pos: Vector3) -> void:
	# A compact drop-ship built from lightweight modular geometry.
	var hull := _mat(Color(0.105, 0.145, 0.16), 0.82, 0.38)
	var edge := _mat(Color(0.28, 0.34, 0.35), 0.78, 0.34)
	var glass := _mat(Color(0.035, 0.34, 0.34), 0.52, 0.22, true)
	var warning := _mat(Color(1.0, 0.47, 0.12), 0.25, 0.42, true)
	_make_box("DropShipDeck", pos + Vector3(0, 0.18, 0), Vector3(8.2, 0.28, 7.2), hull, false)
	_make_box("ShipPortHull", pos + Vector3(-4.0, 1.15, 0), Vector3(0.28, 2.0, 7.0), edge, false)
	_make_box("ShipStarboardHull", pos + Vector3(4.0, 1.15, 0), Vector3(0.28, 2.0, 7.0), edge, false)
	_make_box("ShipRearBulkhead", pos + Vector3(0, 1.25, 3.35), Vector3(8.0, 2.2, 0.28), hull, false)
	_make_box("ShipRoofBeam", pos + Vector3(0, 2.35, 0.0), Vector3(8.0, 0.22, 7.0), edge, false)
	_make_box("ShipCockpitGlass", pos + Vector3(0, 1.55, -3.38), Vector3(3.4, 1.0, 0.12), glass, false)
	_make_box("ShipRamp", pos + Vector3(0, 0.02, -4.15), Vector3(5.6, 0.18, 1.8), edge, false)
	for side in [-1.0, 1.0]:
		var engine_pos := pos + Vector3(side * 4.45, 1.05, 2.35)
		_make_box("ShipEnginePod", engine_pos, Vector3(0.85, 1.35, 2.4), hull, false)
		_make_box("ShipEngineGlow", engine_pos + Vector3(0, 0, 1.22), Vector3(0.48, 0.78, 0.12), glass, false)
		_make_box("ShipBench", pos + Vector3(side * 2.7, 0.72, 0.7), Vector3(1.4, 0.85, 2.1), hull, false)
		_make_box("ShipHazardStripe", pos + Vector3(side * 3.97, 0.36, -2.0), Vector3(0.025, 0.04, 1.4), warning, false)
	_make_box("ShipConsole", pos + Vector3(0, 1.05, -2.65), Vector3(1.5, 1.0, 0.45), hull, false)
	_make_box("ShipConsoleScreen", pos + Vector3(0, 1.62, -2.69), Vector3(1.1, 0.42, 0.06), glass, false)
	_make_ship_terminal(pos + Vector3(0, 0, -2.65), hull, glass)
	_make_box("ShipCeilingLight", pos + Vector3(0, 2.20, 0.0), Vector3(2.8, 0.07, 0.18), _mat(accent, 0.2, 0.28, true), false)
	var beacon := OmniLight3D.new()
	beacon.position = pos + Vector3(0, 2.7, 0)
	beacon.light_color = accent
	beacon.light_energy = 0.8
	beacon.omni_range = 8.0
	beacon.shadow_enabled = false
	root.add_child(beacon)
	_make_box("ShipCallsign", pos + Vector3(0, 2.48, 3.18), Vector3(2.4, 0.16, 0.08), warning, false)

func _make_ship_terminal(pos: Vector3, hull: Material, screen: Material) -> void:
	var terminal := StaticBody3D.new()
	terminal.name = "ShipServiceTerminal"
	terminal.position = pos + Vector3(0, 1.05, 0)
	terminal.collision_layer = 2
	terminal.collision_mask = 1
	terminal.add_to_group("ship_terminal")
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.55, 1.05, 0.48)
	visual.mesh = mesh
	visual.material_override = hull
	terminal.add_child(visual)
	var display := MeshInstance3D.new()
	var display_mesh := BoxMesh.new()
	display_mesh.size = Vector3(0.92, 0.36, 0.035)
	display.mesh = display_mesh
	display.position = Vector3(0, 0.27, -0.255)
	display.material_override = screen
	terminal.add_child(display)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.6, 1.1, 0.5)
	collision.shape = shape
	terminal.add_child(collision)
	root.add_child(terminal)

func _build_hazard_details(map_index: int) -> void:
	var pipe_mat := _mat(Color(0.22, 0.29, 0.31), 0.88, 0.28)
	var stripe_mat := _mat(Color(0.88, 0.43, 0.10), 0.18, 0.52, true)
	var panel_mat := _mat(Color(0.075, 0.105, 0.12), 0.72, 0.48)
	for side in [-1.0, 1.0]:
		_make_box("CeilingConduit", Vector3(side * 21.2, 4.45, 0), Vector3(0.22, 0.22, 42), pipe_mat, false)
		_make_box("FloorWarningLine", Vector3(side * 22.4, 0.015, 0), Vector3(0.12, 0.025, 44), stripe_mat, false)
	for i in range(8):
		var z := -18.0 + float(i) * 5.0
		for side in [-1.0, 1.0]:
			_make_box("WallServicePanel", Vector3(side * 23.48, 1.7, z), Vector3(0.06, 1.25, 1.55), panel_mat, false)
			_make_box("PanelStatusLED", Vector3(side * 23.40, 2.05, z - 0.42), Vector3(0.035, 0.10, 0.18), _mat(accent, 0.1, 0.25, true), false)
			_make_box("PanelWarningStripe", Vector3(side * 23.40, 1.12, z + 0.48), Vector3(0.04, 0.08, 0.48), stripe_mat, false)
	for side in [-1.0, 1.0]:
		_make_box("MainOverheadPipe", Vector3(side * 18.8, 4.15, 0), Vector3(0.32, 0.32, 43), pipe_mat, false)
		_make_box("CableTray", Vector3(side * 16.8, 4.62, 0), Vector3(0.65, 0.10, 43), panel_mat, false)
		for z in [-18.0, -9.0, 0.0, 9.0, 18.0]:
			_make_box("PipeBracket", Vector3(side * 18.8, 3.92, z), Vector3(0.55, 0.16, 0.32), stripe_mat, false)
	for i in range(6):
		var x := -15.0 + float(i) * 6.0
		_make_box("FloorDrain", Vector3(x, 0.012, 0), Vector3(1.8, 0.025, 0.42), pipe_mat, false)
		_make_box("DrainHazard", Vector3(x, 0.03, 0.25), Vector3(1.8, 0.025, 0.08), stripe_mat, false)
	for i in range(4):
		var vent := MeshInstance3D.new()
		var vent_mesh := BoxMesh.new()
		vent_mesh.size = Vector3(1.8, 0.08, 0.75)
		vent.mesh = vent_mesh
		vent.position = Vector3(-16.0 + float(i) * 10.5, 4.82, -20.0)
		vent.material_override = pipe_mat
		root.add_child(vent)
	if map_index == 0 or map_index == 5:
		for i in range(5):
			var steam_pipe := _make_steam_stack(Vector3(-18.0 + float(i) * 9.0, 0, 8.0), accent)
			root.add_child(steam_pipe)

func _make_steam_stack(pos: Vector3, tint: Color) -> Node3D:
	var assembly := Node3D.new()
	assembly.position = pos
	var base := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.32
	cylinder.bottom_radius = 0.42
	cylinder.height = 1.7
	base.mesh = cylinder
	base.position.y = 0.85
	base.material_override = _mat(Color(0.19, 0.23, 0.24), 0.82, 0.4)
	assembly.add_child(base)
	var cap := MeshInstance3D.new()
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.48
	cap_mesh.bottom_radius = 0.48
	cap_mesh.height = 0.12
	cap.mesh = cap_mesh
	cap.position.y = 1.72
	cap.material_override = _mat(tint, 0.35, 0.3, true)
	assembly.add_child(cap)
	return assembly

func _make_box(label: String, pos: Vector3, size: Vector3, mat: Material, solid: bool = true) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	if solid:
		var body := StaticBody3D.new()
		body.name = label
		body.position = pos
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = mat
		body.add_child(visual)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
		root.add_child(body)
	else:
		var visual := MeshInstance3D.new()
		visual.name = label
		visual.mesh = mesh
		visual.position = pos
		visual.material_override = mat
		root.add_child(visual)

func _make_cylinder(pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var body := StaticBody3D.new()
	body.position = pos
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	visual.mesh = mesh
	visual.material_override = mat
	body.add_child(visual)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	collider.shape = shape
	body.add_child(collider)
	root.add_child(body)

func _mat(color: Color, metallic: float, roughness: float, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emissive:
		mat.emission_enabled = true
		mat.emission = color * 0.48
	return mat
