extends CharacterBody3D
class_name SalvagePlayer

var player_id: int = 1
var game: Node
var view_camera: Camera3D
var flashlight: SpotLight3D
var flashlight_level: int = 0
var health: float = 100.0
var stamina: float = 100.0
var mobile_buttons: Dictionary = {}
var mobile_vector := Vector2.ZERO
var look_sensitivity: float = 0.0022
var network_clock: float = 0.0
var bob_clock: float = 0.0
var is_dead: bool = false
var body_visual: Node3D
var left_arm: Node3D
var right_arm: Node3D
var emote_id: int = 0
var emote_time: float = 0.0

func _ready() -> void:
	add_to_group("players")
	set_multiplayer_authority(player_id)
	collision_layer = 1
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	collider.shape = capsule
	collider.position.y = 0.9
	add_child(collider)
	_build_character()
	body_visual.visible = not is_multiplayer_authority()
	view_camera = Camera3D.new()
	view_camera.name = "ViewCamera"
	view_camera.position = Vector3(0, 1.56, 0)
	view_camera.fov = 78.0
	view_camera.current = is_multiplayer_authority()
	add_child(view_camera)
	flashlight = SpotLight3D.new()
	flashlight.position = Vector3(0.12, -0.08, -0.16)
	flashlight.rotation_degrees.x = -3
	flashlight.light_energy = 1.65
	flashlight.light_color = Color(0.72, 0.88, 0.92)
	flashlight.spot_range = 19.0
	flashlight.spot_angle = 38.0
	flashlight.shadow_enabled = false
	view_camera.add_child(flashlight)
	if is_multiplayer_authority():
		if not OS.has_feature("mobile"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_character() -> void:
	body_visual = Node3D.new()
	body_visual.position.y = 0.92
	add_child(body_visual)
	var suit := _material(Color(0.22, 0.30, 0.34), 0.65, 0.4)
	var dark := _material(Color(0.045, 0.075, 0.09), 0.45, 0.5)
	var visor := _material(Color(0.12, 0.82, 0.86), 0.8, 0.2, true)
	_add_capsule(body_visual, Vector3(0, 0, 0), 0.35, 0.82, suit)
	_add_box(body_visual, Vector3(0, 0.51, -0.015), Vector3(0.36, 0.30, 0.32), dark)
	_add_box(body_visual, Vector3(0, 0.53, -0.19), Vector3(0.25, 0.10, 0.035), visor)
	_add_box(body_visual, Vector3(0, -0.38, 0), Vector3(0.42, 0.14, 0.34), dark)
	left_arm = _make_arm(body_visual, Vector3(-0.40, 0.05, 0), suit)
	right_arm = _make_arm(body_visual, Vector3(0.40, 0.05, 0), suit)
	_add_box(body_visual, Vector3(-0.15, -0.75, 0), Vector3(0.19, 0.48, 0.22), suit)
	_add_box(body_visual, Vector3(0.15, -0.75, 0), Vector3(0.19, 0.48, 0.22), suit)

func _make_arm(parent: Node3D, pos: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	_add_capsule(pivot, Vector3(0, -0.23, 0), 0.12, 0.50, mat)
	_add_box(pivot, Vector3(0, -0.48, -0.015), Vector3(0.18, 0.17, 0.18), _material(Color(0.08, 0.15, 0.18), 0.6, 0.35))
	return pivot

func _add_capsule(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh_node.mesh = mesh
	mesh_node.position = pos
	mesh_node.material_override = mat
	parent.add_child(mesh_node)

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = pos
	mesh_node.material_override = mat
	parent.add_child(mesh_node)

func _material(color: Color, metallic: float, roughness: float, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emissive:
		mat.emission_enabled = true
		mat.emission = color * 0.6
	return mat

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority() or is_dead:
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var touch := Vector2.ZERO
	if _mobile_down("left"):
		touch.x -= 1.0
	if _mobile_down("right"):
		touch.x += 1.0
	if _mobile_down("forward"):
		touch.y -= 1.0
	if _mobile_down("back"):
		touch.y += 1.0
	var move_input := keyboard
	if touch.length() > 0.01:
		move_input = touch.normalized()
	var local_direction := Vector3(move_input.x, 0, move_input.y)
	var direction := (global_transform.basis * local_direction).normalized()
	var sprinting := Input.is_action_pressed("sprint") or _mobile_down("sprint")
	var speed := 4.1
	if sprinting and move_input.length() > 0.1 and stamina > 2.0:
		speed = 6.4
		stamina = maxf(0.0, stamina - 27.0 * delta)
	else:
		stamina = minf(100.0, stamina + 17.0 * delta)
	velocity.x = move_toward(velocity.x, direction.x * speed, 22.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 22.0 * delta)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	elif Input.is_action_just_pressed("jump") or _mobile_down("jump"):
		velocity.y = 6.0
	move_and_slide()
	bob_clock += delta * (10.0 if move_input.length() > 0.1 else 2.2)
	if emote_time > 0.0:
		emote_time = maxf(0.0, emote_time - delta)
		_animate_emote()
	if body_visual:
		body_visual.position.y = 0.92 + (sin(bob_clock) * 0.025 if move_input.length() > 0.1 else 0.0)
		if left_arm:
			left_arm.rotation.x = sin(bob_clock) * 0.18
			right_arm.rotation.x = -sin(bob_clock) * 0.18
	network_clock += delta
	if network_clock >= 0.10:
		network_clock = 0.0
		_send_network_state()
	if Input.is_action_just_pressed("interact") or consume_mobile_action("interact_once"):
		_interact()
	if Input.is_action_just_pressed("inventory") and game and game.has_method("open_inventory"):
		game.call("open_inventory")
	if Input.is_action_just_pressed("flashlight") or consume_mobile_action("flashlight_once"):
		flashlight.visible = not flashlight.visible
	if Input.is_action_just_pressed("emote_dance") or consume_mobile_action("emote_dance"):
		play_emote(1)
	if Input.is_action_just_pressed("emote_wave") or consume_mobile_action("emote_wave"):
		play_emote(2)
	if Input.is_action_just_pressed("emote_robot") or consume_mobile_action("emote_robot"):
		play_emote(3)

func upgrade_flashlight() -> void:
	flashlight_level = mini(2, flashlight_level + 1)
	if flashlight:
		flashlight.spot_range = 19.0 + flashlight_level * 5.0
		flashlight.light_energy = 1.65 + flashlight_level * 0.45
		flashlight.spot_angle = 38.0 + flashlight_level * 3.0

func play_emote(which: int) -> void:
	if which < 1 or which > 3 or not is_multiplayer_authority():
		return
	emote_id = which
	emote_time = 2.8
	_animate_emote()

func _animate_emote() -> void:
	if not body_visual or not left_arm or not right_arm:
		return
	var t := 2.8 - emote_time
	match emote_id:
		1:
			left_arm.rotation.z = sin(t * 10.0) * 0.95
			right_arm.rotation.z = -sin(t * 10.0) * 0.95
			body_visual.rotation.y = sin(t * 5.0) * 0.28
		2:
			left_arm.rotation.z = -0.15
			right_arm.rotation.z = -1.8 + sin(t * 8.0) * 0.35
			body_visual.rotation.y = -0.12
		3:
			left_arm.rotation.z = sin(t * 12.0) * 0.5
			right_arm.rotation.z = -sin(t * 12.0) * 0.5
			body_visual.rotation.y = sin(t * 12.0) * 0.18
	if emote_time <= 0.0:
		left_arm.rotation.z = 0.0
		right_arm.rotation.z = 0.0
		body_visual.rotation.y = 0.0

func _process(_delta: float) -> void:
	if is_multiplayer_authority() and game and game.has_method("set_local_player_status"):
		game.set_local_player_status(health, stamina)

func _mobile_down(action: String) -> bool:
	return bool(mobile_buttons.get(action, false))

func set_mobile_action(action: String, pressed: bool) -> void:
	mobile_buttons[action] = pressed

func consume_mobile_action(action: String) -> bool:
	if bool(mobile_buttons.get(action, false)):
		mobile_buttons[action] = false
		return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_apply_look(event.relative)
	elif event is InputEventScreenDrag:
		_apply_look(event.relative * 1.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventKey and event.pressed and event.keycode == KEY_1:
		play_emote(1)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_2:
		play_emote(2)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_3:
		play_emote(3)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not OS.has_feature("mobile") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _apply_look(relative: Vector2) -> void:
	rotation.y -= relative.x * look_sensitivity
	if view_camera:
		view_camera.rotation.x = clampf(view_camera.rotation.x - relative.y * look_sensitivity, -1.35, 1.35)

func _interact() -> void:
	if not game:
		return
	var start := view_camera.global_position
	var finish := start + (-view_camera.global_transform.basis.z * 3.6)
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	query.exclude = [get_rid()]
	query.collision_mask = 3
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is Node and collider.is_in_group("loot"):
			game.call("request_loot", str(collider.get("item_id")), player_id)
			return
		if collider is Node and collider.is_in_group("ship_terminal"):
			game.call("open_ship_terminal", player_id)
			return
	if game.has_method("get_exit_position"):
		if global_position.distance_to(game.call("get_exit_position")) < 5.2:
			game.call("request_extract", player_id)
		elif game.has_method("set_prompt"):
			game.call("set_prompt", "NO HAY SEÑAL // BUSCA EL PUNTO DE EXTRACCIÓN")

func _send_network_state() -> void:
	if not multiplayer.has_multiplayer_peer():
		return
	if multiplayer.is_server():
		rpc("client_receive_transform", global_position, rotation.y, view_camera.rotation.x)
	else:
		rpc_id(1, "server_receive_transform", global_position, rotation.y, view_camera.rotation.x)

@rpc("any_peer", "unreliable")
func server_receive_transform(pos: Vector3, yaw: float, pitch: float) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != player_id:
		return
	global_position = pos
	rotation.y = yaw
	view_camera.rotation.x = pitch
	rpc("client_receive_transform", pos, yaw, pitch)

@rpc("any_peer", "call_remote", "unreliable")
func client_receive_transform(pos: Vector3, yaw: float, pitch: float) -> void:
	if is_multiplayer_authority():
		return
	global_position = global_position.lerp(pos, 0.72)
	rotation.y = yaw
	view_camera.rotation.x = pitch

func apply_damage(amount: float) -> void:
	if is_dead:
		return
	health = maxf(0.0, health - amount)
	if health <= 0.0:
		is_dead = true
		velocity = Vector3.ZERO
		if game and game.has_method("player_was_downed"):
			game.call("player_was_downed", player_id)
