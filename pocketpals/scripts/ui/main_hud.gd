extends CanvasLayer

## Main HUD. Built entirely in code from standard Control containers.
## It never polls other nodes for data: it listens to signals
## (GameManager, CareSystem, CreatureStats, InventoryManager).

## Emitted when the Camera button is pressed. main.gd switches the mode.
signal camera_requested
## Emitted when the Shop button is pressed. main.gd opens the shop.
signal shop_requested

const MODE_NAMES := {
	GameManager.Mode.INTRO: "Introduction",
	GameManager.Mode.HOME: "Home",
	GameManager.Mode.CAMERA: "Camera",
	GameManager.Mode.OUTDOOR: "Outdoors",
}

const HUNGER_COLOR := Color(0.96, 0.66, 0.26)
const HAPPINESS_COLOR := Color(1.0, 0.5, 0.7)
const ENERGY_COLOR := Color(0.35, 0.7, 0.95)
const BOND_COLOR := Color(0.7, 0.5, 0.95)
const MESSAGE_SECONDS := 4.0

var _care: CareSystem
var _species: CreatureSpecies

var _mode_label: Label
var _creature_label: Label
var _coins_label: Label
var _hint_label: Label
var _status_label: Label

var _stats_panel: Control
var _portrait_panel: PanelContainer
var _portrait_face: Label
var _hunger_bar: ProgressBar
var _happiness_bar: ProgressBar
var _energy_bar: ProgressBar
var _bond_bar: ProgressBar
var _bond_label: Label
var _gear_label: Label

var _action_panel: Control
var _rest_button: Button
var _food_panel: Control
var _food_row: HBoxContainer

var _transient_message := ""
var _message_timer := 0.0


func _ready() -> void:
	_build_ui()
	GameManager.mode_changed.connect(_on_mode_changed)
	GameManager.coins_changed.connect(_on_coins_changed)
	_on_mode_changed(GameManager.current_mode)
	_on_coins_changed(GameManager.coins)


## Called by main.gd after the HUD is in the tree.
func setup(species: CreatureSpecies, care: CareSystem) -> void:
	_species = species
	_care = care
	_creature_label.text = species.display_name

	var portrait_style := StyleBoxFlat.new()
	portrait_style.bg_color = species.body_color
	portrait_style.border_color = species.accent_color
	portrait_style.set_border_width_all(4)
	portrait_style.set_corner_radius_all(40)
	_portrait_panel.add_theme_stylebox_override("panel", portrait_style)

	_hunger_bar.max_value = care.stats.max_hunger
	_happiness_bar.max_value = care.stats.max_happiness
	_energy_bar.max_value = care.stats.max_energy
	_bond_bar.max_value = 1.0

	care.stats.changed.connect(_refresh_stats)
	care.message.connect(_show_message)
	care.sleep.rest_started.connect(_refresh_buttons)
	care.sleep.rest_ended.connect(_refresh_buttons)
	InventoryManager.inventory_changed.connect(_refresh_buttons)
	InventoryManager.bed_changed.connect(_refresh_gear)
	InventoryManager.toy_changed.connect(_refresh_gear)

	_refresh_stats()
	_refresh_buttons()
	_refresh_gear()


func set_hint(text: String) -> void:
	_hint_label.text = text


func _process(delta: float) -> void:
	if _care == null:
		return
	if _message_timer > 0.0:
		_message_timer -= delta
		_status_label.text = _transient_message
	else:
		_status_label.text = _get_mood_text()


# ---------- Signal handlers ----------

func _on_mode_changed(new_mode: GameManager.Mode) -> void:
	_mode_label.text = "Mode: %s" % MODE_NAMES.get(new_mode, "?")
	# Care UI is only shown at home. Camera Mode has its own HUD.
	var at_home := (new_mode == GameManager.Mode.HOME)
	_action_panel.visible = at_home
	_stats_panel.visible = at_home
	_status_label.visible = at_home
	_hint_label.visible = at_home
	if not at_home:
		_food_panel.visible = false


