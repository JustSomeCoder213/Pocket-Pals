class_name DecorationBuilder
extends RefCounted

## Builds a placeholder model for a decoration item. The returned node's origin
## is the slot position (floor level for floor items, the wall spot for paintings).
## To use a real model later, replace the body of build() with an instantiated scene.

static func build(item: ItemData) -> Node3D:
	var root := Node3D.new()
	match item.visual:
		"plant":
			_build_plant(root, item)
		"rug":
			_build_rug(root, item)
		"painting":
			_build_painting(root, item)
		"lamp":
			_build_lamp(root, item)
		_:
			_add_box(root, Vector3(0.5, 0.5, 0.5), Vector3(0.0, 0.25, 0.0), item.color)
	return root


static func _build_plant(root: Node3D, item: ItemData) -> void:
	_add_cylinder(root, 0.3, 0.22, 0.5, Vector3(0.0, 0.25, 0.0), item.accent_color, false)
	_add_sphere(root, 0.32, Vector3(0.0, 0.85, 0.0), Vector3(1.0, 0.9, 1.0), item.color)
	_add_sphere(root, 0.22, Vector3(0.22, 1.1, 0.08), Vector3.ONE, item.color.lightened(0.15))
	_add_sphere(root, 0.22, Vector3(-0.2, 1.05, -0.1), Vector3.ONE, item.color.darkened(0.1))


static func _build_rug(root: Node3D, item: ItemData) -> void:
	_add_box(root, Vector3(3.0, 0.03, 2.2), Vector3(0.0, 0.015, 0.0), item.color)
	_add_box(root, Vector3(2.4, 0.034, 1.6), Vector3(0.0, 0.017, 0.0), item.accent_color)


static func _build_painting(root: Node3D, item: ItemData) -> void:
	_add_box(root, Vector3(2.0, 1.2, 0.08), Vector3.ZERO, item.accent_color)  # frame
	_add_box(root, Vector3(1.7, 0.9, 0.1), Vector3.ZERO, item.color)          # canvas
	_add_sphere(root, 0.22, Vector3(0.35, 0.12, 0.05), Vector3(1.0, 1.0, 0.3), Color(1.0, 0.9, 0.3))  # sun


static func _build_lamp(root: Node3D, item: ItemData) -> void:
	_add_cylinder(root, 0.2, 0.2, 0.05, Vector3(0.0, 0.025, 0.0), item.accent_color, false)  # base
	_add_cylinder(root, 0.04, 0.04, 1.6, Vector3(0.0, 0.85, 0.0), item.accent_color, false)  # pole
	_add_cylinder(root, 0.15, 0.3, 0.4, Vector3(0.0, 1.75, 0.0), item.color, true)           # glowing shade
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.7, 0.0)
	light.light_color = Color(1.0, 0.85, 0.6)
	light.light_energy = 1.2
	light.omni_range = 6.0
	root.add_child(light)


# ---------- primitive helpers ----------

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)


static func _add_sphere(parent: Node3D, radius: float, pos: Vector3, scl: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scl
	parent.add_child(instance)


static func _add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color, glow: bool) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	var material := _material(color)
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
