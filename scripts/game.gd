extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const WorldBuilderScript = preload("res://scripts/world_builder.gd")

const GAME_PORT := 28960
const MAX_CLIENTS := 4
const DEFAULT_QUOTA := 6

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
var canvas: CanvasLayer
var ui_root: Control
var status_label: Label
var objective_label: Label
var credits_label: Label
var health_label: Label
var stamina_label: Label
var prompt_label: Label
var map_label: Label
var timer_label: Label
var lobby_map_select: OptionButton
var lobby_ip_input: LineEdit
var lobby_status: Label
var result_panel: PanelContainer
var mobile_ui: Control
var mobile_visible: bool = false

func _ready() -> void:
	Engine.max_fps = 30 if OS.has_feature("mobile") else 60
	_configure_input()
	_create_canvas()
	_show_lobby()
	set_process(true)

func _process(delta: float) -> void:
	if session_live and not round_finished:
		shift_seconds += delta
		if is_instance_valid(timer_label):
			var total := int(shift_seconds)
			timer_label.text = "%02d:%02d" % [total / 60, total % 60]

func _configure_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("interact", KEY_E)
	_add_key_action("flashlight", KEY_F)

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
	prompt_label = null
	map_label = null
	timer_label = null
	mobile_ui = null
	result_panel = null

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
	rpc_id(peer_id, "receive_session_config", current_map, session_seed, quota, credits, round_index, collected)
	for existing_id in players.keys():
		var existing: Node = players[existing_id]
		if is_instance_valid(existing):
			rpc_id(peer_id, "receive_spawn_player", int(existing_id), existing.global_position)
	var spawn := _spawn_position_for(peer_id)
	receive_spawn_player.rpc(peer_id, spawn)
	for enemy_id in enemies.keys():
		var enemy: Node = enemies[enemy_id]
		if is_instance_valid(enemy):
			rpc_id(peer_id, "receive_enemy_spawn", str(enemy_id), enemy.global_position, enemy.variant)
	set_prompt("CREW CONNECTED  //  PLAYER %d JOINED" % peer_id)

func _on_peer_disconnected(peer_id: int) -> void:
	if players.has(peer_id):
		var node: Node = players[peer_id]
		if is_instance_valid(node):
			node.queue_free()
		players.erase(peer_id)
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
	_create_hud()
	_update_hud()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _clear_world() -> void:
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
	for i in range(mini(3, locations.size())):
		receive_enemy_spawn.rpc("hunter_%02d" % i, locations[i], i % 3)

func _spawn_player(peer_id: int, pos: Vector3) -> void:
	if players.has(peer_id) and is_instance_valid(players[peer_id]):
		return
	var player = PlayerScript.new()
	player.name = "Player_%d" % peer_id
	player.player_id = peer_id
	player.game = self
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
		if node.item_id == item_id:
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
	var target: Node
	for node in get_tree().get_nodes_in_group("loot"):
		if node.item_id == item_id:
			target = node
			break
	if not target or not is_instance_valid(target):
		return
	if player.global_position.distance_to(target.global_position) > 5.0:
		return
	credits += int(target.credit_value)
	collected += 1
	sync_loot_count.rpc(collected, credits)
	remove_loot.rpc(item_id)
	set_prompt("SALVAGE SECURED  //  +%d CREDITS" % target.credit_value)

@rpc("authority", "call_local", "reliable")
func sync_loot_count(new_count: int, new_credits: int) -> void:
	collected = new_count
	credits = new_credits
	_update_hud()

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
	quota = DEFAULT_QUOTA + int(round_index / 3)
	round_index += 1
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

func set_local_player_status(current_health: float, current_stamina: float) -> void:
	if is_instance_valid(health_label):
		health_label.text = "SUIT  %03d%%" % int(current_health)
	if is_instance_valid(stamina_label):
		stamina_label.text = "STAMINA  %03d%%" % int(current_stamina)

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

func _create_hud() -> void:
	_clear_ui()
	var top := PanelContainer.new()
	top.anchor_left = 0.02
	top.anchor_top = 0.025
	top.anchor_right = 0.98
	top.anchor_bottom = 0.025
	top.offset_bottom = 56
	top.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.035, 0.045, 0.86), Color(0.08, 0.54, 0.54, 0.55)))
	ui_root.add_child(top)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	top.add_child(margin)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 24)
	margin.add_child(bar)
	map_label = _label("", 12, Color(0.39, 0.9, 0.82))
	map_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(map_label)
	objective_label = _label("", 14, Color(0.91, 0.97, 0.92))
	bar.add_child(objective_label)
	credits_label = _label("", 14, Color(1.0, 0.73, 0.36))
	bar.add_child(credits_label)
	timer_label = _label("00:00", 14, Color(0.70, 0.84, 0.88))
	bar.add_child(timer_label)
	health_label = _label("SUIT 100%", 12, Color(0.40, 0.94, 0.74))
	health_label.anchor_left = 0.025
	health_label.anchor_top = 0.12
	health_label.anchor_right = 0.20
	health_label.anchor_bottom = 0.16
	ui_root.add_child(health_label)
	stamina_label = _label("STAMINA 100%", 12, Color(0.40, 0.94, 0.74))
	stamina_label.anchor_left = 0.025
	stamina_label.anchor_top = 0.16
	stamina_label.anchor_right = 0.22
	stamina_label.anchor_bottom = 0.20
	ui_root.add_child(stamina_label)
	prompt_label = _label("RECOVER THE SIGNAL  //  FIND THE SALVAGE", 13, Color(0.55, 0.92, 0.84))
	prompt_label.anchor_left = 0.2
	prompt_label.anchor_top = 0.86
	prompt_label.anchor_right = 0.8
	prompt_label.anchor_bottom = 0.94
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ui_root.add_child(prompt_label)
	_create_mobile_controls()
	_update_hud()

func _create_mobile_controls() -> void:
	mobile_visible = OS.has_feature("mobile")
	mobile_ui = Control.new()
	mobile_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_ui.mouse_filter = Control.MOUSE_FILTER_PASS
	mobile_ui.visible = mobile_visible
	ui_root.add_child(mobile_ui)
	var movement := _touch_button("◀", 0.025, 0.78, 0.075, 0.88, "left")
	_touch_button("▶", 0.145, 0.78, 0.195, 0.88, "right")
	_touch_button("▲", 0.085, 0.68, 0.135, 0.78, "forward")
	_touch_button("▼", 0.085, 0.88, 0.135, 0.98, "back")
	_touch_button("RUN", 0.22, 0.82, 0.30, 0.92, "sprint")
	_touch_button("USE", 0.86, 0.80, 0.94, 0.91, "interact_once", false)
	_touch_button("LAMP", 0.86, 0.66, 0.94, 0.77, "flashlight_once", false)
	_touch_button("JUMP", 0.76, 0.84, 0.84, 0.94, "jump")
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
			player.set_mobile_action(action, true)
			if not hold:
				get_tree().create_timer(0.13).timeout.connect(func(): player.set_mobile_action(action, false))
	button.button_down.connect(begin)
	if hold:
		button.button_up.connect(func():
			var player := _local_player()
			if player:
				player.set_mobile_action(action, false)
		)
	return button

func _local_player() -> Node:
	var id := multiplayer.get_unique_id()
	if players.has(id) and is_instance_valid(players[id]):
		return players[id]
	return null

func _disconnect_to_menu() -> void:
	session_live = false
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for player in players.values():
		if is_instance_valid(player):
			player.queue_free()
	players.clear()
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