func _on_coins_changed(new_amount: int) -> void:
	_coins_label.text = "Coins: %d" % new_amount


func _show_message(text: String) -> void:
	_transient_message = text
	_message_timer = MESSAGE_SECONDS


func _refresh_stats() -> void:
	var stats := _care.stats
	_hunger_bar.value = stats.hunger
	_happiness_bar.value = stats.happiness
	_energy_bar.value = stats.energy
	_bond_bar.value = stats.get_bond_progress()
	_bond_label.text = "Bond Lv %d" % stats.get_bond_level()
	_portrait_face.text = _get_face_text()


func _refresh_buttons() -> void:
	if _care == null:
		return
	_rest_button.text = "Wake up" if _care.sleep.is_resting else "Rest"
	_refresh_food_buttons()


func _refresh_gear(_item_id: String = "") -> void:
	if _gear_label == null:
		return
	var bed_name := "Floor"
	var bed := ItemDatabase.get_item(InventoryManager.equipped_bed)
	if bed != null:
		bed_name = bed.display_name
	var toy_name := "None"
	var toy := ItemDatabase.get_item(InventoryManager.equipped_toy)
	if toy != null:
		toy_name = toy.display_name
	_gear_label.text = "Bed: %s   Toy: %s" % [bed_name, toy_name]


## Rebuilds the food picker: one button per Food item, disabled when you have none.
func _refresh_food_buttons() -> void:
	if _food_row == null:
		return
	for child in _food_row.get_children():
		_food_row.remove_child(child)
		child.queue_free()
	for item in ItemDatabase.get_items_in_category("Food"):
		var count := InventoryManager.get_count(item.item_id)
		var button := Button.new()
		button.text = "%s x%d" % [item.display_name, count]
		button.tooltip_text = item.get_effect_text()
		button.disabled = count <= 0
		button.custom_minimum_size = Vector2(170, 44)
		button.add_theme_font_size_override("font_size", 18)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_food_chosen.bind(item.item_id))
		_food_row.add_child(button)


func _on_feed_pressed() -> void:
	_refresh_food_buttons()
	_food_panel.visible = not _food_panel.visible


func _on_food_chosen(food_id: String) -> void:
	_food_panel.visible = false
	if _care != null:
		_care.feed(food_id)


func _on_pet_pressed() -> void:
	if _care != null:
		_care.pet()


func _on_play_pressed() -> void:
	if _care != null:
		_care.play()


func _on_rest_pressed() -> void:
	if _care == null:
		return
	if _care.sleep.is_resting:
		_care.wake()
	else:
		_care.rest()


func _on_camera_pressed() -> void:
	camera_requested.emit()


func _on_shop_pressed() -> void:
	shop_requested.emit()


# ---------- Text helpers ----------

func _get_face_text() -> String:
	if _care.sleep.is_resting:
		return "(-_-)"
	if _care.is_hungry():
		return "(>_<)"
	if _care.stats.happiness < _care.stats.max_happiness * 0.3:
		return "(T_T)"
	if _care.stats.happiness > _care.stats.max_happiness * 0.8:
		return "(^o^)"
	return "(^_^)"


func _get_mood_text() -> String:
	var creature_name := _species.display_name
	var stats := _care.stats
	if _care.sleep.is_resting:
		return "%s is sleeping peacefully... Zzz" % creature_name
	if _care.is_hungry():
		return "%s's tummy is rumbling. Time for a snack?" % creature_name
	if _care.is_tired():
		return "%s looks sleepy. A rest would help." % creature_name
	if stats.happiness < stats.max_happiness * 0.3:
		return "%s could use some cuddles." % creature_name
	if stats.happiness > stats.max_happiness * 0.8:
		return "%s is delighted!" % creature_name
	return "%s is doing fine." % creature_name


