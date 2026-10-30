extends Node3D

## Placeholder creature built from spheres, driven by a small finite-state
## machine (FSM).
##
## HOW TO ADD A NEW BEHAVIOR:
##   1. Add a name to the State enum.
##   2. Add a branch in _process() for what it does each frame.
##   3. Add a branch in _set_state() for what happens when it starts.
##   4. Add a command_xxx() function that other scripts can call.
##   5. Give it a pose in get_pose() so photos of it are scored.
##
## PHOTO-SUBJECT INTERFACE (used by PhotoCamera):
##   get_species(), get_stats(), get_pose(), get_focus_point(),
##   get_subject_height(), get_subject_radius(), react_to_photo()

enum State { IDLE, WANDER, WALK_TO, EATING, PLAYING, SLEEPING, HAPPY }

const SUBJECT_GROUP := &"photo_subjects"

var species: CreatureSpecies
var stats: CreatureStats
var state: State = State.IDLE

var _bounds := Rect2(-2.0, -2.0, 4.0, 5.0)  # x, z, width, depth of the wander area
var _spots: Dictionary = {}  # named positions supplied by the home
var _target := Vector3.ZERO
var _arrival_state: State = State.IDLE  # what to do after WALK_TO finishes
var _state_timer := 0.0
var _clock := 0.0
var _visual: Node3D  # everything visible; we hop/squash this node
var _zzz: Label3D


func setup(p_species: CreatureSpecies, p_bounds: Rect2, p_spots: Dictionary, p_stats: CreatureStats) -> void:
	species = p_species
	_bounds = p_bounds
	_spots = p_spots
	stats = p_stats
	_build_model()
	_set_state(State.IDLE)
	add_to_group(SUBJECT_GROUP)


# ---------- Commands (called by home_controller) ----------

func command_eat() -> void:
	_go_to(_spots["food"], State.EATING)


func command_play() -> void:
	_go_to(_spots["toy"], State.PLAYING)


func command_sleep() -> void:
	if _is_sleeping_or_heading_to_bed():
		return
	_go_to(_spots["bed_approach"], State.SLEEPING)


func command_wake() -> void:
	if _is_sleeping_or_heading_to_bed():
		_set_state(State.IDLE)


func react_happy() -> void:
	if _is_sleeping_or_heading_to_bed():
		return
	_set_state(State.HAPPY)


# ---------- Photo-subject interface ----------

func get_species() -> CreatureSpecies:
	return species


func get_stats() -> CreatureStats:
	return stats


## Name and score value (0.0 - 1.0) of what the creature is doing right now.
func get_pose() -> Dictionary:
	match state:
		State.HAPPY:
			return {"name": "Happy hop", "value": 1.0}
		State.PLAYING:
			return {"name": "Playing", "value": 0.9}
		State.SLEEPING:
			return {"name": "Sleeping", "value": 0.75}
		State.EATING:
			return {"name": "Snacking", "value": 0.7}
		State.WANDER:
			return {"name": "Strolling", "value": 0.55}
		State.WALK_TO:
			return {"name": "On the move", "value": 0.45}
	return {"name": "Sitting pretty", "value": 0.5}


## World position of the middle of the body (what the camera aims at).
func get_focus_point() -> Vector3:
	return global_position + Vector3(0.0, 0.6 * species.body_scale, 0.0)


func get_subject_height() -> float:
	return 1.3 * species.body_scale


func get_subject_radius() -> float:
	return 0.55 * species.body_scale


## Called after a valid photo was taken of this creature.
func react_to_photo() -> void:
	react_happy()


# ---------- State machine ----------

func _process(delta: float) -> void:
	if _visual == null:
		return
	_clock += delta

	match state:
		State.IDLE:
			_visual.scale = Vector3(1.0, 1.0 + sin(_clock * 3.0) * 0.03, 1.0) * species.body_scale
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.WANDER)
		State.WANDER:
			if _walk_toward_target(delta):
				_set_state(State.IDLE)
		State.WALK_TO:
			if _walk_toward_target(delta):
				_set_state(_arrival_state)
		State.EATING:
			_visual.rotation.x = 0.35 + sin(_clock * 12.0) * 0.15  # nodding at the bowl
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.IDLE)
		State.PLAYING:
			_visual.position.y = absf(sin(_clock * 10.0)) * 0.35
			_visual.rotation.y = sin(_clock * 5.0) * 0.6
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.IDLE)
		State.SLEEPING:
			_visual.scale = Vector3(1.1, 0.65 + sin(_clock * 1.5) * 0.03, 1.1) * species.body_scale
			_zzz.position.y = 1.5 + sin(_clock * 2.0) * 0.1
		State.HAPPY:
			_visual.position.y = absf(sin(_clock * 12.0)) * 0.4
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.IDLE)


