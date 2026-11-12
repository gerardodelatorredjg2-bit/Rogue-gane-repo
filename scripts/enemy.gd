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
	patrol_target = global_position + Vector3(5, 0, 4)
	movement_speed = [2.7, 3.5, 2.15][variant % 3]
	attack_range = 1.55 if variant != 2 else 1.85

func _build_robot() -> void:
	var accent: Color = COLORS[variant % COLORS.size()]
	var metal := _mat(Color(0.12, 0.16, 0.19), 0.84, 0.35)
	var armor := _mat(Color(0.25, 0.29, 0.30), 0.75, 0.42)
	var glow := _mat(accent, 0.45, 0.2, true)
	body = Node3D.new()
	body.position.y = 0.92
	add_child(body)
	_add_box(body, Vector3(0, 0.02, 0), Vector3(0.76, 0.94, 0.48), armor)
	_add_box(body, Vector3(0, 0.52, -0.03), Vector3(0.54, 0.45, 0.48), metal)
	head = Node3D.new()
	head.position = Vector3(0, 0.75, -0.03)
	body.add_child(head)
	_add_box(head, Vector3(0, 0, 0), Vector3(0.55, 0.44, 0.48), metal)
	_add_box(head, Vector3(0, 0.02, -0.25), Vector3(0.38, 0.10, 0.035), glow)
	_add_box(body, Vector3(-0.41, 0.08, -0.03), Vector3(0.14, 0.55, 0.16), glow)
	_add_box(body, Vector3(0.41, 0.08, -0.03), Vector3(0.14, 0.55, 0.16), glow)
	arm_left = _make_limb(body, Vector3(-0.51, 0.36, 0), Vector3(0.17, 0.60, 0.18), armor)
	arm_right = _make_limb(body, Vector3(0.51, 0.36, 0), Vector3(0.17, 0.60, 0.18), armor)
	leg_left = _make_limb(body, Vector3(-0.20, -0.65, 0.02), Vector3(0.20, 0.65, 0.22), metal)
	leg_right = _make_limb(body, Vector3(0.20, -0.65, 0.02), Vector3(0.20, 0.65, 0.22), metal)
	_add_box(body, Vector3(0, -0.12, 0.28), Vector3(0.34, 0.20, 0.26), glow)
	eye_light = OmniLight3D.new()
	eye_light.position = Vector3(0, 0.75, -0.42)
	eye_light.light_color = accent
	eye_light.light_energy = 0.75
	eye_light.omni_range = 4.0
	eye_light.shadow_enabled = false
	body.add_child(eye_light)

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
	var target: Node3D = _nearest_player()
	var direction := Vector3.ZERO
	if target and global_position.distance_to(target.global_position) < detection_range:
		state = "HUNT"
		direction = target.global_position - global_position
		direction.y = 0
		if direction.length() < attack_range and attack_clock <= 0.0:
			attack_clock = 1.35
			if game and game.has_method("server_enemy_attack"):
				game.call("server_enemy_attack", int(target.get("player_id")), 12.0 if variant == 1 else 8.0)
	else:
		state = "PATROL"
		direction = patrol_target - global_position
		direction.y = 0
		if direction.length() < 1.6:
			patrol_target = global_position + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
	if direction.length() > 0.15:
		direction = direction.normalized()
		rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), delta * 3.2)
		velocity.x = move_toward(velocity.x, direction.x * movement_speed * (1.28 if state == "HUNT" else 0.58), delta * 8.0)
		velocity.z = move_toward(velocity.z, direction.z * movement_speed * (1.28 if state == "HUNT" else 0.58), delta * 8.0)
	else:
		velocity.x = move_toward(velocity.x, 0, delta * 8.0)
		velocity.z = move_toward(velocity.z, 0, delta * 8.0)
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0
	move_and_slide()
	_animate_robot()
	sync_clock += delta
	if sync_clock >= 0.12:
		sync_clock = 0
		if game and game.has_method("broadcast_enemy_state"):
			game.call("broadcast_enemy_state", enemy_id, global_position, rotation.y, animation_clock)

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
	var stride := sin(animation_clock * (9.0 if state == "HUNT" else 3.2))
	var amount := 0.55 if state == "HUNT" else 0.18
	if body:
		body.position.y = 0.92 + absf(stride) * 0.05
	if arm_left:
		arm_left.rotation.x = stride * amount
	if arm_right:
		arm_right.rotation.x = -stride * amount
	if leg_left:
		leg_left.rotation.x = -stride * amount
	if leg_right:
		leg_right.rotation.x = stride * amount
	if head:
		head.rotation.y = sin(animation_clock * 1.4) * (0.22 if state == "PATROL" else 0.05)
	if eye_light:
		eye_light.light_energy = 0.55 + absf(sin(animation_clock * 4.2)) * 0.55