# ---------- UI construction ----------

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.name = "Root"
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for margin in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		root.add_theme_constant_override(margin, 16)

	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(layout)

	layout.add_child(_build_top_bar())

	var middle := HBoxContainer.new()
	middle.name = "Middle"
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(middle)
	middle.add_child(_build_stats_panel())

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 20)
	_status_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_status_label.add_theme_constant_override("outline_size", 6)
	layout.add_child(_status_label)

	layout.add_child(_build_food_panel())
	layout.add_child(_build_action_panel())

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = "Wheel: zoom  |  C: camera  |  B: shop  |  Debug: F1 time x10   F2 cycle bed   F3 +food +coins   F4 make hungry and tired"
	_hint_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_hint_label.add_theme_constant_override("outline_size", 4)
	layout.add_child(_hint_label)


func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	panel.name = "TopBar"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	panel.add_child(row)

	_mode_label = _make_label(row, 20)
	_creature_label = _make_label(row, 20)
	_creature_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_creature_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_coins_label = _make_label(row, 20)
	return panel


func _build_stats_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "StatsPanel"
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_stats_panel = panel

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	_portrait_panel = PanelContainer.new()
	_portrait_panel.name = "Portrait"
	_portrait_panel.custom_minimum_size = Vector2(80, 80)
	_portrait_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_face = Label.new()
	_portrait_face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_portrait_face.add_theme_font_size_override("font_size", 18)
	_portrait_face.add_theme_color_override("font_color", Color(0.25, 0.12, 0.18))
	_portrait_panel.add_child(_portrait_face)
	row.add_child(_portrait_panel)

	var right := VBoxContainer.new()
	right.name = "BarsAndGear"
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	right.add_child(grid)

	_hunger_bar = _make_bar(HUNGER_COLOR)
	_happiness_bar = _make_bar(HAPPINESS_COLOR)
	_energy_bar = _make_bar(ENERGY_COLOR)
	_bond_bar = _make_bar(BOND_COLOR)
	_add_bar_row(grid, "Hunger", _hunger_bar)
	_add_bar_row(grid, "Happiness", _happiness_bar)
	_add_bar_row(grid, "Energy", _energy_bar)
	_bond_label = _add_bar_row(grid, "Bond Lv 1", _bond_bar)

	_gear_label = Label.new()
	_gear_label.name = "GearLabel"
	_gear_label.add_theme_font_size_override("font_size", 16)
	_gear_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	right.add_child(_gear_label)
	return panel


func _build_food_panel() -> Control:
	var center := CenterContainer.new()
	center.name = "FoodPanel"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.visible = false
	_food_panel = center

	var panel := PanelContainer.new()
	center.add_child(panel)
	_food_row = HBoxContainer.new()
	_food_row.name = "FoodRow"
	_food_row.add_theme_constant_override("separation", 10)
	panel.add_child(_food_row)
	return center


func _build_action_panel() -> Control:
	var center := CenterContainer.new()
	center.name = "ActionPanel"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_panel = center

	var panel := PanelContainer.new()
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	_make_button(row, "Feed...", _on_feed_pressed)
	_make_button(row, "Pet", _on_pet_pressed)
	_make_button(row, "Play", _on_play_pressed)
	_rest_button = _make_button(row, "Rest", _on_rest_pressed)
	_make_button(row, "Camera (C)", _on_camera_pressed)
	_make_button(row, "Shop (B)", _on_shop_pressed)
	return center


func _make_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _make_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(120, 48)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE  # so Space/Enter never re-press a button
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _make_bar(fill_color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(210, 22)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.15, 0.15, 0.2, 0.75)
	background.set_corner_radius_all(6)
	bar.add_theme_stylebox_override("background", background)
	return bar


## Adds "label | bar" as one grid row and returns the label.
func _add_bar_row(grid: GridContainer, text: String, bar: ProgressBar) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	grid.add_child(label)
	grid.add_child(bar)
	return label
