extends Node3D

## Builds the home room from primitive meshes (no external assets needed),
## connects the care system to the creature's animations, and shows the
## equipped bed, equipped toy and placed decorations.
##
## HOW TO ADD A DECORATION SLOT: add an entry to DECOR_SLOTS (slot name ->
## position), then give a decoration item decor_slot = "<that name>".

const CreatureScript := preload("res://scripts/creature/creature_controller.gd")

const ZOOM_MIN := 5.0
const ZOOM_MAX := 16.0
const ZOOM_STEP := 0.8

## Where each decoration slot sits in the room (floor top is y = 0).
const DECOR_SLOTS := {
	"rug": Vector3(0.0, 0.0, 0.5),
	"plant": Vector3(-4.2, 0.0, 0.5),
	"wall": Vector3(0.5, 2.4, -4.96),
	"lamp": Vector3(4.2, 0.0, -1.0),
}

var camera: Camera3D
var creature: Node3D

var _bed_mattress: MeshInstance3D
var _toy_ball: MeshInstance3D
var _decor_nodes: Dictionary = {}  # slot name -> Node3D


func setup(species: CreatureSpecies, care: CareSystem) -> void:
	_build_environment()
	_build_room()
	_build_camera()
	_spawn_creature(species, care)
	care.action_done.connect(_on_care_action)

	InventoryManager.bed_changed.connect(_apply_bed)
	InventoryManager.toy_changed.connect(_apply_toy)
	InventoryManager.decorations_changed.connect(_refresh_decorations)
	_apply_bed(InventoryManager.equipped_bed)
	_apply_toy(InventoryManager.equipped_toy)
	_refresh_decorations()


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.current_mode != GameManager.Mode.HOME or camera == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = clampf(camera.size - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = clampf(camera.size + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)


## Translates a care action into a creature animation/behavior.
func _on_care_action(action: StringName) -> void:
	if creature == null:
		return
	match action:
		&"feed":
			creature.command_eat()
		&"pet":
			creature.react_happy()
		&"play":
			creature.command_play()
		&"rest":
			creature.command_sleep()
		&"wake":
			creature.command_wake()


# ---------- Inventory-driven visuals ----------

func _apply_bed(bed_id: String) -> void:
	var bed := ItemDatabase.get_item(bed_id)
	if bed == null or _bed_mattress == null:
		return
	var mesh := _bed_mattress.mesh as BoxMesh
	var material := mesh.material as StandardMaterial3D
	material.albedo_color = bed.color


func _apply_toy(toy_id: String) -> void:
	var toy := ItemDatabase.get_item(toy_id)
	if toy == null or _toy_ball == null:
		return
	var mesh := _toy_ball.mesh as SphereMesh
	var material := mesh.material as StandardMaterial3D
	material.albedo_color = toy.color
	_toy_ball.scale = Vector3.ONE * toy.model_scale
	_toy_ball.position.y = 0.3 * toy.model_scale  # keep it resting on the floor


## Adds, swaps or removes decoration models so they match InventoryManager.
func _refresh_decorations() -> void:
	for slot in DECOR_SLOTS:
		var placed_id: String = InventoryManager.placed_decorations.get(slot, "")
		var current := _decor_nodes.get(slot) as Node3D
		if current != null and str(current.get_meta("item_id", "")) == placed_id:
			continue  # already showing the right thing
		if current != null:
			remove_child(current)
			current.queue_free()
			_decor_nodes.erase(slot)
		if placed_id == "":
			continue
		var item := ItemDatabase.get_item(placed_id)
		if item == null:
			continue
		var node := DecorationBuilder.build(item)
		node.name = "Decor_%s" % slot
		node.position = DECOR_SLOTS[slot]
		node.set_meta("item_id", placed_id)
		add_child(node)
		_decor_nodes[slot] = node


# ---------- Room construction ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.78, 0.9, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.96, 0.9)
	env.ambient_light_energy = 0.7
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-50.0, 45.0, 0.0)
	sun.shadow_enabled = true
	sun.light_energy = 1.0
	add_child(sun)


func _build_room() -> void:
	# Floor top surface sits at y = 0.
	_add_box("Floor", Vector3(10.0, 0.2, 10.0), Vector3(0.0, -0.1, 0.0), Color(0.88, 0.76, 0.6))
	# Two walls (back and left); the camera looks in over the open corner.
	_add_box("WallBack", Vector3(10.0, 4.0, 0.2), Vector3(0.0, 2.0, -5.1), Color(0.98, 0.93, 0.85))
	_add_box("WallLeft", Vector3(0.2, 4.0, 10.0), Vector3(-5.1, 2.0, 0.0), Color(0.95, 0.88, 0.8))
	# Bed (frame + mattress + pillow). Mattress top surface is at y = 0.545.
	_add_box("BedFrame", Vector3(2.0, 0.3, 1.4), Vector3(-3.6, 0.15, -3.8), Color(0.55, 0.38, 0.27))
	_bed_mattress = _add_box("BedMattress", Vector3(1.9, 0.25, 1.3), Vector3(-3.6, 0.42, -3.8), Color(0.6, 0.75, 0.95))
	_add_box("BedPillow", Vector3(0.5, 0.15, 0.9), Vector3(-4.3, 0.62, -3.8), Color.WHITE)
	# Food bowl (box stand-in).
	_add_box("FoodBowl", Vector3(0.6, 0.2, 0.6), Vector3(3.2, 0.1, -3.8), Color(0.9, 0.4, 0.35))
	_add_box("FoodInBowl", Vector3(0.4, 0.05, 0.4), Vector3(3.2, 0.21, -3.8), Color(0.55, 0.35, 0.2))
	# Toy ball (color and size are set by _apply_toy).
	_toy_ball = MeshInstance3D.new()
	_toy_ball.name = "ToyBall"
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	sphere.material = StandardMaterial3D.new()
	_toy_ball.mesh = sphere
	_toy_ball.position = Vector3(3.2, 0.3, 3.0)
	add_child(_toy_ball)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.name = "HomeCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.0
	camera.near = 0.05
	camera.far = 100.0
	add_child(camera)  # must be in the tree before look_at_from_position
	camera.look_at_from_position(Vector3(9.0, 9.0, 9.0), Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.current = true


func _spawn_creature(species: CreatureSpecies, care: CareSystem) -> void:
	creature = Node3D.new()
	creature.name = "Creature"
	creature.set_script(CreatureScript)
	add_child(creature)
	creature.position = Vector3(0.0, 0.0, 1.0)

	# Named places the creature can walk to. To add a new activity spot,
	# add an entry here and use it from a new command in creature_controller.gd.
	var spots := {
		"food": Vector3(3.2, 0.0, -2.9),          # where it stands to eat
		"food_target": Vector3(3.2, 0.0, -3.8),   # the bowl it looks at
		"toy": Vector3(2.2, 0.0, 3.0),             # where it stands to play
		"toy_target": Vector3(3.2, 0.0, 3.0),      # the ball it looks at
		"bed_approach": Vector3(-3.6, 0.0, -2.6),  # in front of the bed
		"bed_top": Vector3(-3.3, 0.55, -3.8),      # lying on the mattress
	}
	# Walkable area (x, z, width, depth) that avoids the bed and bowl.
	creature.setup(species, Rect2(-2.5, -2.0, 5.0, 5.0), spots, care.stats)


func _add_box(node_name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	add_child(instance)
	return instance
