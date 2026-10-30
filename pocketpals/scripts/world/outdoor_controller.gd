class_name OutdoorController
extends Node3D

## The outdoor photography area, built from primitives at x = 100 so its colliders can
## never touch the home room. Everything with a StaticBody3D "Collider" is on physics
## layer 1, which PhotoCamera's occlusion ray checks. Wild creatures have no colliders.
##
## HOW TO ADD PROPS: add a line to TREES / BUSHES / ROCKS below.
## HOW TO ADD A SPAWN POINT: add a dictionary to SPAWN_POINTS. Its "habitat" must match a
## species' habitat (Forest, Meadow, Rocks).

const ORIGIN := Vector3(100.0, 0.0, 0.0)
const ZOOM_MIN := 9.0
const ZOOM_MAX := 20.0
const ZOOM_STEP := 1.0

const SPAWN_POINTS := [
	{"name": "forest_nook", "habitat": "Forest", "position": Vector3(-5.1, 0.0, -3.3)},
	{"name": "meadow", "habitat": "Meadow", "position": Vector3(4.0, 0.0, 3.0)},
	{"name": "rocky_outcrop", "habitat": "Rocks", "position": Vector3(6.4, 0.0, -5.4)},
]
const TREES := [  # [position, size]
	[Vector3(-7.0, 0.0, -6.5), 1.2],
	[Vector3(-5.0, 0.0, -8.4), 1.0],
	[Vector3(-8.6, 0.0, -3.2), 1.1],
	[Vector3(-2.5, 0.0, -8.6), 0.9],
	[Vector3(2.5, 0.0, -8.5), 1.1],
	[Vector3(8.6, 0.0, -8.4), 1.2],
	[Vector3(-8.8, 0.0, 3.5), 1.0],
]
const BUSHES := [
	Vector3(-4.3, 0.0, -2.5),  # hides the forest creature's spawn point
	Vector3(3.0, 0.0, -2.0),
	Vector3(7.2, 0.0, 1.8),
	Vector3(-3.2, 0.0, 3.2),
	Vector3(-6.4, 0.0, -0.6),
]
const ROCKS := [  # [position, size]
	[Vector3(5.2, 0.0, -4.4), 1.0],
	[Vector3(7.9, 0.0, -6.4), 1.4],
	[Vector3(8.2, 0.0, -3.6), 0.7],
	[Vector3(-1.5, 0.0, 7.4), 0.8],
]

var camera: Camera3D
var spawner: CreatureSpawner
## How far Camera Mode may drift from the starting view while outdoors.
var pan_limit: float = 13.0


func setup(wild_species: Array[CreatureSpecies]) -> void:
	position = ORIGIN
	_build_camera()
	_build_sun()
	_build_ground()
	_build_props()
	spawner = CreatureSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.setup(self, wild_species, SPAWN_POINTS)


