extends CanvasLayer

## Camera Mode HUD: reticle, framing indicator, zoom, buttons, flash.

signal photo_requested
signal recenter_requested
signal exit_requested

const TOAST_SECONDS := 2.5
const COLOR_IDLE := Color(1.0, 1.0, 1.0, 0.9)
const COLOR_OK := Color(0.4, 1.0, 0.55)

var _reticle: Control
var _framing_label: Label
var _zoom_label: Label
var _toast_label: Label
var _flash: ColorRect
var _reticle_color := COLOR_IDLE
var _toast_timer := 0.0


func _ready() -> void:
	_build_ui()
	GameManager.mode_changed.connect(_on_mode_changed)
	_on_mode_changed(GameManager.current_mode)


## Called by main.gd after this HUD is in the tree.
func setup(photo_camera: PhotoCamera) -> void:
	photo_camera.framing_changed.connect(_on_framing_changed)
	photo_camera.zoom_changed.connect(_on_zoom_changed)
	photo_camera.photo_taken.connect(_on_photo_taken)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.text = ""


# ---------- Signal handlers ----------

func _on_mode_changed(new_mode: GameManager.Mode) -> void:
	visible = (new_mode == GameManager.Mode.CAMERA)


func _on_framing_changed(text: String, in_frame: bool) -> void:
	_framing_label.text = text
	_reticle_color = COLOR_OK if in_frame else COLOR_IDLE
	_reticle.queue_redraw()


func _on_zoom_changed(multiplier: float) -> void:
	_zoom_label.text = "Zoom %.1fx" % multiplier


func _on_photo_taken(result: Dictionary) -> void:
	if result["valid"]:
		_flash.modulate.a = 0.85
		var tween := create_tween()
		tween.tween_property(_flash, "modulate:a", 0.0, 0.35)
	else:
		_toast_label.text = str(result["message"])
		_toast_timer = TOAST_SECONDS


# ---------- Drawing ----------

func _draw_reticle() -> void:
	var center := _reticle.size * 0.5
	var half := 70.0
	var arm := 24.0
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var corner := center + Vector2(sx * half, sy * half)
			_reticle.draw_line(corner, corner + Vector2(-sx * arm, 0.0), _reticle_color, 3.0)
			_reticle.draw_line(corner, corner + Vector2(0.0, -sy * arm), _reticle_color, 3.0)
	_reticle.draw_circle(center, 3.0, _reticle_color)


# ---------- UI construction ----------

func _build_ui() -> void:
	# Reticle: a 160x160 control centered on the screen, drawn with draw_line().
	_reticle = Control.new()
	_reticle.name = "Reticle"
	_reticle.custom_minimum_size = Vector2(160, 160)
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reticle)
	_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_reticle.draw.connect(_draw_reticle)

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

	# Leaves room for the main HUD's top bar (mode / name / coins).
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 56)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(spacer)

	_framing_label = _make_outlined_label(layout, 24)
	_framing_label.name = "FramingLabel"

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(filler)

	_toast_label = _make_outlined_label(layout, 22)
	_toast_label.name = "ToastLabel"
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))

	layout.add_child(_build_bottom_bar())

	var help := _make_outlined_label(layout, 16)
	help.name = "HelpLabel"
	help.text = "Hold right mouse + move or WASD: aim  |  Wheel: zoom  |  Click or Space: photo  |  C: exit"

	# Flash overlay is added last so it draws on top of everything.
	_flash = ColorRect.new()
	_flash.name = "Flash"
	_flash.color = Color.WHITE
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.modulate.a = 0.0


func _build_bottom_bar() -> Control:
	var center := CenterContainer.new()
	center.name = "BottomBar"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	center.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	_zoom_label = Label.new()
	_zoom_label.name = "ZoomLabel"
	_zoom_label.text = "Zoom 1.0x"
	_zoom_label.custom_minimum_size = Vector2(110, 0)
	_zoom_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_zoom_label.add_theme_font_size_override("font_size", 20)
	row.add_child(_zoom_label)

	_make_button(row, "Take Photo (Space)", func() -> void: photo_requested.emit(), 200)
	_make_button(row, "Find Creature", func() -> void: recenter_requested.emit(), 150)
	_make_button(row, "Exit Camera (C)", func() -> void: exit_requested.emit(), 170)
	return center


func _make_outlined_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.15))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label


func _make_button(parent: Control, text: String, callback: Callable, min_width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width, 48)
	button.add_theme_font_size_override("font_size", 20)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