func _set_state(new_state: State) -> void:
	var previous := state
	state = new_state

	# Stepping off the bed when leaving SLEEPING.
	if previous == State.SLEEPING and new_state != State.SLEEPING:
		position = _spots["bed_approach"]

	# Reset visuals so no state leaves the model squashed or tilted.
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3.ZERO
	_visual.scale = Vector3.ONE * species.body_scale
	_zzz.visible = false

	match new_state:
		State.IDLE:
			_state_timer = randf_range(1.5, 3.5)
		State.WANDER:
			_target = Vector3(
				randf_range(_bounds.position.x, _bounds.end.x),
				0.0,
				randf_range(_bounds.position.y, _bounds.end.y)
			)
		State.WALK_TO:
			pass  # _target and _arrival_state were set by _go_to()
		State.EATING:
			_look_at_xz(_spots["food_target"])
			_state_timer = 2.5
		State.PLAYING:
			_look_at_xz(_spots["toy_target"])
			_state_timer = 3.5
		State.SLEEPING:
			position = _spots["bed_top"]
			rotation.y = PI * 0.25  # face the camera
			_zzz.visible = true
		State.HAPPY:
			rotation.y = PI * 0.25
			_state_timer = 1.2


func _go_to(target: Vector3, arrival_state: State) -> void:
	_target = target
	_arrival_state = arrival_state
	_set_state(State.WALK_TO)


## Moves toward _target. Returns true when it has arrived.
func _walk_toward_target(delta: float) -> bool:
	var offset := _target - position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.08:
		return true
	var direction := offset / distance
	position += direction * minf(_get_speed() * delta, distance)
	# +Z is the creature's "front".
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 8.0 * delta)
	_visual.position.y = absf(sin(_clock * 8.0)) * 0.12  # little hops
	return false


func _get_speed() -> float:
	var speed := species.move_speed
	if stats != null:
		if stats.hunger < stats.max_hunger * 0.25 or stats.energy < stats.max_energy * 0.25:
			speed *= 0.6  # hungry or tired creatures drag their feet
	return speed


func _look_at_xz(point: Vector3) -> void:
	var offset := point - position
	rotation.y = atan2(offset.x, offset.z)


func _is_sleeping_or_heading_to_bed() -> bool:
	return state == State.SLEEPING or (state == State.WALK_TO and _arrival_state == State.SLEEPING)


# ---------- Placeholder model ----------

func _build_model() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	_visual.scale = Vector3.ONE * species.body_scale
	add_child(_visual)

	_add_sphere("Body", 0.5, Vector3(0.0, 0.5, 0.0), Vector3(1.0, 0.9, 1.0), species.body_color)
	_add_sphere("EarLeft", 0.16, Vector3(-0.28, 1.0, 0.0), Vector3(0.8, 1.4, 0.8), species.accent_color)
	_add_sphere("EarRight", 0.16, Vector3(0.28, 1.0, 0.0), Vector3(0.8, 1.4, 0.8), species.accent_color)
	_add_sphere("Tail", 0.15, Vector3(0.0, 0.4, -0.5), Vector3.ONE, species.accent_color)
	_add_sphere("CheekLeft", 0.08, Vector3(-0.3, 0.45, 0.4), Vector3(1.4, 0.8, 0.6), species.accent_color)
	_add_sphere("CheekRight", 0.08, Vector3(0.3, 0.45, 0.4), Vector3(1.4, 0.8, 0.6), species.accent_color)
	for side in [-1.0, 1.0]:
		_add_sphere("Eye", 0.1, Vector3(side * 0.18, 0.62, 0.42), Vector3.ONE, Color(0.1, 0.08, 0.12))
		_add_sphere("EyeShine", 0.035, Vector3(side * 0.18 + 0.03, 0.67, 0.5), Vector3.ONE, Color.WHITE)

	# "Zzz" text shown while sleeping. Child of the creature, not of _visual,
	# so it isn't squashed with the body.
	_zzz = Label3D.new()
	_zzz.name = "Zzz"
	_zzz.text = "Z z z"
	_zzz.font_size = 64
	_zzz.pixel_size = 0.01
	_zzz.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_zzz.no_depth_test = true
	_zzz.modulate = Color(0.3, 0.4, 0.8)
	_zzz.position = Vector3(0.0, 1.5, 0.0)
	_zzz.visible = false
	add_child(_zzz)


func _add_sphere(node_name: String, radius: float, pos: Vector3, scl: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.scale = scl
	_visual.add_child(instance)