## Shows or hides the whole area. While inactive nothing in it runs at all:
## no spawning, no wandering, no timers, and its colliders leave the physics world.
func set_active(active: bool) -> void:
	visible = active
	process_mode = Node.PROCESS_MODE_INHERIT if active else Node.PROCESS_MODE_DISABLED
	if active and camera != null:
		camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_mode != GameManager.Mode.OUTDOOR or camera == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = clampf(camera.size - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = clampf(camera.size + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


# ---------- Camera and light ----------

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "OutdoorCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17.0
	camera.near = 0.05
	camera.far = 100.0
	# The camera's own Environment overrides the home's WorldEnvironment.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.84, 0.97)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.98, 0.92)
	env.ambient_light_energy = 0.75
	camera.environment = env
	add_child(camera)  # must be in the tree before look_at_from_position
	camera.look_at_from_position(
		global_position + Vector3(10.0, 10.0, 10.0),
		global_position + Vector3(0.0, 0.5, 0.0),
		Vector3.UP
	)


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, 45.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.05
	add_child(sun)


# ---------- Ground ----------

func _build_ground() -> void:
	# Grass block on top of a soil block: top of the grass sits at y = 0.
	_add_box(self, Vector3(20.0, 0.4, 20.0), Vector3(0.0, -0.2, 0.0), Color(0.5, 0.77, 0.4))
	_add_box(self, Vector3(20.0, 0.8, 20.0), Vector3(0.0, -0.8, 0.0), Color(0.5, 0.38, 0.27))
	# Dirt path running toward the front corner (toward the camera, where "home" is).
	_add_box(self, Vector3(2.2, 0.03, 14.0), Vector3(0.0, 0.015, 3.0), Color(0.86, 0.74, 0.55))


# ---------- Props ----------

func _build_props() -> void:
	for entry in TREES:
		_add_tree(entry[0], entry[1])
	for spot in BUSHES:
		_add_bush(spot)
	for entry in ROCKS:
		_add_rock(entry[0], entry[1])
	_add_flowers(Vector3(4.0, 0.0, 3.0))
	_add_signpost(Vector3(1.9, 0.0, 7.6))


func _add_tree(spot: Vector3, size: float) -> void:
	var root := Node3D.new()
	root.name = "Tree"
	root.position = spot
	add_child(root)
	_add_cylinder(root, 0.22 * size, 0.32 * size, 2.2 * size, Vector3(0.0, 1.1 * size, 0.0), Color(0.45, 0.32, 0.22))
	_add_sphere(root, 1.3 * size, Vector3(0.0, 2.7 * size, 0.0), Vector3(1.0, 0.9, 1.0), Color(0.2, 0.55, 0.32))
	_add_sphere(root, 0.9 * size, Vector3(0.7 * size, 2.2 * size, 0.3 * size), Vector3.ONE, Color(0.25, 0.62, 0.36))
	_add_sphere(root, 0.95 * size, Vector3(-0.65 * size, 2.3 * size, -0.3 * size), Vector3.ONE, Color(0.17, 0.5, 0.3))
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.35 * size
	trunk.height = 2.2 * size
	_add_collider(root, trunk, Vector3(0.0, 1.1 * size, 0.0))  # trunk only; foliage doesn't block


func _add_bush(spot: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Bush"
	root.position = spot
	add_child(root)
	_add_sphere(root, 0.8, Vector3(0.0, 0.55, 0.0), Vector3(1.0, 0.75, 1.0), Color(0.28, 0.62, 0.3))
	_add_sphere(root, 0.5, Vector3(0.5, 0.45, 0.3), Vector3.ONE, Color(0.33, 0.68, 0.34))
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	_add_collider(root, shape, Vector3(0.0, 0.55, 0.0))


func _add_rock(spot: Vector3, size: float) -> void:
	var root := Node3D.new()
	root.name = "Rock"
	root.position = spot
	add_child(root)
	_add_sphere(root, 0.8 * size, Vector3(0.0, 0.5 * size, 0.0), Vector3(1.0, 0.7, 0.85), Color(0.62, 0.62, 0.66))
	_add_sphere(root, 0.45 * size, Vector3(0.6 * size, 0.3 * size, 0.2 * size), Vector3(1.0, 0.7, 1.0), Color(0.7, 0.7, 0.74))
	var shape := SphereShape3D.new()
	shape.radius = 0.8 * size
	_add_collider(root, shape, Vector3(0.0, 0.5 * size, 0.0))


## Small colored dots scattered around a point. A fixed seed keeps them in the same places every run.
func _add_flowers(center: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var palette := [Color(1.0, 0.85, 0.3), Color(1.0, 0.55, 0.65), Color(0.95, 0.95, 1.0), Color(0.75, 0.6, 1.0)]
	var root := Node3D.new()
	root.name = "Flowers"
	root.position = center
	add_child(root)
	for i in 18:
		var spot := Vector3(rng.randf_range(-3.0, 3.0), 0.09, rng.randf_range(-3.0, 3.0))
		_add_sphere(root, 0.09, spot, Vector3.ONE, palette[rng.randi() % palette.size()])


## Decoration only: marks where the path leads home. Going home uses the Go Home button.
func _add_signpost(spot: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Signpost"
	root.position = spot
	add_child(root)
	_add_cylinder(root, 0.06, 0.06, 1.4, Vector3(0.0, 0.7, 0.0), Color(0.5, 0.36, 0.25))
	_add_box(root, Vector3(0.9, 0.35, 0.08), Vector3(0.0, 1.3, 0.0), Color(0.9, 0.78, 0.55))
	var label := Label3D.new()
	label.text = "Home"
	label.font_size = 48
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.3, 0.2, 0.12)
	label.position = Vector3(0.0, 1.3, 0.1)
	root.add_child(label)


# ---------- Primitive helpers ----------

func _add_collider(parent: Node3D, shape: Shape3D, local_pos: Vector3) -> void:
	var body := StaticBody3D.new()  # collision layer 1 by default
	body.name = "Collider"
	body.position = local_pos
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	return material


func _add_box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)


func _add_sphere(parent: Node3D, radius: float, pos: Vector3, scl: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scl
	parent.add_child(instance)


func _add_cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.material = _material(color)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = pos
	parent.add_child(instance)
