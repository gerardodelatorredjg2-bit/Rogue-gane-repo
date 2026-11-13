extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const WorldBuilderScript = preload("res://scripts/world_builder.gd")
const AmbienceScript = preload("res://scripts/ambience.gd")
const DroppedItemScript = preload("res://scripts/dropped_item.gd")

const GAME_PORT := 28960
const MAX_CLIENTS := 4
const DEFAULT_QUOTA := 6
const INVENTORY_ITEMS := ["medkit", "battery", "scanner"]
const ITEM_LABELS := {"medkit": "MEDKIT", "battery": "FLASHLIGHT CELL", "scanner": "MOTION SCANNER"}
const SHOP_CATALOG := {
	"repair": {"cost": 25, "label": "SUIT PATCH  +50 INTEGRITY", "kind": "service"},
	"stamina": {"cost": 15, "label": "STAMINA RECHARGE", "kind": "service"},
	"medkit": {"cost": 40, "label": "MEDKIT  +1", "kind": "item"},
	"battery": {"cost": 25, "label": "FLASHLIGHT CELL  +1", "kind": "item"},
	"scanner": {"cost": 55, "label": "MOTION SCANNER  +1", "kind": "item"},
	"hull": {"cost": 120, "label": "HULL REINFORCEMENT  +1", "kind": "upgrade"},
	"storage": {"cost": 90, "label": "CARGO RACK  +2 SLOTS", "kind": "upgrade"},
	"engine": {"cost": 140, "label": "ENGINE TUNING  +5% SPEED", "kind": "upgrade"}
}

var current_map: int = 0
var session_seed: int = 73191
var quota: int = DEFAULT_QUOTA
var collected: int = 0
var credits: int = 0
var round_index: int = 1
var shift_seconds: float = 0.0
var session_live: bool = false
var round_finished: bool = false
var world_info: Dictionary = {}
var players: Dictionary = {}
var enemies: Dictionary = {}
var player_inventories: Dictionary = {}
var ship_upgrades: Dictionary = {"hull": 0, "storage": 0, "engine": 0}
var scanner_until: float = 0.0
var dropped_counter: int = 0
var sfx_files: Array[String] = []
var sfx_player: AudioStreamPlayer
var canvas: CanvasLayer
var ui_root: Control
var status_label: Label
var objective_label: Label
var credits_label: Label
var health_label: Label
var stamina_label: Label
var battery_label: Label
var prompt_label: Label
var map_label: Label
var timer_label: Label
var lobby_map_select: OptionButton
var lobby_ip_input: LineEdit
var lobby_status: Label
var result_panel: PanelContainer
var mobile_ui: Control
var mobile_visible: bool = false
var health_bar: ProgressBar
var stamina_bar: ProgressBar
var battery_bar: ProgressBar
var quota_bar: ProgressBar
var threat_label: Label
var hud_scan_clock: float = 0.0
var terminal_panel: PanelContainer
var inventory_panel: PanelContainer
var settings_panel: PanelContainer
var settings_config := ConfigFile.new()
var player_display_name: String = "CREWMATE"
var move_key_layout: int = 0
var mobile_left_handed: bool = false
var invert_look_y: bool = false

func _ready() -> void:
	Engine.max_fps = 30 if OS.has_feature("mobile") else 60
	_configure_input()
	_create_canvas()
	_load_sfx_library()
	_load_user_settings()
	_show_lobby()
	set_process(true)

func _process(delta: float) -> void:
	if session_live and not round_finished:
		shift_seconds += delta
		if is_instance_valid(timer_label):
			var total := int(shift_seconds)
			timer_label.text = "%02d:%02d" % [total / 60, total % 60]
		hud_scan_clock += delta
		if hud_scan_clock >= 0.35:
			hud_scan_clock = 0.0
			_update_threat_indicator()


func _default_inventory() -> Dictionary:
	return {"medkit": 1, "battery": 1, "scanner": 0}

func _inventory_slot_limit() -> int:
	return 6 + int(ship_upgrades.get("storage", 0)) * 2

func _inventory_count(player_id: int) -> int:
	var inventory: Dictionary = player_inventories.get(player_id, _default_inventory())
	var total := 0
	for item_id in inventory.keys():
		total += int(inventory[item_id])
	return total

func _load_sfx_library() -> void:
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "KenneySFX"
	sfx_player.volume_db = -7.0
	add_child(sfx_player)
	var directory := DirAccess.open("res://assets/audio/kenney_sci_fi")
	if directory == null:
		return
	for file_name in directory.get_files():
		var extension := file_name.get_extension().to_lower()
		if extension == "ogg" or extension == "wav":
			sfx_files.append(file_name)

func _play_sfx(keyword: String = "") -> void:
	if sfx_files.is_empty() or not is_instance_valid(sfx_player):
		return
	var filters: Array[String] = []
	match keyword.to_lower():
		"ui":
			filters = ["computernoise", "forcefield"]
		"pickup":
			filters = ["forcefield", "lasersmall"]
		"impact":
			filters = ["impactmetal", "explosioncrunch"]
		_:
			if not keyword.is_empty():
				filters = [keyword.to_lower()]
	var candidates: Array[String] = []
	for file_name in sfx_files:
		var normalized := file_name.to_lower()
		for filter_text in filters:
			if normalized.contains(filter_text):
				candidates.append(file_name)
				break
	if candidates.is_empty():
		candidates = sfx_files
	var chosen := candidates[randi_range(0, candidates.size() - 1)]
	var stream := load("res://assets/audio/kenney_sci_fi/%s" % chosen) as AudioStream
	if stream:
		sfx_player.stream = stream
		sfx_player.play()

@rpc("authority", "call_local", "reliable")
func sync_player_inventory(player_id: int, inventory: Dictionary) -> void:
	player_inventories[player_id] = inventory.duplicate(true)
	if player_id == multiplayer.get_unique_id():
		_refresh_inventory_panel()
	_play_sfx("ui")

@rpc("authority", "call_local", "reliable")
func sync_ship_upgrades(upgrades: Dictionary) -> void:
	ship_upgrades = upgrades.duplicate(true)
	_refresh_ship_upgrade_visuals()
	for peer_id in players.keys():
		var player := players[peer_id] as SalvagePlayer
		if is_instance_valid(player):
			player.move_speed_multiplier = 1.0 + float(ship_upgrades.get("engine", 0)) * 0.05
			player.damage_resistance = minf(0.35, float(ship_upgrades.get("hull", 0)) * 0.06)


func _refresh_ship_upgrade_visuals() -> void:
	var generated_world := get_node_or_null("GeneratedWorld")
	if not generated_world:
		return
	for old_node in generated_world.get_children():
		if old_node.is_in_group("ship_upgrade_visual"):
			old_node.queue_free()
	var ship_pos: Vector3 = world_info.get("ship", Vector3(0, 0, 17))
	var hull_level := mini(5, int(ship_upgrades.get("hull", 0)))
	for level in range(hull_level):
		for side in [-1.0, 1.0]:
			_add_ship_upgrade_plate(generated_world, ship_pos + Vector3(side * 4.18, 1.48 + float(level) * 0.12, -1.35 + float(level) * 0.48), Vector3(0.20, 0.40, 1.55), Color(0.90, 0.38, 0.13))
	var storage_level := mini(5, int(ship_upgrades.get("storage", 0)))
	for level in range(storage_level):
		_add_ship_upgrade_plate(generated_world, ship_pos + Vector3(0, 2.54 + float(level) * 0.18, 2.35), Vector3(4.2, 0.10, 0.18), Color(0.82, 0.62, 0.22))
	var engine_level := mini(5, int(ship_upgrades.get("engine", 0)))
	for level in range(engine_level):
		for side in [-1.0, 1.0]:
			_add_ship_upgrade_plate(generated_world, ship_pos + Vector3(side * 4.45, 1.05, 3.65 + float(level) * 0.13), Vector3(0.46, 0.24, 0.10), Color(0.18, 0.82, 1.0))

