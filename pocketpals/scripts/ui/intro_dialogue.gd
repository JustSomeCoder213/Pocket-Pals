class_name IntroDialogue
extends CanvasLayer

## The professor's welcome and the starter gift.
## Enter or the Next button advances. Clicking while text is typing finishes the line.
## Skip jumps straight to the gift. The gift is only granted by the Accept button.

signal starter_accepted

const PROFESSOR_NAME := "Professor Pippa Fernwick"
const CHARS_PER_SECOND := 60.0
const LINES := [
	"Oh, a new face! Welcome to Little World. I'm Professor Pippa Fernwick, and I study the creatures that live around here.",
	"Around here we don't battle. We watch, we care, and we take photographs. A good photo tells a creature's story, and the Museum pays coins for them!",
	"Photography is simple: press C for Camera Mode. Hold the right mouse button or use WASD to aim, scroll to zoom, then click or press Space. Keep the creature near the center, and not too small.",
	"Caring matters just as much. Feed, pet, play and rest. Nothing bad ever happens if you take a break; your companion just gets a little hungry and sleepy. Resting is always free.",
	"Coins from photos buy food, comfier beds, toys and decorations in the shop (B). And press O to explore the meadow, where new species are waiting to be discovered!",
	"Esc opens the menu, J opens your collection, and the game saves by itself. Now, one last thing...",
]
const OFFER_LINE := "Meet %s! I found this little one near the meadow, and it has been waiting for someone kind. Will you take care of it?"

var _species: CreatureSpecies
var _index := 0
var _offer_shown := false
var _typing_tween: Tween

var _name_label: Label
var _text_label: Label
var _page_label: Label
var _next_button: Button
var _skip_button: Button
var _offer_box: HBoxContainer
var _offer_portrait: PanelContainer
var _offer_label: Label
var _accept_button: Button


func _ready() -> void:
	_build_ui()
	visible = false


func start(species: CreatureSpecies) -> void:
	_species = species
	_index = 0
	_offer_shown = false
	visible = true
	_show_line()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		if _offer_shown:
			_on_accept_pressed()
		else:
			_on_next_pressed()


# ---------- Dialogue flow ----------

func _show_line() -> void:
	_name_label.text = PROFESSOR_NAME
	_offer_box.visible = false
	_next_button.visible = true
	_skip_button.visible = true
	_page_label.text = "%d / %d" % [_index + 1, LINES.size()]
	_type_text(str(LINES[_index]))


func _show_offer() -> void:
	_offer_shown = true
	_page_label.text = ""
	_next_button.visible = false
	_skip_button.visible = false
	_type_text(OFFER_LINE % _species.display_name)

	var style := StyleBoxFlat.new()
	style.bg_color = _species.body_color
	style.border_color = _species.accent_color
	style.set_border_width_all(4)
	style.set_corner_radius_all(36)
	_offer_portrait.add_theme_stylebox_override("panel", style)
	_offer_label.text = "%s\n(%s)" % [_species.description, _species.rarity]
	_accept_button.text = "Accept %s (Enter)" % _species.display_name
	_offer_box.visible = true


## Shows text with a typewriter effect.
func _type_text(text: String) -> void:
	_text_label.text = text
	_text_label.visible_ratio = 0.0
	if _typing_tween != null:
		_typing_tween.kill()
	_typing_tween = create_tween()
	_typing_tween.tween_property(_text_label, "visible_ratio", 1.0, maxf(text.length() / CHARS_PER_SECOND, 0.2))


## If a line is still being typed, shows it completely and returns true.
func _finish_typing() -> bool:
	if _typing_tween != null and _typing_tween.is_running():
		_typing_tween.kill()
		_text_label.visible_ratio = 1.0
		return true
	return false


func _on_next_pressed() -> void:
	if _offer_shown or _finish_typing():
		return
	_index += 1
	if _index >= LINES.size():
		_show_offer()
	else:
		_show_line()


func _on_skip_pressed() -> void:
	if _offer_shown:
		return
	_finish_typing()
	_show_offer()


func _on_accept_pressed() -> void:
	if not visible:
		return
	visible = false
	starter_accepted.emit()


# ---------- UI construction ----------

func _build_ui() -> void:
	# A light dim that still swallows clicks, so nothing behind can be pressed.
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.3)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var root := MarginContainer.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		root.add_theme_constant_override(side, 40)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(filler)

	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	column.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	margin.add_child(row)

	row.add_child(_build_professor_portrait())

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)

	_name_label = _make_label(right, PROFESSOR_NAME, 22)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	_text_label = _make_label(right, "", 22)
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.custom_minimum_size = Vector2(500, 100)

	_offer_box = HBoxContainer.new()
	_offer_box.name = "OfferBox"
	_offer_box.add_theme_constant_override("separation", 14)
	_offer_box.visible = false
	right.add_child(_offer_box)

	_offer_portrait = PanelContainer.new()
	_offer_portrait.custom_minimum_size = Vector2(72, 72)
	_offer_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var face := Label.new()
	face.text = "(^_^)"
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_theme_color_override("font_color", Color(0.25, 0.12, 0.18))
	_offer_portrait.add_child(face)
	_offer_box.add_child(_offer_portrait)

	_offer_label = _make_label(_offer_box, "", 17)
	_offer_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_offer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_offer_label.custom_minimum_size = Vector2(300, 0)

	_accept_button = _make_button(_offer_box, "Accept", _on_accept_pressed, 230)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	right.add_child(bottom)
	_page_label = _make_label(bottom, "", 16)
	_page_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	_skip_button = _make_button(bottom, "Skip to the gift", _on_skip_pressed, 170)
	_next_button = _make_button(bottom, "Next (Enter)", _on_next_pressed, 150)


func _build_professor_portrait() -> Control:
	var portrait := PanelContainer.new()
	portrait.name = "ProfessorPortrait"
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.45, 0.72, 0.7)
	style.border_color = Color(0.25, 0.45, 0.45)
	style.set_border_width_all(4)
	style.set_corner_radius_all(48)
	portrait.add_theme_stylebox_override("panel", style)
	var face := Label.new()
	face.text = "(o.o)"
	face.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	face.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	face.add_theme_font_size_override("font_size", 20)
	face.add_theme_color_override("font_color", Color(0.12, 0.2, 0.2))
	portrait.add_child(face)
	return portrait


func _make_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _make_button(parent: Control, text: String, callback: Callable, min_width: float) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(min_width, 48)
	button.add_theme_font_size_override("font_size", 19)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
