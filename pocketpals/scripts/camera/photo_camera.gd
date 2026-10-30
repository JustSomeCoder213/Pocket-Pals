class_name PhotoCamera
extends Node

## Camera Mode logic. It borrows an orthographic Camera3D (the home's or the outdoor one):
##   enter() saves the view and centers on a creature,
##   exit()  restores the saved view.
##
## Aiming pans the camera inside its own view plane (the camera never rotates),
## which keeps the 2.5D look intact. Zoom changes Camera3D.size.
##
## Photos are EVALUATED, not saved as image files (see the Phase 3 notes).
## Only subjects that are visible in the tree can be photographed, so creatures in the
## location you are not standing in are ignored.

## Emitted for every photo attempt. result["valid"] says whether it counts.
signal photo_taken(result: Dictionary)
## Emitted only when the framing text changes (so the HUD isn't spammed).
signal framing_changed(text: String, in_frame: bool)
## Zoom shown to the player: 1.0 (fully zoomed out) up to ~7.0.
signal zoom_changed(multiplier: float)

const SUBJECT_GROUP := &"photo_subjects"
## Physics layer 1 is "world". Anything with a collider on layer 1 can hide a creature.
const OCCLUDER_MASK := 1

const ZOOM_MIN := 2.0   ## smallest camera.size (most zoomed in)
const ZOOM_MAX := 14.0  ## largest camera.size (most zoomed out)
const ZOOM_FACTOR := 0.88
const START_ZOOM := 6.0
const DEFAULT_PAN_LIMIT := 7.0  ## how far the view may drift from the starting view
const KEY_PAN_SPEED := 8.0      ## world units per second at camera.size 11
const COOLDOWN := 1.0           ## seconds between valid photos
const MIN_VISIBLE_FRACTION := 0.6

@export var mouse_sensitivity: float = 1.5

var active: bool = false
## While true, aiming, zooming and shooting are ignored (e.g. result panel open).
var input_blocked: bool = false:
	set = set_input_blocked

var _camera: Camera3D
var _pan_limit: float = DEFAULT_PAN_LIMIT
var _home_position := Vector3.ZERO
var _saved_size := 11.0
var _cooldown := 0.0
var _aiming := false
var _last_framing_text := ""
var _last_subject: Node3D
var _last_centered_id: int = 0


func setup(camera: Camera3D) -> void:
	set_camera(camera)


## Chooses which Camera3D Camera Mode drives. Ignored while Camera Mode is active.
func set_camera(camera: Camera3D, pan_limit: float = DEFAULT_PAN_LIMIT) -> void:
	if active:
		return
	_camera = camera
	_pan_limit = pan_limit


# ---------- Mode entry / exit ----------

func enter() -> void:
	if _camera == null:
		return
	_home_position = _camera.global_position
	_saved_size = _camera.size
	_camera.size = START_ZOOM
	_cooldown = 0.0
	_last_framing_text = ""
	_last_centered_id = 0
	active = true
	center_on_subject()
	zoom_changed.emit(ZOOM_MAX / _camera.size)


func exit() -> void:
	_set_aiming(false)
	active = false
	input_blocked = false
	if _camera == null:
		return
	_camera.global_position = _home_position
	_camera.size = _saved_size


func set_input_blocked(value: bool) -> void:
	input_blocked = value
	if value:
		_set_aiming(false)


# ---------- Input and per-frame update ----------

func _unhandled_input(event: InputEvent) -> void:
	if not active or input_blocked or _camera == null:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_set_aiming(button.pressed)
		elif not button.pressed:
			return
		elif button.button_index == MOUSE_BUTTON_LEFT:
			take_photo()
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(ZOOM_FACTOR)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(1.0 / ZOOM_FACTOR)
	elif event is InputEventMouseMotion and _aiming:
		var motion := event as InputEventMouseMotion
		var units_per_pixel := _camera.size / _camera.get_viewport().get_visible_rect().size.y
		_pan(Vector2(motion.relative.x, -motion.relative.y) * units_per_pixel * mouse_sensitivity)
	elif event.is_action_pressed("take_photo"):
		take_photo()


func _process(delta: float) -> void:
	if not active or _camera == null:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not input_blocked:
		_pan_with_keyboard(delta)
	_update_framing()


