class_name WildCreature
extends Node3D

## A wild creature outdoors. Model, behavior and rules all come from its CreatureSpecies.
##
## STATES:  IDLE -> (WANDER | LOOK_AROUND | PLAY) -> IDLE ...
##          HAPPY after a photo, LEAVING when its stay time runs out
##          (or after a photo, for Shy species).
##
## HOW TO ADD A BEHAVIOR:
##   1. Add a name to State.            2. Handle it in _process().
##   3. Start it in _set_state().       4. Give it a pose in get_pose().
##   5. Trigger it in _choose_next_state().
##
## PHOTO-SUBJECT INTERFACE (used by PhotoCamera):
##   get_species(), get_stats(), get_pose(), get_focus_point(),
##   get_subject_height(), get_subject_radius(), react_to_photo()

signal left(creature: Node3D)

enum State { IDLE, WANDER, LOOK_AROUND, PLAY, HAPPY, LEAVING }

const SUBJECT_GROUP := &"photo_subjects"
const MAP_LIMIT := 8.5          ## creatures never wander farther than this from the center
const APPEAR_SECONDS := 0.6
const LEAVE_SECONDS := 0.7

var species: CreatureSpecies
var state: State = State.IDLE

var _origin := Vector3.ZERO     ## spawn point (local to the outdoor area)
var _target := Vector3.ZERO
var _state_timer := 0.0
var _stay_left := 0.0
var _age := 0.0
var _leave_time := 0.0
var _leave_after_happy := false
var _clock := 0.0
var _visual: Node3D


func setup(p_species: CreatureSpecies, p_origin: Vector3) -> void:
	species = p_species
	_origin = p_origin
	position = p_origin
	_clock = randf() * 10.0
	_stay_left = randf_range(species.stay_time_min, species.stay_time_max)
	_build_model()
	rotation.y = randf() * TAU
	_set_state(State.IDLE)
	add_to_group(SUBJECT_GROUP)


# ---------- Photo-subject interface ----------

func get_species() -> CreatureSpecies:
	return species


## Wild creatures have no care stats; PhotoCamera uses neutral mood and bond.
func get_stats() -> CreatureStats:
	return null


func get_pose() -> Dictionary:
	match state:
		State.HAPPY:
			return {"name": "Happy hop", "value": 1.0}
		State.PLAY:
			return {"name": "Playing", "value": 0.9}
		State.LOOK_AROUND:
			return {"name": "Curious look", "value": 0.7}
		State.WANDER:
			return {"name": "Strolling", "value": 0.55}
		State.LEAVING:
			return {"name": "Vanishing", "value": 0.3}
	return {"name": "Sitting pretty", "value": 0.5}


func get_focus_point() -> Vector3:
	return global_position + Vector3(0.0, 0.6 * species.body_scale, 0.0)


func get_subject_height() -> float:
	return 1.3 * species.body_scale


func get_subject_radius() -> float:
	return 0.55 * species.body_scale


## Called after a valid photo was taken of this creature.
func react_to_photo() -> void:
	if state == State.LEAVING:
		return
	_leave_after_happy = (species.personality == "Shy")
	_set_state(State.HAPPY)


# ---------- State machine ----------

func _process(delta: float) -> void:
	if _visual == null:
		return
	_clock += delta
	_age += delta
	var base := Vector3.ONE * (species.body_scale * _get_presence())
	_visual.scale = base

	if state != State.LEAVING:
		_stay_left -= delta
		if _stay_left <= 0.0:
			_set_state(State.LEAVING)

	match state:
		State.IDLE:
			_visual.scale = base * Vector3(1.0, 1.0 + sin(_clock * 3.0) * 0.03, 1.0)
			_state_timer -= delta
			if _state_timer <= 0.0:
				_choose_next_state()
		State.WANDER:
			if _walk_toward_target(delta):
				_set_state(State.IDLE)
		State.LOOK_AROUND:
			_visual.rotation.y = sin(_clock * 3.0) * 0.9
			_visual.rotation.z = sin(_clock * 2.0) * 0.15
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.IDLE)
		State.PLAY:
			_visual.position.y = absf(sin(_clock * 10.0)) * 0.35
			_visual.rotation.y = sin(_clock * 5.0) * 0.6
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.IDLE)
		State.HAPPY:
			_visual.position.y = absf(sin(_clock * 12.0)) * 0.4
			_state_timer -= delta
			if _state_timer <= 0.0:
				_set_state(State.LEAVING if _leave_after_happy else State.IDLE)
		State.LEAVING:
			_leave_time += delta
			_visual.position.y = absf(sin(_clock * 14.0)) * 0.3
			if _leave_time >= LEAVE_SECONDS:
				set_process(false)
				left.emit(self)
				queue_free()


func _set_state(new_state: State) -> void:
	state = new_state
	# Reset visuals so no state leaves the model tilted.
	_visual.position = Vector3.ZERO
	_visual.rotation = Vector3.ZERO

	match new_state:
		State.IDLE:
			_state_timer = randf_range(1.2, 3.0)
		State.WANDER:
			_target = _pick_wander_target()
		State.LOOK_AROUND:
			_state_timer = 2.2
		State.PLAY:
			_state_timer = 2.4
		State.HAPPY:
			rotation.y = PI * 0.25  # face the camera
			_state_timer = 1.2
		State.LEAVING:
			_leave_time = 0.0