func _add_ship_upgrade_plate(parent: Node, position: Vector3, size: Vector3, color: Color) -> void:
	var plate := MeshInstance3D.new()
	plate.add_to_group("ship_upgrade_visual")
	var mesh := BoxMesh.new()
	mesh.size = size
	plate.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.68
	material.roughness = 0.32
	material.emission_enabled = true
	material.emission = color * 0.22
	plate.material_override = material
	plate.position = position
	parent.add_child(plate)

func _configure_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("interact", KEY_E)
	_add_key_action("flashlight", KEY_F)
	_add_key_action("inventory", KEY_I)

func _add_key_action(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)

func _create_canvas() -> void:
	canvas = CanvasLayer.new()
	canvas.layer = 10
	add_child(canvas)
	ui_root = Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
	canvas.add_child(ui_root)

func _clear_ui() -> void:
	for child in ui_root.get_children():
		child.queue_free()
	objective_label = null
	credits_label = null
	health_label = null
	stamina_label = null
	battery_label = null
	prompt_label = null
	map_label = null
	timer_label = null
	mobile_ui = null
	result_panel = null
	health_bar = null
	stamina_bar = null
	battery_bar = null
	quota_bar = null
	threat_label = null
	terminal_panel = null
	inventory_panel = null
	settings_panel = null

func _show_lobby(message: String = "ALL SYSTEMS NOMINAL  //  LOCAL NETWORK READY") -> void:
	_clear_ui()
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.012, 0.022, 0.034, 0.98)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(backdrop)
	var grid := ColorRect.new()
	grid.color = Color(0.035, 0.09, 0.11, 0.22)
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(grid)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -270
	panel.offset_top = -310
	panel.offset_right = 270
	panel.offset_bottom = 310
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.055, 0.07, 0.97), Color(0.08, 0.74, 0.70, 0.9)))
	ui_root.add_child(panel)
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 28)
	outer.add_theme_constant_override("margin_right", 28)
	outer.add_theme_constant_override("margin_top", 22)
	outer.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(outer)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 13)
	outer.add_child(stack)
	var eyebrow := _label("FIELD OPERATIONS DIVISION  /  09.27", 12, Color(0.22, 0.88, 0.78))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(eyebrow)
	var title := _label("ROGUE MACHINES", 34, Color(0.88, 0.96, 0.96))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label("L O S T   S I G N A L", 16, Color(0.27, 0.82, 0.82))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	var divider := ColorRect.new()
	divider.custom_minimum_size.y = 2
	divider.color = Color(0.09, 0.62, 0.59)
	stack.add_child(divider)
	var desc := _label("RECOVER SALVAGE. KEEP THE CREW ALIVE.\nTHE MACHINES HEARD YOU COME IN.", 13, Color(0.58, 0.68, 0.71))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(desc)
	var map_caption := _label("SELECT OPERATION SITE", 11, Color(0.3, 0.76, 0.72))
	stack.add_child(map_caption)
	lobby_map_select = OptionButton.new()
	lobby_map_select.custom_minimum_size.y = 44
	lobby_map_select.add_theme_font_size_override("font_size", 14)
	for map_name in WorldBuilderScript.MAP_NAMES:
		lobby_map_select.add_item(map_name)
	lobby_map_select.select(current_map)
	stack.add_child(lobby_map_select)
	var ip_caption := _label("HOST ADDRESS  /  JOIN ONLY", 11, Color(0.3, 0.76, 0.72))
	stack.add_child(ip_caption)
	lobby_ip_input = LineEdit.new()
	lobby_ip_input.text = "192.168.43.1"
	lobby_ip_input.placeholder_text = "Host local IPv4, e.g. 192.168.1.20"
	lobby_ip_input.custom_minimum_size.y = 42
	lobby_ip_input.add_theme_font_size_override("font_size", 14)
	stack.add_child(lobby_ip_input)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	stack.add_child(buttons)
	var host_button := _button("HOST LAN", true)
	host_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_button.pressed.connect(_start_host)
	buttons.add_child(host_button)
	var join_button := _button("JOIN LAN", false)
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_button.pressed.connect(_join_lan)
	buttons.add_child(join_button)
	var solo_button := _button("PLAY SOLO", false)
	solo_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	solo_button.pressed.connect(_play_solo)
	stack.add_child(solo_button)
	var settings_button := _button("SETTINGS  /  PLAYER PROFILE", false)
	settings_button.pressed.connect(_open_settings)
	stack.add_child(settings_button)
	lobby_status = _label(message, 11, Color(0.52, 0.72, 0.72))
	lobby_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lobby_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lobby_status.custom_minimum_size.y = 30
	stack.add_child(lobby_status)
	var foot := _label("LAN UDP %d  //  UP TO %d CREW  //  NO ACCOUNT REQUIRED" % [GAME_PORT, MAX_CLIENTS], 10, Color(0.29, 0.42, 0.46))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(foot)
	var controls := _label("PC  WASD + MOUSE  |  E INTERACT  |  F LIGHT\nMOBILE  TOUCH PAD + SWIPE LOOK", 10, Color(0.38, 0.52, 0.55))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(controls)

func _start_host() -> void:
	current_map = lobby_map_select.selected if lobby_map_select else 0
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(GAME_PORT, MAX_CLIENTS - 1)
	if error != OK:
		_show_lobby("HOST FAILED  //  PORT %d IS UNAVAILABLE (%d)" % [GAME_PORT, error])
		return
	_set_multiplayer_signals()
	multiplayer.multiplayer_peer = peer
	session_seed = randi()
	credits = 0
	round_index = 1
	collected = 0
	quota = DEFAULT_QUOTA
	_start_session_world()
	_spawn_player(1, world_info.get("spawn", Vector3.ZERO))
	_spawn_initial_enemies()
	set_prompt("HOST %s:%d  //  WAITING FOR CREW" % [_local_ipv4_addresses(), GAME_PORT])
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if not OS.has_feature("mobile") else Input.MOUSE_MODE_VISIBLE

func _play_solo() -> void:
	_start_host()
	if session_live:
		set_prompt("SOLO CONTRACT ACTIVE  //  EXTRACT WHEN THE QUOTA IS MET")

func _join_lan() -> void:
	var address := lobby_ip_input.text.strip_edges() if lobby_ip_input else ""
	if address.is_empty():
		_show_lobby("ENTER THE HOST PHONE'S LOCAL IP ADDRESS.")
		return
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address, GAME_PORT)
	if error != OK:
		_show_lobby("COULD NOT START CLIENT  //  CHECK THE ADDRESS.")
		return
	_set_multiplayer_signals()
	multiplayer.multiplayer_peer = peer
	_show_lobby("CONNECTING TO %s:%d  //  CHECK THE HOST HOTSPOT" % [address, GAME_PORT])

func _set_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

func _on_connected_to_server() -> void:
	_show_lobby("LINK ESTABLISHED  //  DOWNLOADING CONTRACT DATA...")

func _on_connection_failed() -> void:
	_show_lobby("CONNECTION FAILED  //  SAME WI-FI, HOTSPOT CLIENT ISOLATION OFF, PORT %d" % GAME_PORT)

func _on_server_disconnected() -> void:
	session_live = false
	_show_lobby("HOST CONNECTION LOST  //  RETURNED TO MAIN MENU")