# ---------- Public actions ----------

## Evaluates the current view and emits photo_taken (valid or not).
func take_photo() -> void:
	if not active or input_blocked or _camera == null:
		return
	if _cooldown > 0.0:
		return
	var result := _build_result()
	_cooldown = COOLDOWN if result["valid"] else 0.3
	if result["valid"] and is_instance_valid(_last_subject):
		_last_subject.react_to_photo()
	photo_taken.emit(result)


## Moves the view so the creature nearest to the middle of the screen is centered.
func center_on_subject() -> void:
	if _camera == null:
		return
	var best: Node3D = null
	var best_distance := INF
	for subject in _get_visible_subjects():
		var distance := _off_axis_offset(subject).length()
		if distance < best_distance:
			best_distance = distance
			best = subject
	if best != null:
		_center_on(best)


## Find Creature button: jumps to the next visible creature, cycling through all of them.
func find_next_subject() -> void:
	if _camera == null:
		return
	var subjects := _get_visible_subjects()
	if subjects.is_empty():
		return
	subjects.sort_custom(func(a: Node3D, b: Node3D) -> bool: return a.get_instance_id() < b.get_instance_id())
	var next_index := 0
	for i in subjects.size():
		if subjects[i].get_instance_id() == _last_centered_id:
			next_index = (i + 1) % subjects.size()
			break
	_center_on(subjects[next_index])


# ---------- Aiming ----------

func _set_aiming(value: bool) -> void:
	if _aiming == value:
		return
	_aiming = value
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if value else Input.MOUSE_MODE_VISIBLE


func _zoom(factor: float) -> void:
	_camera.size = clampf(_camera.size * factor, ZOOM_MIN, ZOOM_MAX)
	zoom_changed.emit(ZOOM_MAX / _camera.size)


