extends StaticBody3D
class_name SalvageLoot

var item_id: String = ""
var credit_value: int = 15
var item_kind: int = 0
var spin_phase: float = 0.0
var visual: Node3D

const COLORS := [
	Color(0.18, 0.95, 0.88),
	Color(1.0, 0.62, 0.22),
	Color(0.76, 0.48, 1.0),
	Color(0.92, 0.84, 0.38)
]

func _ready() -> void:
	add_to_group("loot")
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.52
	shape.shape = sphere
	shape.position.y = 0.48
	add_child(shape)
	visual = Node3D.new()
	visual.position.y = 0.52
	add_child(visual)
	var core := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.48, 0.48, 0.48)
	core.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLORS[item_kind % COLORS.size()]
	mat.metallic = 0.72
	mat.roughness = 0.24
	mat.emission_enabled = true
	mat.emission = COLORS[item_kind % COLORS.size()] * 0.28
	core.material_override = mat
	visual.add_child(core)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.34
	ring_mesh.outer_radius = 0.39
	ring.mesh = ring_mesh
	ring.rotation.x = PI * 0.5
	ring.material_override = mat
	visual.add_child(ring)
	var light := OmniLight3D.new()
	light.position.y = 0.16
	light.light_color = COLORS[item_kind % COLORS.size()]
	light.light_energy = 0.5
	light.omni_range = 3.0
	light.shadow_enabled = false
	visual.add_child(light)

func _process(delta: float) -> void:
	if is_instance_valid(visual):
		spin_phase += delta
		visual.rotation.y += delta * 1.25
		visual.position.y = 0.52 + sin(spin_phase * 2.0) * 0.10