func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server() or not session_live:
		return
	rpc_id(peer_id, "receive_session_config", current_map, session_seed, quota, credits, round_index, collected, _collected_item_ids())
	for existing_id in players.keys():
		var existing: Node3D = players[existing_id]
		if is_instance_valid(existing):
			rpc_id(peer_id, "receive_spawn_player", int(existing_id), existing.global_position)
			rpc_id(peer_id, "sync_player_inventory", int(existing_id), player_inventories.get(existing_id, _default_inventory()))
	rpc_id(peer_id, "sync_ship_upgrades", ship_upgrades)
	var spawn := _spawn_position_for(peer_id)
	receive_spawn_player.rpc(peer_id, spawn)
	for enemy_id in enemies.keys():
		var enemy: Node3D = enemies[enemy_id]
		if is_instance_valid(enemy):
			rpc_id(peer_id, "receive_enemy_spawn", str(enemy_id), enemy.global_position, int(enemy.get("variant")))
	for dropped in get_tree().get_nodes_in_group("dropped_items"):
		if is_instance_valid(dropped):
			rpc_id(peer_id, "spawn_dropped_item", str(dropped.get("drop_id")), str(dropped.get("item_kind")), dropped.global_position, dropped.linear_velocity)
	set_prompt("CREW CONNECTED  //  PLAYER %d JOINED" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if players.has(peer_id):
		var node: Node = players[peer_id]
		if is_instance_valid(node):
			node.queue_free()
		players.erase(peer_id)
		player_inventories.erase(peer_id)
		remove_player.rpc(peer_id)

func _local_ipv4_addresses() -> String:
	var addresses := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
			addresses.append(address)
	return ", ".join(addresses) if not addresses.is_empty() else "CHECK WI-FI SETTINGS"

func _spawn_position_for(peer_id: int) -> Vector3:
	var base: Vector3 = world_info.get("spawn", Vector3.ZERO)
	return base + Vector3(float(peer_id % 4) * 1.15 - 1.7, 0, float(peer_id % 2) * 1.4)

func _start_session_world() -> void:
	session_live = true
	round_finished = false
	shift_seconds = 0.0
	_clear_world()
	world_info = WorldBuilderScript.new().build(self, current_map, session_seed)
	_refresh_ship_upgrade_visuals()
	if not has_node("IndustrialAmbience"):
		var ambience = AmbienceScript.new()
		ambience.name = "IndustrialAmbience"
		add_child(ambience)
	else:
		var ambience_node = get_node("IndustrialAmbience")
		if ambience_node.has_method("play"):
			ambience_node.play()
	_create_hud()
	_update_hud()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _clear_world() -> void:
	for dropped in get_tree().get_nodes_in_group("dropped_items"):
		if is_instance_valid(dropped):
			dropped.queue_free()
	if has_node("GeneratedWorld"):
		var old_world := get_node("GeneratedWorld")
		remove_child(old_world)
		old_world.free()
	for node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(node):
			remove_child(node)
			node.free()
	enemies.clear()

func _spawn_initial_enemies() -> void:
	var locations: Array = world_info.get("enemy_spawns", [])
	var director_count := mini(locations.size(), 3 + int((round_index - 1) / 2))
	for i in range(director_count):
		receive_enemy_spawn.rpc("hunter_%02d" % i, locations[i], i % 3)

func _spawn_player(peer_id: int, pos: Vector3) -> void:
	if players.has(peer_id) and is_instance_valid(players[peer_id]):
		return
	if not player_inventories.has(peer_id):
		player_inventories[peer_id] = _default_inventory()
	var player = PlayerScript.new()
	player.name = "Player_%d" % peer_id
	player.player_id = peer_id
	player.game = self
	player.look_sensitivity = float(settings_config.get_value("controls", "sensitivity", 0.0022))
	player.invert_look_y = invert_look_y
	player.move_speed_multiplier = 1.0 + float(ship_upgrades.get("engine", 0)) * 0.05
	player.damage_resistance = minf(0.35, float(ship_upgrades.get("hull", 0)) * 0.06)
	add_child(player)
	player.global_position = pos
	players[peer_id] = player

@rpc("authority", "call_local", "reliable")
func receive_spawn_player(peer_id: int, pos: Vector3) -> void:
	_spawn_player(peer_id, pos)

@rpc("authority", "call_local", "reliable")
func remove_player(peer_id: int) -> void:
	if players.has(peer_id):
		var node: Node = players[peer_id]
		if is_instance_valid(node):
			node.queue_free()
		players.erase(peer_id)

@rpc("authority", "call_local", "reliable")
func receive_session_config(map_index: int, seed_value: int, new_quota: int, new_credits: int, new_round: int, new_collected: int, taken_item_ids: Array[String]) -> void:
	current_map = map_index
	session_seed = seed_value
	quota = new_quota
	credits = new_credits
	round_index = new_round
	collected = new_collected
	_start_session_world()
	for item_id in taken_item_ids:
		remove_loot(item_id)

func _loot_exists(item_id: String) -> bool:
	for node in get_tree().get_nodes_in_group("loot"):
		if node.get("item_id") == item_id:
			return true
	return false

func _collected_item_ids() -> Array[String]:
	var result: Array[String] = []
	for i in range(12):
		var item_id := "salvage_%02d" % i
		if not _loot_exists(item_id):
			result.append(item_id)
	return result

@rpc("authority", "call_local", "reliable")
func receive_enemy_spawn(enemy_id: String, pos: Vector3, variant: int) -> void:
	if enemies.has(enemy_id) and is_instance_valid(enemies[enemy_id]):
		return
	var enemy = EnemyScript.new()
	enemy.name = "Robot_" + enemy_id
	enemy.enemy_id = enemy_id
	enemy.variant = variant
	enemy.game = self
	add_child(enemy)
	enemy.global_position = pos
	enemies[enemy_id] = enemy

func broadcast_enemy_state(enemy_id: String, pos: Vector3, yaw: float, animation_time: float) -> void:
	if multiplayer.is_server():
		rpc("sync_enemy_state", enemy_id, pos, yaw, animation_time)

@rpc("any_peer", "call_remote", "unreliable")
func sync_enemy_state(enemy_id: String, pos: Vector3, yaw: float, _animation_time: float) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	if enemies.has(enemy_id) and is_instance_valid(enemies[enemy_id]):
		var enemy: Node3D = enemies[enemy_id]
		enemy.global_position = enemy.global_position.lerp(pos, 0.75)
		enemy.rotation.y = yaw

func request_loot(item_id: String, player_id: int) -> void:
	if multiplayer.is_server():
		_server_collect(item_id, player_id)
	else:
		rpc_id(1, "server_collect", item_id, player_id)

@rpc("any_peer", "reliable")
func server_collect(item_id: String, player_id: int) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player_id:
		return
	_server_collect(item_id, player_id)

func _server_collect(item_id: String, player_id: int) -> void:
	if round_finished or not players.has(player_id):
		return
	var player: Node3D = players[player_id]
	var target: Node3D
	for node in get_tree().get_nodes_in_group("loot"):
		if node.item_id == item_id:
			target = node
			break
	if not target or not is_instance_valid(target):
		return
	if player.global_position.distance_to(target.global_position) > 5.0:
		return
	var item_value := int(target.get("credit_value"))
	credits += item_value
	collected += 1
	sync_loot_count.rpc(collected, credits)
	remove_loot.rpc(item_id)
	set_prompt("SALVAGE SECURED  //  +%d CREDITS" % item_value)

@rpc("authority", "call_local", "reliable")
func sync_loot_count(new_count: int, new_credits: int) -> void:
	collected = new_count
	credits = new_credits
	_update_hud()
	_play_sfx("pickup")

@rpc("authority", "call_local", "reliable")
func remove_loot(item_id: String) -> void:
	for node in get_tree().get_nodes_in_group("loot"):
		if node.item_id == item_id:
			node.queue_free()
			break

func request_extract(player_id: int) -> void:
	if multiplayer.is_server():
		_server_extract(player_id)
	else:
		rpc_id(1, "server_extract", player_id)

@rpc("any_peer", "reliable")
func server_extract(player_id: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player_id:
		return
	_server_extract(player_id)

func _server_extract(player_id: int) -> void:
	if round_finished or collected < quota or not players.has(player_id):
		set_prompt("QUOTA INCOMPLETA  //  %d / %d RECUPERADOS" % [collected, quota])
		return
	var player: Node3D = players[player_id]
	if player.global_position.distance_to(get_exit_position()) > 6.2:
		return
	round_finished = true
	credits += 75 + collected * 4
	round_complete.rpc(credits, round_index)

@rpc("authority", "call_local", "reliable")
func round_complete(total_credits: int, completed_round: int) -> void:
	_play_sfx("ui")
	credits = total_credits
	round_index = completed_round
	round_finished = true
	_show_round_result()

func _show_round_result() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.006, 0.014, 0.02, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(shade)
	result_panel = PanelContainer.new()
	result_panel.anchor_left = 0.5
	result_panel.anchor_top = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_bottom = 0.5
	result_panel.offset_left = -230
	result_panel.offset_top = -170
	result_panel.offset_right = 230
	result_panel.offset_bottom = 170
	result_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.07, 0.08, 0.98), Color(0.12, 0.87, 0.75)))
	ui_root.add_child(result_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 16)
	result_panel.add_child(stack)
	var title := _label("SHIFT COMPLETE", 26, Color(0.44, 0.98, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var detail := _label("CONTRACT %02d  //  SALVAGE %d / %d\nCREDITS AVAILABLE: %d" % [round_index, collected, quota, credits], 14, Color(0.78, 0.88, 0.89))
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(detail)
	var next := _button("DEPLOY NEXT SHIFT", true)
	next.pressed.connect(_next_shift)
	stack.add_child(next)
	var back := _button("DISCONNECT", false)
	back.pressed.connect(_disconnect_to_menu)
	stack.add_child(back)

func _next_shift() -> void:
	if not multiplayer.is_server():
		set_prompt("ONLY THE HOST CAN START THE NEXT SHIFT")
		return
	current_map = (current_map + 1) % WorldBuilderScript.MAP_NAMES.size()
	session_seed = randi()
	collected = 0
	round_index += 1
	quota = DEFAULT_QUOTA + round_index - 1
	receive_session_config.rpc(current_map, session_seed, quota, credits, round_index, collected, [])
	for peer_id in players.keys():
		teleport_player.rpc(int(peer_id), _spawn_position_for(int(peer_id)))
	round_finished = false
	_spawn_initial_enemies()
	set_prompt("NEW CONTRACT  //  %s" % WorldBuilderScript.MAP_NAMES[current_map])

@rpc("authority", "call_local", "reliable")
func teleport_player(peer_id: int, pos: Vector3) -> void:
	if players.has(peer_id):
		players[peer_id].global_position = pos
		players[peer_id].velocity = Vector3.ZERO

func server_enemy_attack(player_id: int, damage: float) -> void:
	if multiplayer.is_server():
		player_damaged.rpc(player_id, damage)

@rpc("authority", "call_local", "reliable")
func player_damaged(player_id: int, damage: float) -> void:
	_play_sfx("impact")
	if players.has(player_id) and is_instance_valid(players[player_id]):
		players[player_id].apply_damage(damage)
	if player_id == multiplayer.get_unique_id():
		set_prompt("WARNING  //  SUIT INTEGRITY COMPROMISED")

func player_was_downed(player_id: int) -> void:
	if multiplayer.is_server():
		player_downed.rpc(player_id)

@rpc("authority", "call_local", "reliable")
func player_downed(player_id: int) -> void:
	if player_id == multiplayer.get_unique_id():
		set_prompt("YOU ARE DOWN  //  WAIT FOR THE NEXT CONTRACT")

func get_exit_position() -> Vector3:
	return world_info.get("exit", Vector3.ZERO)

func set_prompt(message: String) -> void:
	if is_instance_valid(prompt_label):
		prompt_label.text = message

func set_local_player_status(current_health: float, current_stamina: float, current_battery: float) -> void:
	if is_instance_valid(health_label):
		health_label.text = "SUIT  %03d%%" % int(current_health)
	if is_instance_valid(stamina_label):
		stamina_label.text = "STAMINA  %03d%%" % int(current_stamina)
	if is_instance_valid(health_bar):
		health_bar.value = current_health
	if is_instance_valid(stamina_bar):
		stamina_bar.value = current_stamina
	if is_instance_valid(battery_label):
		battery_label.text = "LAMP CELL  %03d%%" % int(current_battery)
	if is_instance_valid(battery_bar):
		battery_bar.value = current_battery

func _update_hud() -> void:
	if is_instance_valid(objective_label):
		objective_label.text = "SALVAGE  %02d / %02d" % [collected, quota]
	if is_instance_valid(credits_label):
		credits_label.text = "¢ %04d" % credits
	if is_instance_valid(map_label):
		map_label.text = WorldBuilderScript.MAP_NAMES[current_map]
	if is_instance_valid(timer_label):
		var total := int(shift_seconds)
		timer_label.text = "%02d:%02d" % [total / 60, total % 60]
	if is_instance_valid(quota_bar):
		quota_bar.value = 100.0 * float(collected) / maxf(1.0, float(quota))

func _create_hud() -> void:
	_clear_ui()
	var top := PanelContainer.new()
	top.anchor_left = 0.02
	top.anchor_top = 0.02
	top.anchor_right = 0.98
	top.anchor_bottom = 0.02
	top.offset_bottom = 58
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.026, 0.034, 0.94), Color(0.08, 0.67, 0.62, 0.72)))
	ui_root.add_child(top)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	top.add_child(margin)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 20)
	margin.add_child(bar)
	map_label = _label("SITE // UNKNOWN", 12, Color(0.34, 0.94, 0.82))
	map_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(map_label)
	var shift_label := _label("CONTRACT %02d" % round_index, 11, Color(0.54, 0.68, 0.72))
	bar.add_child(shift_label)
	objective_label = _label("", 14, Color(0.93, 0.98, 0.94))
	bar.add_child(objective_label)
	credits_label = _label("", 14, Color(1.0, 0.72, 0.35))
	bar.add_child(credits_label)
	timer_label = _label("00:00", 14, Color(0.73, 0.87, 0.92))
	bar.add_child(timer_label)
	var bag_hud_button := _button("BAG", false)
	bag_hud_button.custom_minimum_size = Vector2(54, 38)
	bag_hud_button.pressed.connect(func(): toggle_inventory(multiplayer.get_unique_id()))
	bar.add_child(bag_hud_button)
	var settings_hud_button := _button("⚙", false)
	settings_hud_button.custom_minimum_size = Vector2(48, 38)
	settings_hud_button.pressed.connect(_open_settings)
	bar.add_child(settings_hud_button)

	var vitals := PanelContainer.new()
	vitals.anchor_left = 0.02
	vitals.anchor_top = 0.115
	vitals.anchor_right = 0.28
	vitals.anchor_bottom = 0.115
	vitals.offset_bottom = 166
	vitals.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.027, 0.034, 0.82), Color(0.12, 0.38, 0.40, 0.48)))
	ui_root.add_child(vitals)
	var vitals_box := VBoxContainer.new()
	vitals_box.add_theme_constant_override("separation", 5)
	vitals.add_child(vitals_box)
	vitals_box.add_child(_label("SUIT TELEMETRY", 10, Color(0.36, 0.79, 0.78)))
	health_label = _label("INTEGRITY  100%", 11, Color(0.44, 0.96, 0.76))
	vitals_box.add_child(health_label)
	health_bar = _make_hud_bar(Color(0.12, 0.88, 0.65))
	vitals_box.add_child(health_bar)
	stamina_label = _label("STAMINA  100%", 11, Color(0.58, 0.83, 0.94))
	vitals_box.add_child(stamina_label)
	stamina_bar = _make_hud_bar(Color(0.22, 0.65, 0.96))
	vitals_box.add_child(stamina_bar)
	battery_label = _label("LAMP CELL  100%", 10, Color(0.98, 0.76, 0.35))
	vitals_box.add_child(battery_label)
	battery_bar = _make_hud_bar(Color(1.0, 0.68, 0.24))
	vitals_box.add_child(battery_bar)

	var objective_panel := PanelContainer.new()
	objective_panel.anchor_left = 0.72
	objective_panel.anchor_top = 0.115
	objective_panel.anchor_right = 0.98
	objective_panel.anchor_bottom = 0.115
	objective_panel.offset_bottom = 94
	objective_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.027, 0.034, 0.82), Color(0.55, 0.38, 0.15, 0.52)))
	ui_root.add_child(objective_panel)
	var objective_box := VBoxContainer.new()
	objective_box.add_theme_constant_override("separation", 7)
	objective_panel.add_child(objective_box)
	objective_box.add_child(_label("RECOVERY QUOTA", 10, Color(0.98, 0.67, 0.32)))
	quota_bar = _make_hud_bar(Color(1.0, 0.61, 0.24))
	objective_box.add_child(quota_bar)
	objective_box.add_child(_label("FIND SALVAGE  /  RETURN TO THE SHIP", 9, Color(0.59, 0.70, 0.70)))

	var reticle := _label("+", 22, Color(0.72, 0.96, 0.90, 0.78))
	reticle.anchor_left = 0.48
	reticle.anchor_top = 0.465
	reticle.anchor_right = 0.52
	reticle.anchor_bottom = 0.535
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_root.add_child(reticle)
	threat_label = _label("●  MOTION SENSOR // QUIET", 10, Color(0.38, 0.84, 0.72))
	threat_label.anchor_left = 0.31
	threat_label.anchor_top = 0.105
	threat_label.anchor_right = 0.69
	threat_label.anchor_bottom = 0.15
	threat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_root.add_child(threat_label)
	prompt_label = _label("RECOVER THE SIGNAL  //  FIND THE SALVAGE", 12, Color(0.68, 0.96, 0.87))
	prompt_label.anchor_left = 0.25
	prompt_label.anchor_top = 0.72
	prompt_label.anchor_right = 0.75
	prompt_label.anchor_bottom = 0.79
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_root.add_child(prompt_label)
	_create_mobile_controls()
	_update_hud()

