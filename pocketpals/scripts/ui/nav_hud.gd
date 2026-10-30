class_name NavHud
extends CanvasLayer

## Right-hand navigation panel: collection progress + travel buttons.
## Home:    Go Outdoors (O), Collection (J)
## Outdoor: Camera (C), Collection (J), Go Home (H), and a controls hint at the bottom.

signal outdoors_requested
signal home_requested
signal camera_requested
signal collection_requested

var _discovery: DiscoverySystem
var _progress_label: Label
var _outdoors_button: Button
var _camera_button: Button
var _home_button: Button
var _hint_label: Label


func _ready() -> void:
	_build_ui()
	GameManager.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(GameManager.current_mode)


## Called by main.gd after this HUD is in the tree.
func setup(discovery: DiscoverySystem) -> void:
	_discovery = discovery
	discovery.changed.connect(_refresh_progress)
	_refresh_progress()


func _on_mode_changed(new_mode: GameManager.Mode) -> void:
	var at_home := (new_mode == GameManager.Mode.HOME)
	var outdoors := (new_mode == GameManager.Mode.OUTDOOR)
	visible = at_home or outdoors
	_outdoors_button.visible = at_home
	_camera_button.visible = outdoors
	_home_button.visible = outdoors
	_hint_label.visible = outdoors


func _refresh_progress() -> void:
	if _discovery == null:
		return
	_progress_label.text = "Collection: %d / %d" % [_discovery.get_discovered_count(), _discovery.get_total_count()]


# ---------- UI construction ----------

func _build_ui() -> void:
	var root := MarginContainer.new()
	root.name = "Root"
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_top", 76)  # clears the main HUD's top bar
	root.add_theme_constant_override("margin_bottom", 16)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)

	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(filler)

	var panel := PanelContainer.new()
	panel.name = "NavPanel"
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(panel)

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	panel.add_child(buttons)

	_progress_label = Label.new()
	_progress_label.name = "ProgressLabel"
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 18)
	buttons.add_child(_progress_label)

	_outdoors_button = _make_button(buttons, "Go Outdoors (O)", func() -> void: outdoors_requested.emit())
	_camera_button = _make_button(buttons, "Camera (C)", func() -> void: camera_requested.emit())
	_make_button(buttons, "Collection (J)", func() -> void: collection_requested.emit())
	_home_button = _make_button(buttons, "Go Home (H)", func() -> void: home_requested.emit())

	var vertical_filler := Control.new()
	vertical_filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vertical_filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(vertical_filler)

	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = "Wheel: zoom  |  C: camera mode  |  J: collection  |  H: go home  |  Debug: F5 spawn all creatures   F6 reset collection"
	_hint_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	_hint_label.add_theme_constant_override("outline_size", 4)
	column.add_child(_hint_label)


func _make_button(parent: Control, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(190, 46)
	button.add_theme_font_size_override("font_size", 19)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
