extends CharacterBody3D
class_name SalvageStalker

var enemy_id: String = ""
var game: Node
var variant: int = 0
var movement_speed: float = 2.7
var detection_range: float = 22.0
var attack_range: float = 1.65
var attack_clock: float = 0.0
var sync_clock: float = 0.0
var animation_clock: float = 0.0
var patrol_target := Vector3.ZERO
var state: String = "PATROL"
var head: Node3D
var arm_left: Node3D
var arm_right: Node3D
var leg_left: Node3D
var leg_right: Node3D
var body: Node3D
var eye_light: OmniLight3D
var stalker_audio: AudioStreamPlayer3D
var last_known_position := Vector3.ZERO
var memory_remaining: float = 0.0
var sound_cooldown: float = 0.0

const EXTERNAL_MODELS := [
	"res://assets/models/robots/minion-a01.glb",
	"res://assets/models/robots/minion-b01.glb",
	"res://assets/models/robots/minion-c01.glb",
	"res://assets/models/robots/minion-d01.glb"
]

const COLORS := [Color(0.95, 0.23, 0.16), Color(0.76, 0.30, 1.0), Color(0.92, 0.66, 0.18)]

func _ready() -> void:
	add_to_group("enemies")
	set_multiplayer_authority(1)
	collision_layer = 4
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.9
	collider.shape = capsule
	collider.position.y = 0.94
	add_child(collider)
	_build_robot()
	_create_stalker_audio()
	patrol_target = global_position + Vector3(5, 0, 4)
	movement_speed = [2.7, 3.5, 2.15][variant % 3]
	attack_range = 1.55 if variant != 2 else 1.85
	var contract_day := int(game.round_index) if game and game.get("round_index") != null else 1
	var escalation := minf(0.42, float(maxi(0, contract_day - 1)) * 0.045)
	movement_speed *= 1.0 + escalation
	detection_range += float(maxi(0, contract_day - 1)) * 0.8

func _build_robot() -> void:
	var accent: Color = COLORS[variant % COLORS.size()]
	var metal := _mat(Color(0.055, 0.075, 0.09), 0.88, 0.28)
	var armor := _mat(Color(0.20, 0.25, 0.28), 0.82, 0.34)
	var glow := _mat(accent, 0.45, 0.16, true)
	body = Node3D.new()
	body.position.y = 0.92
	add_child(body)
	var model_loaded := false
	var model_path: String = EXTERNAL_MODELS[variant % EXTERNAL_MODELS.size()]
	if ResourceLoader.exists(model_path):
		var imported_scene := load(model_path) as PackedScene
		if imported_scene:
			var imported_model := imported_scene.instantiate() as Node3D
			if imported_model:
				imported_model.name = "ImportedStalker"
				imported_model.position = Vector3(0, -0.88, 0)
				imported_model.rotation.y = PI
				imported_model.scale = Vector3.ONE * 0.92
				body.add_child(imported_model)
				_play_imported_animation(imported_model)
				model_loaded = true
	if not model_loaded:
		_add_box(body, Vector3(0, 0.02, 0), Vector3(0.76, 0.94, 0.48), armor)
		_add_box(body, Vector3(0, 0.52, -0.03), Vector3(0.54, 0.45, 0.48), metal)
		head = Node3D.new()
		head.position = Vector3(0, 0.75, -0.03)
		body.add_child(head)
		_add_box(head, Vector3(0, 0, 0), Vector3(0.55, 0.44, 0.48), metal)
		_add_box(head, Vector3(0, 0.02, -0.25), Vector3(0.38, 0.10, 0.035), glow)
		arm_left = _make_limb(body, Vector3(-0.51, 0.36, 0), Vector3(0.17, 0.60, 0.18), armor)
		arm_right = _make_limb(body, Vector3(0.51, 0.36, 0), Vector3(0.17, 0.60, 0.18), armor)
		leg_left = _make_limb(body, Vector3(-0.20, -0.65, 0.02), Vector3(0.20, 0.65, 0.22), metal)
		leg_right = _make_limb(body, Vector3(0.20, -0.65, 0.02), Vector3(0.20, 0.65, 0.22), metal)
	# Exposed reactor, split jaw, cable spine and hooked shoulder blades make
	# the otherwise friendly low-poly base models read as industrial predators.
	var red := _mat(Color(1.0, 0.025, 0.035), 0.38, 0.16, true)
	_add_box(body, Vector3(0, 0.10, -0.29), Vector3(0.31, 0.24, 0.065), metal)
	_add_box(body, Vector3(0, 0.11, -0.335), Vector3(0.17, 0.10, 0.025), red)
	_add_box(body, Vector3(0, 0.67, -0.33), Vector3(0.42, 0.10, 0.08), metal)
	for tooth in range(5):
		_add_box(body, Vector3(-0.16 + float(tooth) * 0.08, 0.60, -0.38), Vector3(0.035, 0.095, 0.025), glow)
	for segment in range(5):
		_add_box(body, Vector3(0, 0.52 - float(segment) * 0.23, 0.31), Vector3(0.14, 0.15, 0.13), metal)
	for side in [-1.0, 1.0]:
		_add_box(body, Vector3(side * 0.47, 0.30, 0.02), Vector3(0.20, 0.22, 0.26), armor)
		_add_spike(body, Vector3(side * 0.48, 0.45, 0.10), side, glow)
		_add_spike(body, Vector3(side * 0.58, 0.16, 0.06), side, metal)
		_add_box(body, Vector3(side * 0.62, -0.12, -0.06), Vector3(0.12, 0.40, 0.11), metal)
		for claw in range(3):
			_add_box(body, Vector3(side * (0.65 + float(claw % 2) * 0.035), -0.39, -0.19 + float(claw - 1) * 0.11), Vector3(0.055, 0.22, 0.055), glow)
	eye_light = OmniLight3D.new()
	eye_light.position = Vector3(0, 0.78, -0.43)
	eye_light.light_color = Color(1.0, 0.025, 0.02)
	eye_light.light_energy = 1.1
	eye_light.omni_range = 5.2
	eye_light.shadow_enabled = false
	body.add_child(eye_light)