func _make_hud_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.035, 0.075, 0.08, 0.95)
	background.set_corner_radius_all(3)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", background)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _update_threat_indicator() -> void:
	if not is_instance_valid(threat_label):
		return
	var player := _local_player()
	if player == null:
		threat_label.text = "●  MOTION SENSOR // STANDBY"
		return
	var nearest := 999.0
	for enemy in enemies.values():
		if is_instance_valid(enemy):
			nearest = minf(nearest, player.global_position.distance_to(enemy.global_position))
	if scanner_until > shift_seconds:
		threat_label.text = "◉  SCANNER ACTIVE // HOSTILE %.1f M" % nearest
		threat_label.add_theme_color_override("font_color", Color(0.25, 0.88, 1.0))
	elif nearest < 7.0:
		threat_label.text = "●  PROXIMITY ALERT // HOSTILE VERY CLOSE"
		threat_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.18))
	elif nearest < 16.0:
		threat_label.text = "●  MOTION DETECTED // CONTACT NEARBY"
		threat_label.add_theme_color_override("font_color", Color(1.0, 0.67, 0.22))
	else:
		threat_label.text = "●  MOTION SENSOR // QUIET"
		threat_label.add_theme_color_override("font_color", Color(0.38, 0.84, 0.72))

func open_ship_terminal(player_id: int) -> void:
	if player_id != multiplayer.get_unique_id() or is_instance_valid(terminal_panel):
		return
	if is_instance_valid(inventory_panel):
		inventory_panel.queue_free()
		inventory_panel = null
	terminal_panel = PanelContainer.new()
	terminal_panel.anchor_left = 0.5
	terminal_panel.anchor_top = 0.5
	terminal_panel.anchor_right = 0.5
	terminal_panel.anchor_bottom = 0.5
	terminal_panel.offset_left = -235
	terminal_panel.offset_top = -235
	terminal_panel.offset_right = 235
	terminal_panel.offset_bottom = 235
	terminal_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.035, 0.043, 0.99), Color(0.12, 0.83, 0.72)))
	ui_root.add_child(terminal_panel)
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 15)
	outer.add_theme_constant_override("margin_right", 15)
	outer.add_theme_constant_override("margin_top", 12)
	outer.add_theme_constant_override("margin_bottom", 12)
	terminal_panel.add_child(outer)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	outer.add_child(stack)
	var title := _label("DROP-SHIP // QUARTERMASTER", 19, Color(0.45, 0.98, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label("CREDITS  ¢%04d  //  CONTRACT %02d" % [credits, round_index], 11, Color(0.98, 0.72, 0.32))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	var levels := _label("HULL %d   CARGO %d   ENGINE %d" % [ship_upgrades.get("hull", 0), ship_upgrades.get("storage", 0), ship_upgrades.get("engine", 0)], 10, Color(0.50, 0.80, 0.82))
	levels.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(levels)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 285)
	stack.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	for item_id in SHOP_CATALOG.keys():
		var entry: Dictionary = SHOP_CATALOG[item_id]
		var display_cost := int(entry.get("cost", 0))
		if str(entry.get("kind")) == "upgrade":
			display_cost += int(ship_upgrades.get(str(item_id), 0)) * 50
		var row_button := _button("%s  //  ¢%d" % [entry.get("label", item_id), display_cost], str(entry.get("kind")) == "upgrade")
		row_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var captured_item_id := str(item_id)
		row_button.pressed.connect(request_ship_purchase.bind(captured_item_id, player_id))
		list.add_child(row_button)
	var close := _button("CLOSE QUARTERMASTER", false)
	close.pressed.connect(func():
		if is_instance_valid(terminal_panel):
			terminal_panel.queue_free()
		terminal_panel = null
	)
	stack.add_child(close)

func request_ship_purchase(item_id: String, player_id: int) -> void:
	if multiplayer.is_server():
		_server_ship_purchase(item_id, player_id)
	else:
		rpc_id(1, "server_ship_purchase", item_id, player_id)

@rpc("any_peer", "reliable")
func server_ship_purchase(item_id: String, player_id: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player_id:
		return
	_server_ship_purchase(item_id, player_id)

func _server_ship_purchase(item_id: String, player_id: int) -> void:
	if round_finished or not players.has(player_id) or not SHOP_CATALOG.has(item_id):
		return
	var player: Node3D = players[player_id]
	if player.global_position.distance_to(Vector3(0, 0, 17)) > 5.0:
		return
	var entry: Dictionary = SHOP_CATALOG[item_id]
	var cost := int(entry.get("cost", -1))
	var kind := str(entry.get("kind", ""))
	if kind == "upgrade":
		var current_level := int(ship_upgrades.get(item_id, 0))
		if current_level >= 5:
			_deny_shop_purchase(player_id, "SHIP UPGRADE MAXIMUM REACHED")
			return
		cost += current_level * 50
	if cost < 0 or credits < cost:
		_deny_shop_purchase(player_id, "NOT ENOUGH CREDITS")
		return
	var inventory: Dictionary = player_inventories.get(player_id, _default_inventory()).duplicate(true)
	if kind == "item" and _inventory_count(player_id) >= _inventory_slot_limit():
		_deny_shop_purchase(player_id, "INVENTORY FULL  //  BUY CARGO RACKS")
		return
	var new_health := float(player.get("health"))
	var new_stamina := float(player.get("stamina"))
	if item_id == "repair":
		if new_health >= 100.0:
			_deny_shop_purchase(player_id, "SUIT INTEGRITY ALREADY FULL")
			return
		new_health = minf(100.0, new_health + 50.0)
	elif item_id == "stamina":
		new_stamina = 100.0
	elif kind == "item":
		inventory[item_id] = int(inventory.get(item_id, 0)) + 1
	elif kind == "upgrade":
		ship_upgrades[item_id] = int(ship_upgrades.get(item_id, 0)) + 1
	else:
		return
	credits -= cost
	if kind == "item":
		player_inventories[player_id] = inventory
		sync_player_inventory.rpc(player_id, inventory)
	if kind == "upgrade":
		sync_ship_upgrades.rpc(ship_upgrades)
	sync_ship_purchase.rpc(credits, player_id, new_health, new_stamina, item_id)

func _deny_shop_purchase(player_id: int, message: String) -> void:
	if player_id == multiplayer.get_unique_id():
		set_prompt(message)
	else:
		rpc_id(player_id, "ship_purchase_denied", message)

@rpc("authority", "call_remote", "reliable")
func ship_purchase_denied(message: String) -> void:
	set_prompt(message)

@rpc("authority", "call_local", "reliable")
func sync_ship_purchase(new_credits: int, player_id: int, new_health: float, new_stamina: float, item_id: String) -> void:
	credits = new_credits
	if players.has(player_id) and is_instance_valid(players[player_id]):
		var player := players[player_id] as SalvagePlayer
		player.health = new_health
		player.stamina = new_stamina
	_update_hud()
	_play_sfx("ui")
	var item_label := str(SHOP_CATALOG.get(item_id, {}).get("label", item_id))
	set_prompt("PURCHASE COMPLETE  //  " + item_label)
	if player_id == multiplayer.get_unique_id() and is_instance_valid(terminal_panel):
		terminal_panel.queue_free()
		terminal_panel = null

func toggle_inventory(player_id: int) -> void:
	if player_id != multiplayer.get_unique_id():
		return
	if is_instance_valid(inventory_panel):
		inventory_panel.queue_free()
		inventory_panel = null
		return
	open_inventory(player_id)

func open_inventory(player_id: int) -> void:
	if player_id != multiplayer.get_unique_id() or is_instance_valid(inventory_panel):
		return
	inventory_panel = PanelContainer.new()
	inventory_panel.anchor_left = 0.5
	inventory_panel.anchor_top = 0.5
	inventory_panel.anchor_right = 0.5
	inventory_panel.anchor_bottom = 0.5
	inventory_panel.offset_left = -225
	inventory_panel.offset_top = -205
	inventory_panel.offset_right = 225
	inventory_panel.offset_bottom = 205
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.008, 0.025, 0.035, 0.985), Color(0.10, 0.76, 0.77)))
	ui_root.add_child(inventory_panel)
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 16)
	outer.add_theme_constant_override("margin_right", 16)
	outer.add_theme_constant_override("margin_top", 12)
	outer.add_theme_constant_override("margin_bottom", 12)
	inventory_panel.add_child(outer)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 9)
	outer.add_child(stack)
	var title := _label("PERSONAL LOADOUT  //  FIELD GEAR", 18, Color(0.45, 0.98, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var inventory: Dictionary = player_inventories.get(player_id, _default_inventory())
	var slot_text := _label("SLOTS  %d / %d     //     CREDITS  ¢%d" % [_inventory_count(player_id), _inventory_slot_limit(), credits], 11, Color(0.98, 0.72, 0.32))
	slot_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(slot_text)
	var list := VBoxContainer.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	stack.add_child(list)
	for item_id in INVENTORY_ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		list.add_child(row)
		var count := int(inventory.get(item_id, 0))
		var item_name := _label("%s   x%d" % [ITEM_LABELS[item_id], count], 12, Color(0.78, 0.91, 0.92))
		item_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(item_name)
		var captured_item_id := item_id
		var use_button := _button("USE", true)
		use_button.custom_minimum_size = Vector2(72, 38)
		use_button.disabled = count <= 0
		use_button.pressed.connect(request_use_inventory_item.bind(captured_item_id, player_id))
		row.add_child(use_button)
		var drop_button := _button("DROP", false)
		drop_button.custom_minimum_size = Vector2(72, 38)
		drop_button.disabled = count <= 0
		drop_button.pressed.connect(request_drop_inventory_item.bind(captured_item_id, player_id))
		row.add_child(drop_button)
	var instructions := _label("I / BAG: OPEN   •   E: PICK UP   •   F: FLASHLIGHT", 9, Color(0.47, 0.65, 0.70))
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(instructions)
	var close := _button("CLOSE INVENTORY", false)
	close.pressed.connect(func():
		if is_instance_valid(inventory_panel):
			inventory_panel.queue_free()
		inventory_panel = null
	)
	stack.add_child(close)

func _refresh_inventory_panel() -> void:
	if not is_instance_valid(inventory_panel):
		return
	inventory_panel.queue_free()
	inventory_panel = null
	open_inventory(multiplayer.get_unique_id())

func request_use_inventory_item(item_id: String, player_id: int) -> void:
	if multiplayer.is_server():
		_server_use_inventory_item(item_id, player_id)
	else:
		rpc_id(1, "server_use_inventory_item", item_id, player_id)

@rpc("any_peer", "reliable")
func server_use_inventory_item(item_id: String, player_id: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player_id:
		return
	_server_use_inventory_item(item_id, player_id)

func _server_use_inventory_item(item_id: String, player_id: int) -> void:
	if round_finished or not players.has(player_id) or item_id not in INVENTORY_ITEMS:
		return
	var inventory: Dictionary = player_inventories.get(player_id, _default_inventory()).duplicate(true)
	if int(inventory.get(item_id, 0)) <= 0:
		return
	var player := players[player_id] as SalvagePlayer
	var new_health := float(player.health)
	var new_stamina := float(player.stamina)
	var new_battery := float(player.flashlight_charge)
	var new_scan_time := scanner_until
	if item_id == "medkit":
		if new_health >= 100.0:
			_deny_shop_purchase(player_id, "INTEGRITY ALREADY FULL")
			return
		new_health = minf(100.0, new_health + 45.0)
	elif item_id == "battery":
		if new_battery >= 100.0:
			_deny_shop_purchase(player_id, "FLASHLIGHT CELL ALREADY FULL")
			return
		new_battery = minf(100.0, new_battery + 70.0)
	elif item_id == "scanner":
		new_scan_time = maxf(new_scan_time, shift_seconds) + 12.0
	inventory[item_id] = int(inventory[item_id]) - 1
	player_inventories[player_id] = inventory
	sync_inventory_use.rpc(player_id, item_id, new_health, new_stamina, new_battery, new_scan_time, inventory)

@rpc("authority", "call_local", "reliable")
func sync_inventory_use(player_id: int, item_id: String, new_health: float, new_stamina: float, new_battery: float, new_scan_time: float, inventory: Dictionary) -> void:
	player_inventories[player_id] = inventory.duplicate(true)
	scanner_until = new_scan_time
	if players.has(player_id) and is_instance_valid(players[player_id]):
		var player := players[player_id] as SalvagePlayer
		player.health = new_health
		player.stamina = new_stamina
		player.flashlight_charge = new_battery
		if item_id == "battery" and player.flashlight:
			player.flashlight.visible = new_battery > 0.0
	if player_id == multiplayer.get_unique_id():
		_refresh_inventory_panel()
	_play_sfx("pickup")
	var item_label := ITEM_LABELS.get(item_id, item_id.to_upper())
	set_prompt("ITEM USED  //  " + item_label)

func request_drop_inventory_item(item_id: String, player_id: int) -> void:
	if multiplayer.is_server():
		_server_drop_inventory_item(item_id, player_id)
	else:
		rpc_id(1, "server_drop_inventory_item", item_id, player_id)

@rpc("any_peer", "reliable")
func server_drop_inventory_item(item_id: String, player_id: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player_id:
		return
	_server_drop_inventory_item(item_id, player_id)

func _server_drop_inventory_item(item_id: String, player_id: int) -> void:
	if round_finished or not players.has(player_id) or item_id not in INVENTORY_ITEMS:
		return
	var inventory: Dictionary = player_inventories.get(player_id, _default_inventory()).duplicate(true)
	if int(inventory.get(item_id, 0)) <= 0:
		return
	var player := players[player_id] as SalvagePlayer
	var forward := -player.view_camera.global_transform.basis.z
	var drop_position := player.global_position + forward * 1.1 + Vector3.UP * 1.0
	var launch_velocity := forward * 3.0 + Vector3.UP * 2.1
	inventory[item_id] = int(inventory[item_id]) - 1
	player_inventories[player_id] = inventory
	sync_player_inventory.rpc(player_id, inventory)
	dropped_counter += 1
	var drop_id := "drop_%06d" % dropped_counter
	spawn_dropped_item.rpc(drop_id, item_id, drop_position, launch_velocity)

@rpc("authority", "call_local", "reliable")
func spawn_dropped_item(drop_id: String, item_id: String, position: Vector3, initial_velocity: Vector3) -> void:
	var dropped = DroppedItemScript.new()
	dropped.name = drop_id
	dropped.drop_id = drop_id
	dropped.item_kind = item_id
	add_child(dropped)
	dropped.global_position = position
	dropped.linear_velocity = initial_velocity
	dropped.angular_velocity = Vector3(1.8, 2.2, 1.1)

func request_pickup_dropped_item(drop_id: String, player_id: int) -> void:
	if multiplayer.is_server():
		_server_pickup_dropped_item(drop_id, player_id)
	else:
		rpc_id(1, "server_pickup_dropped_item", drop_id, player_id)

@rpc("any_peer", "reliable")
func server_pickup_dropped_item(drop_id: String, player_id: int) -> void:
	if not multiplayer.is_server() or multiplayer.get_remote_sender_id() != player_id:
		return
	_server_pickup_dropped_item(drop_id, player_id)

func _server_pickup_dropped_item(drop_id: String, player_id: int) -> void:
	if round_finished or not players.has(player_id) or _inventory_count(player_id) >= _inventory_slot_limit():
		return
	var target: Node3D
	for item in get_tree().get_nodes_in_group("dropped_items"):
		if is_instance_valid(item) and str(item.get("drop_id")) == drop_id:
			target = item
			break
	if target == null or players[player_id].global_position.distance_to(target.global_position) > 4.5:
		return
	var item_kind := str(target.get("item_kind"))
	var inventory: Dictionary = player_inventories.get(player_id, _default_inventory()).duplicate(true)
	inventory[item_kind] = int(inventory.get(item_kind, 0)) + 1
	player_inventories[player_id] = inventory
	sync_player_inventory.rpc(player_id, inventory)
	remove_dropped_item.rpc(drop_id)
	set_prompt("GEAR RECOVERED  //  " + item_kind.to_upper())

@rpc("authority", "call_local", "reliable")
func remove_dropped_item(drop_id: String) -> void:
	for item in get_tree().get_nodes_in_group("dropped_items"):
		if is_instance_valid(item) and str(item.get("drop_id")) == drop_id:
			item.queue_free()
			return

func _create_mobile_controls() -> void:
	mobile_visible = OS.has_feature("mobile")
	mobile_ui = Control.new()
	mobile_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	mobile_ui.visible = mobile_visible
	ui_root.add_child(mobile_ui)
	var movement: Button
	if mobile_left_handed:
		movement = _touch_button("◀", 0.925, 0.78, 0.975, 0.88, "left")
		_touch_button("▶", 0.805, 0.78, 0.855, 0.88, "right")
		_touch_button("▲", 0.865, 0.68, 0.915, 0.78, "forward")
		_touch_button("▼", 0.865, 0.88, 0.915, 0.98, "back")
		_touch_button("RUN", 0.70, 0.82, 0.78, 0.92, "sprint")
		_touch_button("USE", 0.06, 0.80, 0.14, 0.91, "interact_once", false)
		_touch_button("LAMP", 0.06, 0.66, 0.14, 0.77, "flashlight_once", false)
		_touch_button("BAG", 0.16, 0.52, 0.24, 0.62, "inventory_once", false)
		_touch_button("JUMP", 0.16, 0.84, 0.24, 0.94, "jump")
	else:
		movement = _touch_button("◀", 0.025, 0.78, 0.075, 0.88, "left")
		_touch_button("▶", 0.145, 0.78, 0.195, 0.88, "right")
		_touch_button("▲", 0.085, 0.68, 0.135, 0.78, "forward")
		_touch_button("▼", 0.085, 0.88, 0.135, 0.98, "back")
		_touch_button("RUN", 0.22, 0.82, 0.30, 0.92, "sprint")
		_touch_button("USE", 0.86, 0.80, 0.94, 0.91, "interact_once", false)
		_touch_button("LAMP", 0.86, 0.66, 0.94, 0.77, "flashlight_once", false)
		_touch_button("BAG", 0.76, 0.52, 0.84, 0.62, "inventory_once", false)
		_touch_button("JUMP", 0.76, 0.84, 0.84, 0.94, "jump")
	_emote_button("DANCE", 0.39, 0.88, "dance")
	_emote_button("WAVE", 0.48, 0.88, "wave")
	_emote_button("CHEER", 0.57, 0.88, "cheer")
	if movement:
		movement.tooltip_text = "Movement pad"

func _touch_button(text_value: String, left: float, top: float, right: float, bottom: float, action: String, hold: bool = true) -> Button:
	var button := _button(text_value, false)
	button.anchor_left = left
	button.anchor_top = top
	button.anchor_right = right
	button.anchor_bottom = bottom
	button.offset_left = 0
	button.offset_top = 0
	button.offset_right = 0
	button.offset_bottom = 0
	button.custom_minimum_size = Vector2(54, 48)
	button.modulate = Color(0.72, 1.0, 0.97, 0.78)
	mobile_ui.add_child(button)
	var begin := func() -> void:
		var player := _local_player()
		if player:
			player.call("set_mobile_action", action, true)
			if not hold:
				get_tree().create_timer(0.13).timeout.connect(func(): player.call("set_mobile_action", action, false))
	button.button_down.connect(begin)
	if hold:
		button.button_up.connect(func():
			var player := _local_player()
			if player:
				player.set_mobile_action(action, false)
		)
	return button


func _emote_button(caption: String, left: float, top: float, emote: String) -> void:
	var button := _button(caption, false)
	button.anchor_left = left
	button.anchor_top = top
	button.anchor_right = left + 0.085
	button.anchor_bottom = top + 0.085
	button.offset_left = 0
	button.offset_top = 0
	button.offset_right = 0
	button.offset_bottom = 0
	button.custom_minimum_size = Vector2(58, 42)
	button.modulate = Color(0.78, 0.96, 0.92, 0.84)
	mobile_ui.add_child(button)
	button.pressed.connect(func():
		var player := _local_player()
		if player and player.has_method("play_emote"):
			player.play_emote(emote)
	)

func _load_user_settings() -> void:
	settings_config.load("user://rogue_settings.cfg")
	player_display_name = str(settings_config.get_value("player", "name", "CREWMATE"))
	if player_display_name.strip_edges().is_empty():
		player_display_name = "CREWMATE"
	_apply_audio_setting("Master", float(settings_config.get_value("audio", "master", 0.85)))
	_apply_audio_setting("Music", float(settings_config.get_value("audio", "music", 0.65)))
	_apply_quality_setting(int(settings_config.get_value("video", "preset", 1)))
	move_key_layout = int(settings_config.get_value("controls", "key_layout", 0))
	mobile_left_handed = bool(settings_config.get_value("controls", "left_handed", false))
	invert_look_y = bool(settings_config.get_value("controls", "invert_y", false))
	_apply_key_layout()

func _apply_key_layout() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		InputMap.action_erase_events(action)
	var keys := [KEY_W, KEY_S, KEY_A, KEY_D] if move_key_layout == 0 else [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	_add_key_action("move_forward", keys[0])
	_add_key_action("move_back", keys[1])
	_add_key_action("move_left", keys[2])
	_add_key_action("move_right", keys[3])

func _apply_quality_setting(preset: int) -> void:
	var selected := clampi(preset, 0, 2)
	Engine.max_fps = [30, 45, 60][selected]
	get_viewport().scaling_3d_scale = [0.70, 0.85, 1.0][selected]

func _apply_audio_setting(bus_name: String, linear_value: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_linear(bus_index, clampf(linear_value, 0.0, 1.0))

func _open_settings() -> void:
	if is_instance_valid(settings_panel):
		return
	settings_panel = PanelContainer.new()
	settings_panel.anchor_left = 0.5
	settings_panel.anchor_top = 0.5
	settings_panel.anchor_right = 0.5
	settings_panel.anchor_bottom = 0.5
	settings_panel.offset_left = -225
	settings_panel.offset_top = -270
	settings_panel.offset_right = 225
	settings_panel.offset_bottom = 270
	settings_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.012, 0.035, 0.043, 0.99), Color(0.12, 0.83, 0.72)))
	ui_root.add_child(settings_panel)
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left", 18)
	outer.add_theme_constant_override("margin_right", 18)
	outer.add_theme_constant_override("margin_top", 14)
	outer.add_theme_constant_override("margin_bottom", 14)
	settings_panel.add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 8)
	scroll.add_child(stack)
	var title := _label("SYSTEM SETTINGS", 20, Color(0.45, 0.98, 0.84))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	stack.add_child(_label("PLAYER NAME", 10, Color(0.36, 0.79, 0.78)))
	var name_input := LineEdit.new()
	name_input.text = player_display_name
	name_input.max_length = 18
	name_input.custom_minimum_size.y = 38
	stack.add_child(name_input)
	stack.add_child(_label("MASTER VOLUME", 10, Color(0.36, 0.79, 0.78)))
	var master_slider := HSlider.new()
	master_slider.min_value = 0.0
	master_slider.max_value = 1.0
	master_slider.step = 0.05
	master_slider.value = float(settings_config.get_value("audio", "master", 0.85))
	stack.add_child(master_slider)
	stack.add_child(_label("MUSIC / AMBIENCE VOLUME", 10, Color(0.36, 0.79, 0.78)))
	var music_slider := HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = float(settings_config.get_value("audio", "music", 0.65))
	stack.add_child(music_slider)
	stack.add_child(_label("GRAPHICS QUALITY  /  3D SCALE + FPS", 10, Color(0.36, 0.79, 0.78)))
	var quality := OptionButton.new()
	quality.add_item("LOW  /  70% SCALE  /  30 FPS")
	quality.add_item("BALANCED  /  85% SCALE  /  45 FPS")
	quality.add_item("HIGH  /  100% SCALE  /  60 FPS")
	quality.select(int(settings_config.get_value("video", "preset", 1)))
	stack.add_child(quality)
	stack.add_child(_label("LOOK SENSITIVITY", 10, Color(0.36, 0.79, 0.78)))
	var sensitivity := HSlider.new()
	sensitivity.min_value = 0.0010
	sensitivity.max_value = 0.0045
	sensitivity.step = 0.0001
	sensitivity.value = float(settings_config.get_value("controls", "sensitivity", 0.0022))
	stack.add_child(sensitivity)
	stack.add_child(_label("KEYBOARD MOVEMENT", 10, Color(0.36, 0.79, 0.78)))
	var key_layout := OptionButton.new()
	key_layout.add_item("WASD")
	key_layout.add_item("ARROW KEYS")
	key_layout.select(move_key_layout)
	stack.add_child(key_layout)
	stack.add_child(_label("MOBILE BUTTON LAYOUT", 10, Color(0.36, 0.79, 0.78)))
	var mobile_layout := OptionButton.new()
	mobile_layout.add_item("STANDARD  /  MOVE LEFT")
	mobile_layout.add_item("LEFT-HANDED  /  MOVE RIGHT")
	mobile_layout.select(1 if mobile_left_handed else 0)
	stack.add_child(mobile_layout)
	stack.add_child(_label("VERTICAL LOOK", 10, Color(0.36, 0.79, 0.78)))
	var invert_y_option := OptionButton.new()
	invert_y_option.add_item("NORMAL")
	invert_y_option.add_item("INVERTED")
	invert_y_option.select(1 if invert_look_y else 0)
	stack.add_child(invert_y_option)
	var actions := HBoxContainer.new()
	stack.add_child(actions)
	var save := _button("SAVE SETTINGS", true)
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(save)
	var close := _button("CLOSE", false)
	close.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(close)
	save.pressed.connect(func():
		player_display_name = name_input.text.strip_edges().substr(0, 18)
		if player_display_name.is_empty():
			player_display_name = "CREWMATE"
		settings_config.set_value("player", "name", player_display_name)
		settings_config.set_value("audio", "master", master_slider.value)
		settings_config.set_value("audio", "music", music_slider.value)
		settings_config.set_value("video", "preset", quality.selected)
		settings_config.set_value("controls", "sensitivity", sensitivity.value)
		settings_config.set_value("controls", "key_layout", key_layout.selected)
		settings_config.set_value("controls", "left_handed", mobile_layout.selected == 1)
		settings_config.set_value("controls", "invert_y", invert_y_option.selected == 1)
		settings_config.save("user://rogue_settings.cfg")
		_apply_audio_setting("Master", master_slider.value)
		_apply_audio_setting("Music", music_slider.value)
		_apply_quality_setting(quality.selected)
		move_key_layout = key_layout.selected
		mobile_left_handed = mobile_layout.selected == 1
		invert_look_y = invert_y_option.selected == 1
		_apply_key_layout()
		var local_player := _local_player()
		if local_player:
			local_player.look_sensitivity = sensitivity.value
			local_player.invert_look_y = invert_look_y
			local_player.publish_player_name(player_display_name)
		if mobile_ui and is_instance_valid(mobile_ui):
			mobile_ui.queue_free()
			mobile_ui = null
			_create_mobile_controls()
		if is_instance_valid(settings_panel):
			ui_root.move_child(settings_panel, ui_root.get_child_count() - 1)
		set_prompt("SETTINGS SAVED  //  PROFILE UPDATED")
		_play_sfx("ui")
	)
	close.pressed.connect(func():
		settings_panel.queue_free()
		settings_panel = null
	)

func _local_player() -> SalvagePlayer:
	var id := multiplayer.get_unique_id()
	if players.has(id) and is_instance_valid(players[id]):
		return players[id] as SalvagePlayer
	return null

func _disconnect_to_menu() -> void:
	session_live = false
	if has_node("IndustrialAmbience"):
		get_node("IndustrialAmbience").call("stop_ambience")
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for player in players.values():
		if is_instance_valid(player):
			player.queue_free()
	players.clear()
	player_inventories.clear()
	_clear_world()
	_show_lobby("SESSION CLOSED  //  READY FOR NEXT DEPLOYMENT")

func _label(text_value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 13)
	var bg := Color(0.055, 0.34, 0.32) if primary else Color(0.055, 0.12, 0.15)
	var border := Color(0.15, 0.93, 0.78) if primary else Color(0.18, 0.39, 0.42)
	button.add_theme_stylebox_override("normal", _panel_style(bg, border))
	button.add_theme_stylebox_override("hover", _panel_style(bg.lightened(0.12), border.lightened(0.2)))
	button.add_theme_stylebox_override("pressed", _panel_style(bg.darkened(0.12), border))
	button.add_theme_color_override("font_color", Color(0.88, 0.98, 0.95))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.focus_mode = Control.FOCUS_NONE
	return button

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