## Personality decides what a creature does besides walking around.
func _choose_next_state() -> void:
	if randf() < 0.4:
		match species.personality:
			"Curious":
				_set_state(State.LOOK_AROUND)
				return
			"Playful":
				_set_state(State.PLAY)
				return
	_set_state(State.WANDER)


func _pick_wander_target() -> Vector3:
	var angle := randf() * TAU
	var distance := randf_range(0.8, maxf(species.wander_radius, 1.0))
	var point := _origin + Vector3(cos(angle), 0.0, sin(angle)) * distance
	point.x = clampf(point.x, -MAP_LIMIT, MAP_LIMIT)
	point.z = clampf(point.z, -MAP_LIMIT, MAP_LIMIT)
	return point


## Moves toward _target. Returns true when it has arrived.
func _walk_toward_target(delta: float) -> bool:
	var offset := _target - position
	offset.y = 0.0
	var distance := offset.length()
	if distance < 0.08:
		return true
	var direction := offset / distance
	position += direction * minf(species.move_speed * delta, distance)
	rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 8.0 * delta)
	_visual.position.y = absf(sin(_clock * 8.0)) * 0.12  # little hops
	return false


## 0..1 size multiplier: pops in when spawned and shrinks away when leaving.
## Never exactly 0, because a zero scale makes Godot complain about the transform.
func _get_presence() -> float:
	var appear := clampf(_age / APPEAR_SECONDS, 0.0, 1.0)
	var vanish := 1.0 - clampf(_leave_time / LEAVE_SECONDS, 0.0, 1.0)
	return maxf(appear * vanish, 0.02)


# ---------- Placeholder models ----------

func _build_model() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var body := species.body_color
	var accent := species.accent_color
	var blush := Color(1.0, 0.62, 0.68)

	_add_sphere("Body", 0.5, Vector3(0.0, 0.5, 0.0), Vector3(1.0, 0.9, 1.0), body)
	_add_sphere("CheekLeft", 0.08, Vector3(-0.3, 0.45, 0.4), Vector3(1.4, 0.8, 0.6), blush)
	_add_sphere("CheekRight", 0.08, Vector3(0.3, 0.45, 0.4), Vector3(1.4, 0.8, 0.6), blush)
	for side in [-1.0, 1.0]:
		_add_sphere("Eye", 0.1, Vector3(side * 0.18, 0.62, 0.42), Vector3.ONE, Color(0.1, 0.08, 0.12))
		_add_sphere("EyeShine", 0.035, Vector3(side * 0.18 + 0.03, 0.67, 0.5), Vector3.ONE, Color.WHITE)

	# Each style adds its own ears, tail and head decoration.
	match species.model_style:
		"Sprout":
			_add_sphere("Tail", 0.13, Vector3(0.0, 0.4, -0.5), Vector3.ONE, accent)
			_add_sphere("Stem", 0.05, Vector3(0.0, 1.0, 0.0), Vector3(1.0, 3.0, 1.0), accent)
			_add_sphere("LeafLeft", 0.2, Vector3(-0.2, 1.14, 0.0), Vector3(1.5, 0.25, 0.9), accent, Vector3(0.0, 0.0, -25.0))
			_add_sphere("LeafRight", 0.2, Vector3(0.2, 1.14, 0.0), Vector3(1.5, 0.25, 0.9), accent, Vector3(0.0, 0.0, 25.0))
		"Longear":
			_add_sphere("Tail", 0.18, Vector3(0.0, 0.4, -0.5), Vector3.ONE, Color.WHITE)
			_add_sphere("EarLeft", 0.13, Vector3(-0.2, 1.1, 0.0), Vector3(0.7, 3.2, 0.7), accent, Vector3(0.0, 0.0, 10.0))
			_add_sphere("EarRight", 0.13, Vector3(0.2, 1.1, 0.0), Vector3(0.7, 3.2, 0.7), accent, Vector3(0.0, 0.0, -10.0))
		"Crest":
			_add_sphere("Tail", 0.2, Vector3(0.0, 0.45, -0.55), Vector3.ONE, accent, Vector3.ZERO, true)
			_add_sphere("CrestMiddle", 0.14, Vector3(0.0, 1.02, 0.05), Vector3.ONE, accent, Vector3.ZERO, true)
			_add_sphere("CrestLeft", 0.09, Vector3(-0.2, 0.95, 0.0), Vector3.ONE, accent, Vector3.ZERO, true)
			_add_sphere("CrestRight", 0.09, Vector3(0.2, 0.95, 0.0), Vector3.ONE, accent, Vector3.ZERO, true)
		_:
			_add_sphere("Tail", 0.15, Vector3(0.0, 0.4, -0.5), Vector3.ONE, accent)
			_add_sphere("EarLeft", 0.16, Vector3(-0.28, 1.0, 0.0), Vector3(0.8, 1.4, 0.8), accent)
			_add_sphere("EarRight", 0.16, Vector3(0.28, 1.0, 0.0), Vector3(0.8, 1.4, 0.8), accent)


func _add_sphere(
	node_name: String, radius: float, pos: Vector3, scl: Vector3, color: Color,
	rot_degrees := Vector3.ZERO, glow := false
) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.9
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.rotation_degrees = rot_degrees
	instance.scale = scl
	_visual.add_child(instance)