func _add_spike(parent: Node3D, pos: Vector3, side: float, mat: Material) -> void:
	var spike := MeshInstance3D.new()
	var mesh := ConeMesh.new()
	mesh.bottom_radius = 0.12
	mesh.top_radius = 0.0
	mesh.height = 0.52
	mesh.radial_segments = 6
	spike.mesh = mesh
	spike.position = pos
	spike.rotation.z = -side * 0.72
	spike.material_override = mat
	parent.add_child(spike)

func _create_stalker_audio() -> void:
	stalker_audio = AudioStreamPlayer3D.new()
	stalker_audio.name = "StalkerAudio"
	stalker_audio.volume_db = -8.0
	stalker_audio.max_distance = 26.0
	stalker_audio.unit_size = 7.0
	stalker_audio.bus = "Master"
	add_child(stalker_audio)

func _play_random_stalker_sound(attack_sound: bool) -> void:
	if not game or not is_instance_valid(stalker_audio):
		return
	var files: Array = game.get("sfx_files")
	if files.is_empty():
		return
	var preferred: Array[String] = []
	for file_name in files:
		var low_name := str(file_name).to_lower()
		if (attack_sound and (low_name.contains("impact") or low_name.contains("hit") or low_name.contains("laser"))) or (not attack_sound and (low_name.contains("alarm") or low_name.contains("robot") or low_name.contains("engine") or low_name.contains("power"))):
			preferred.append(str(file_name))
	if preferred.is_empty():
		for file_name in files:
			preferred.append(str(file_name))
	var chosen := preferred[randi_range(0, preferred.size() - 1)]
	var stream := load("res://assets/audio/kenney_sci_fi/%s" % chosen) as AudioStream
	if stream:
		stalker_audio.stream = stream
		stalker_audio.play()

@rpc("authority", "call_local", "reliable")
func play_stalker_audio() -> void:
	_play_random_stalker_sound(false)

@rpc("authority", "call_local", "reliable")
func play_attack_audio() -> void:
	_play_random_stalker_sound(true)

func _play_imported_animation(model: Node3D) -> void:
	var animation_nodes := model.find_children("*", "AnimationPlayer", true, false)
	for animation_node in animation_nodes:
		var animation_player := animation_node as AnimationPlayer
		if animation_player:
			var animations := animation_player.get_animation_list()
			if not animations.is_empty():
				animation_player.play(animations[0])
				return

