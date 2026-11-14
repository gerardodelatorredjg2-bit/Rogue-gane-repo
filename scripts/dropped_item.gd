extends RigidBody3D
class_name DroppedInventoryItem

var drop_id: String = ""
var item_kind: String = "battery"
var visual: Node3D

const COLORS := {
	"medkit": Color(0.92, 0.18, 0.17),
	"battery": Color(0.98, 0.67, 0.12),
	"scanner": Color(0.18, 0.75, 0.95)
}

func _ready() -> void:
	add_to_group("dropped_items")
	collision_layer = 2
	collision_mask = 1
	mass = 0.55
	linear_damp = 1.2
	angular_damp = 1.8
	continuous_cd = true
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.28
	physics.friction = 0.82
	physics_material_override = physics
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.34, 0.20, 0.30)
	collider.shape = shape
	add_child(collider)
	visual = Node3D.new()
	add_child(visual)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.34, 0.20, 0.30)
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLORS.get(item_kind, Color(0.5, 0.8, 0.8))
	mat.metallic = 0.62
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = mat.albedo_color * 0.10
	mesh_node.material_override = mat
	visual.add_child(mesh_node)
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.35, 0.035, 0.055)
	stripe.mesh = stripe_mesh
	stripe.position.y = 0.03
	stripe.material_override = _stripe_material()
	visual.add_child(stripe)
	var label := Label3D.new()
	label.text = item_kind.to_upper()
	label.position.y = 0.24
	label.font_size = 20
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.78, 0.94, 0.92)
	visual.add_child(label)

func _stripe_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.10, 0.13)
	mat.metallic = 0.3
	mat.roughness = 0.45
	return mat

func settle_visual(delta: float) -> void:
	if visual and not sleeping:
		visual.rotation.y += delta * minf(3.2, angular_velocity.length())