func _pan_with_keyboard(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y -= 1.0
	if direction != Vector2.ZERO:
		_pan(direction.normalized() * KEY_PAN_SPEED * (_camera.size / 11.0) * delta)


## amount.x moves the view right, amount.y moves it up (in world units).
func _pan(amount: Vector2) -> void:
	var cam_basis := _camera.global_transform.basis
	_move_camera_to(_camera.global_position + cam_basis.x * amount.x + cam_basis.y * amount.y)


func _move_camera_to(target: Vector3) -> void:
	var offset := target - _home_position
	if offset.length() > _pan_limit:
		offset = offset.normalized() * _pan_limit
	_camera.global_position = _home_position + offset


func _center_on(subject: Node3D) -> void:
	_last_centered_id = subject.get_instance_id()
	_move_camera_to(_camera.global_position + _off_axis_offset(subject))


## The part of the vector camera -> subject that is perpendicular to the view axis.
## Moving the camera by this amount puts the subject in the middle of the screen.
func _off_axis_offset(subject: Node3D) -> Vector3:
	var forward := _camera.global_transform.basis.z  # unit vector along the view axis
	var to_point: Vector3 = subject.get_focus_point() - _camera.global_position
	return to_point - forward * to_point.dot(forward)


## Every subject that is currently visible (creatures in a hidden location are skipped).
func _get_visible_subjects() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group(SUBJECT_GROUP):
		var subject := node as Node3D
		if subject != null and subject.is_visible_in_tree():
			result.append(subject)
	return result


# ---------- Subject detection ----------

## Measures how a subject looks through the camera right now.
func _analyze(subject: Node3D) -> Dictionary:
	var info := {
		"center_in_frame": false,
		"center_offset": INF,
		"visible_fraction": 0.0,
		"size_fraction": 0.0,
		"occluded": false,
	}
	var focus: Vector3 = subject.get_focus_point()
	if _camera.is_position_behind(focus):
		return info

	var rect := _camera.get_viewport().get_visible_rect()
	var screen_center := rect.size * 0.5
	var height: float = subject.get_subject_height()
	var radius: float = subject.get_subject_radius()
	var cam_basis := _camera.global_transform.basis

	# Five sample points: how many of them are on screen = how much is "visible".
	var points: Array[Vector3] = [
		focus,
		focus + cam_basis.y * height * 0.5,
		focus - cam_basis.y * height * 0.5,
		focus + cam_basis.x * radius,
		focus - cam_basis.x * radius,
	]
	var inside := 0
	for point in points:
		if not _camera.is_position_behind(point) and rect.has_point(_camera.unproject_position(point)):
			inside += 1

	var focus_screen := _camera.unproject_position(focus)
	info["center_in_frame"] = rect.has_point(focus_screen)
	info["center_offset"] = focus_screen.distance_to(screen_center) / (rect.size.y * 0.5)
	info["visible_fraction"] = float(inside) / float(points.size())
	info["size_fraction"] = height / _camera.size  # orthographic: size = visible world height
	info["occluded"] = _is_occluded(focus)
	return info


## Casts a ray from the camera to the subject. Anything solid on layer 1 in between hides it.
func _is_occluded(target: Vector3) -> bool:
	var space := _camera.get_world_3d().direct_space_state
	var from := _camera.project_ray_origin(_camera.unproject_position(target))
	var query := PhysicsRayQueryParameters3D.create(from, target, OCCLUDER_MASK)
	return not space.intersect_ray(query).is_empty()


## The subject whose center is closest to the reticle, among those with their center on screen.
## Returns {} or {"subject": Node3D, "analysis": Dictionary}.
func _find_best_subject() -> Dictionary:
	var best := {}
	var best_offset := INF
	for subject in _get_visible_subjects():
		var info := _analyze(subject)
		if not info["center_in_frame"]:
			continue
		var offset: float = info["center_offset"]
		if offset < best_offset:
			best_offset = offset
			best = {"subject": subject, "analysis": info}
	return best


func _update_framing() -> void:
	var best := _find_best_subject()
	var text := "No creature in frame"
	var ok := false
	if not best.is_empty():
		var subject: Node3D = best["subject"]
		var info: Dictionary = best["analysis"]
		var species: CreatureSpecies = subject.get_species()
		var visible_fraction: float = info["visible_fraction"]
		var size_fraction: float = info["size_fraction"]
		if info["occluded"]:
			text = "%s is hidden behind something" % species.display_name
		elif visible_fraction < MIN_VISIBLE_FRACTION:
			text = "%s is partly out of frame" % species.display_name
		else:
			ok = true
			text = "%s in frame" % species.display_name
			if size_fraction < 0.2:
				text += " - zoom in"
			elif size_fraction > 0.65:
				text += " - zoom out"
	if text != _last_framing_text:
		_last_framing_text = text
		framing_changed.emit(text, ok)


# ---------- Building the result ----------

func _build_result() -> Dictionary:
	_last_subject = null
	var best := _find_best_subject()
	if best.is_empty():
		return _invalid("No creature in frame. Aim at a creature and try again.")

	var subject: Node3D = best["subject"]
	var info: Dictionary = best["analysis"]
	var species: CreatureSpecies = subject.get_species()
	var visible_fraction: float = info["visible_fraction"]

	if info["occluded"]:
		return _invalid("Something is blocking the view of %s." % species.display_name)
	if visible_fraction < MIN_VISIBLE_FRACTION:
		return _invalid("%s is only partly in frame." % species.display_name)

	# Wild creatures have no stats: use neutral mood and bond.
	var happiness_ratio := 0.5
	var bond_level := 1
	var stats: CreatureStats = subject.get_stats()
	if stats != null:
		happiness_ratio = stats.happiness / stats.max_happiness
		bond_level = stats.get_bond_level()

	var pose: Dictionary = subject.get_pose()
	var scored := PhotoScoring.evaluate(
		visible_fraction,
		info["size_fraction"],
		info["center_offset"],
		pose["value"],
		happiness_ratio,
		bond_level,
		species
	)

	_last_subject = subject
	return {
		"valid": true,
		"message": "",
		"species_id": species.species_id,
		"species_name": species.display_name,
		"pose_name": pose["name"],
		"score": scored["score"],
		"coins": scored["coins"],
		"rating": scored["rating"],
		"breakdown": scored["breakdown"],
		# DiscoverySystem.register_photo() decides these two (called from main.gd).
		"is_new_discovery": false,
		"discovery_bonus": 0,
	}


func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "message": reason}
