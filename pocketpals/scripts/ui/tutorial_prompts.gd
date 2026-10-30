class_name TutorialPrompts
extends CanvasLayer

## Step-by-step objectives. Each step finishes when the player does the matching thing,
## in any order. Things already done are skipped automatically.
##
## HOW TO ADD A STEP: add an entry to STEPS with a unique "id", then call
## _complete("<id>") from the signal that should finish it (see setup()).

## Emitted when the current step changes (main.gd saves the number).
signal step_changed(step: int)
signal finished

const STEPS := [
	{"id": "feed", "text": "Feed {name}: click Feed... and pick a food."},
	{"id": "pet", "text": "Pet {name} to build your bond."},
	{"id": "photo", "text": "Take a photo of {name}: press C, put {name} in the middle of the reticle, then click or press Space. Photos earn coins!"},
	{"id": "shop", "text": "Spend your coins: open the Shop (B) and buy something. Food is cheap."},
	{"id": "outdoors", "text": "Time to explore! Press O (or click Go Outdoors) to visit the meadow."},
	{"id": "discover", "text": "Wild creatures hide outdoors. Press C and photograph one to discover it. The first photo of each species pays a bonus!"},
]
const FINISH_TEXT := "You're all set! J opens your collection and Esc opens the menu. Your progress saves automatically. Have fun!"
const FINISH_SECONDS := 9.0

var _creature_name := ""
var _step := 0
var _active := false
var _done: Dictionary = {}  # event id (String) -> true

var _panel: PanelContainer
var _title_label: Label
var _text_label: Label
var _skip_button: Button


func _ready() -> void:
	_build_ui()
	GameManager.mode_changed.connect(_on_mode_changed)
	_update_visibility()


## Called by main.gd after this layer is in the tree.
func setup(care: CareSystem, photo_camera: PhotoCamera, economy: Economy, discovery: DiscoverySystem, creature_name: String) -> void:
	_creature_name = creature_name
	care.action_done.connect(_on_care_action)
	photo_camera.photo_taken.connect(_on_photo_taken)
	economy.purchased.connect(_on_purchased)
	discovery.species_discovered.connect(_on_species_discovered)


## step = 0 for a new game, or the saved step. A step past the end means "finished".
func start(step: int) -> void:
	_step = clampi(step, 0, STEPS.size())
	_active = _step < STEPS.size()
	_refresh()
	_update_visibility()


func get_step() -> int:
	return _step


# ---------- Events ----------

func _on_care_action(action: StringName) -> void:
	if action == &"feed":
		_complete("feed")
	elif action == &"pet":
		_complete("pet")


func _on_photo_taken(result: Dictionary) -> void:
	if result["valid"]:
		_complete("photo")


func _on_purchased(_item_id: String) -> void:
	_complete("shop")


func _on_species_discovered(_species_id: String) -> void:
	_complete("discover")


func _on_mode_changed(new_mode: GameManager.Mode) -> void:
	if new_mode == GameManager.Mode.OUTDOOR:
		_complete("outdoors")
	_update_visibility()


func _complete(event_id: String) -> void:
	_done[event_id] = true
	if not _active:
		return
	var before := _step
	while _step < STEPS.size() and _done.get(STEPS[_step]["id"], false):
		_step += 1
	if _step == before:
		return
	step_changed.emit(_step)
	if _step >= STEPS.size():
		_show_finish()
	else:
		_refresh()


func _on_skip_pressed() -> void:
	_step = STEPS.size()
	_active = false
	step_changed.emit(_step)
	_update_visibility()
	finished.emit()


# ---------- Display ----------

func _refresh() -> void:
	if _step >= STEPS.size():
		return
	_title_label.text = "Getting started  (%d / %d)" % [_step + 1, STEPS.size()]
	_text_label.text = str(STEPS[_step]["text"]).replace("{name}", _creature_name)
	_skip_button.visible = true


func _show_finish() -> void:
	_title_label.text = "Tutorial complete!"
	_text_label.text = FINISH_TEXT
	_skip_button.visible = false
	_update_visibility()
	await get_tree().create_timer(FINISH_SECONDS).timeout
	_active = false
	_update_visibility()
	finished.emit()


## Only shown while at home or outdoors (Camera Mode has its own HUD).
func _update_visibility() -> void:
	var mode := GameManager.current_mode
	visible = _active and (mode == GameManager.Mode.HOME or mode == GameManager.Mode.OUTDOOR)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "TutorialPanel"
	_panel.position = Vector2(16, 250)  # just under the stats panel
	_panel.custom_minimum_size = Vector2(380, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	column.add_child(_title_label)

	_text_label = Label.new()
	_text_label.add_theme_font_size_override("font_size", 17)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(350, 0)
	column.add_child(_text_label)

	_skip_button = Button.new()
	_skip_button.text = "Skip tutorial"
	_skip_button.custom_minimum_size = Vector2(0, 32)
	_skip_button.add_theme_font_size_override("font_size", 15)
	_skip_button.focus_mode = Control.FOCUS_NONE
	_skip_button.pressed.connect(_on_skip_pressed)
	column.add_child(_skip_button)