func _make_limb(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	_add_box(pivot, Vector3(0, -size.y * 0.42, 0), size, mat)
	var joint := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.14
	sphere.height = 0.28
	joint.mesh = sphere
	joint.material_override = mat
	joint.position.y = -size.y * 0.80
	pivot.add_child(joint)
	return pivot

func _add_box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = pos
	node.material_override = mat
	parent.add_child(node)

func _mat(color: Color, metallic: float, roughness: float, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if emissive:
		mat.emission_enabled = true
		mat.emission = color * 0.8
	return mat

func _physics_process(delta: float) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
	animation_clock += delta
	attack_clock = maxf(0.0, attack_clock - delta)
	sound_cooldown = maxf(0.0, sound_cooldown - delta)
	memory_remaining = maxf(0.0, memory_remaining - delta)
	var target: Node3D = _nearest_player()
	var direction := Vector3.ZERO
	var sees_target := target != null and global_position.distance_to(target.global_position) < detection_range and _has_line_of_sight(target)
	if sees_target:
		if state != "HUNT" and sound_cooldown <= 0.0:
			rpc("play_stalker_audio")
			sound_cooldown = 7.0
		state = "HUNT"
		last_known_position = target.global_position
		memory_remaining = 4.0
		direction = target.global_position - global_position
		direction.y = 0.0
		if direction.length() < attack_range and attack_clock <= 0.0:
			attack_clock = 1.35
			var attack_direction := (target.global_position - global_position).normalized()
			velocity += attack_direction * (5.2 + float(variant) * 0.45) + Vector3.UP * 1.0
			rpc("play_attack_audio")
			if game and game.has_method("server_enemy_attack"):
				game.call("server_enemy_attack", int(target.get("player_id")), 12.0 if variant == 1 else 8.0)
	elif memory_remaining > 0.0:
		state = "SEARCH"
		direction = last_known_position - global_position
		direction.y = 0.0
		if direction.length() < 1.5:
			memory_remaining = 0.0
			patrol_target = global_position + Vector3(randf_range(-7.0, 7.0), 0, randf_range(-7.0, 7.0))
	else:
		state = "PATROL"
		direction = patrol_target - global_position
		direction.y = 0.0
		if direction.length() < 1.6:
			patrol_target = global_position + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
	if direction.length() > 0.15:
		direction = direction.normalized()
		direction = _avoid_wall(direction)
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * (4.2 if state == "HUNT" else 2.6))
		var speed_factor := 1.35 if state == "HUNT" else (0.78 if state == "SEARCH" else 0.58)
		velocity.x = move_toward(velocity.x, direction.x * movement_speed * speed_factor, delta * 8.0)
		velocity.z = move_toward(velocity.z, direction.z * movement_speed * speed_factor, delta * 8.0)
	else:
		velocity.x = move_toward(velocity.x, 0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0, delta * 8.0)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0.0
	move_and_slide()
	for collision_index in range(get_slide_collision_count()):
		var collision := get_slide_collision(collision_index)
		if absf(collision.get_normal().y) < 0.35:
			velocity += collision.get_normal() * 0.65
	_animate_robot()
	sync_clock += delta
	if sync_clock >= 0.12:
		sync_clock = 0.0
		if game and game.has_method("broadcast_enemy_state"):
			game.call("broadcast_enemy_state", enemy_id, global_position, rotation.y, animation_clock)

func _has_line_of_sight(target: Node3D) -> bool:
	var start := global_position + Vector3.UP * 1.15
	var finish := target.global_position + Vector3.UP * 1.0
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	return hit.get("collider") == target

func _avoid_wall(direction: Vector3) -> Vector3:
	var start := global_position + Vector3.UP * 0.8
	var finish := start + direction * 1.75
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	query.exclude = [get_rid()]
	query.collision_mask = 1
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and not (hit.get("collider") is Node and (hit.get("collider") as Node).is_in_group("players")):
		var normal: Vector3 = hit.get("normal")
		normal.y = 0.0
		if normal.length() > 0.1:
			return (direction + normal.normalized() * 1.35).normalized()
	return direction

func _nearest_player() -> Node3D:
	var best: Node3D
	var best_distance := detection_range + 1.0
	for node in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(node) or node.is_dead:
			continue
		var d := global_position.distance_to(node.global_position)
		if d < best_distance:
			best_distance = d
			best = node
	return best

func _animate_robot() -> void:
	var hunt_mode := state == "HUNT"
	var searching := state == "SEARCH"
	var stride := sin(animation_clock * (10.5 if hunt_mode else (4.4 if searching else 2.6)))
	var amount := 0.72 if hunt_mode else (0.38 if searching else 0.16)
	var windup := attack_clock > 0.0
	var attack_phase := 1.35 - attack_clock
	var lean := 0.0
	if windup:
		lean = -0.30 if attack_phase < 0.36 else (0.38 if attack_phase < 0.72 else 0.10)
	if body:
		body.position.y = 0.92 + absf(stride) * (0.07 if hunt_mode else 0.035)
		body.rotation.x = lean
		body.rotation.z = sin(animation_clock * 3.2) * (0.08 if hunt_mode else 0.025)
	if arm_left:
		arm_left.rotation.x = stride * amount + (1.1 if windup and attack_phase < 0.72 else 0.0)
		arm_left.rotation.z = 0.0 if not windup else 0.38
	if arm_right:
		arm_right.rotation.x = -stride * amount + (-1.2 if windup and attack_phase < 0.72 else 0.0)
		arm_right.rotation.z = 0.0 if not windup else -0.38
	if leg_left:
		leg_left.rotation.x = -stride * amount
	if leg_right:
		leg_right.rotation.x = stride * amount
	if head:
		head.rotation.y = sin(animation_clock * (3.5 if searching else 1.6)) * (0.34 if searching else 0.12)
		head.rotation.x = -0.30 if windup else (0.08 if hunt_mode else 0.0)
	if eye_light:
		var pulse := absf(sin(animation_clock * (8.0 if hunt_mode else 4.0)))
		eye_light.light_energy = 0.75 + pulse * (1.1 if hunt_mode else 0.55)

