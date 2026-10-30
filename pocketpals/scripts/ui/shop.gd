extends CanvasLayer

## Shop overlay. A full-screen dim rectangle blocks clicks on the game behind it.
## Open with open(); closes with the Close button, Esc, or B.

signal closed

## [item category stored in ItemData, tab label]
const CATEGORIES := [
	["Food", "Food"],
	["Sleep", "Sleep"],
	["Toy", "Toys"],
	["Decoration", "Decorations"],
]
const COLOR_OK := Color(0.55, 1.0, 0.65)
const COLOR_ERROR := Color(1.0, 0.55, 0.5)
const COLOR_GOLD := Color(1.0, 0.85, 0.3)

var _economy: Economy
var _category := "Food"
var _items: Array[ItemData] = []
var _selected: ItemData

var _coins_label: Label
var _item_list: ItemList
var _name_label: Label
var _price_label: Label
var _desc_label: Label
var _effect_label: Label
var _status_label: Label
var _action_button: Button
var _feedback_label: Label


func _ready() -> void:
	_build_ui()
	visible = false
	GameManager.coins_changed.connect(_on_coins_changed)
	InventoryManager.inventory_changed.connect(_refresh)
	InventoryManager.bed_changed.connect(_on_gear_changed)
	InventoryManager.toy_changed.connect(_on_gear_changed)
	InventoryManager.decorations_changed.connect(_refresh)


## Called by main.gd after the shop is in the tree.
func setup(economy: Economy) -> void:
	_economy = economy


func open() -> void:
	_feedback_label.text = ""
	_refresh()
	visible = true


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("open_shop"):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	visible = false
	closed.emit()


# ---------- Signal handlers ----------

func _on_coins_changed(_amount: int) -> void:
	_refresh()


func _on_gear_changed(_item_id: String) -> void:
	_refresh()


func _select_category(category: String) -> void:
	_category = category
	_selected = null
	_refresh()


func _on_item_selected(index: int) -> void:
	if index >= 0 and index < _items.size():
		_selected = _items[index]
		_show_details()


func _on_action_pressed() -> void:
	if _selected == null or _economy == null:
		return
	var result: Dictionary
	if _selected.is_consumable() or not InventoryManager.has_item(_selected.item_id):
		result = _economy.purchase(_selected.item_id)
	else:
		result = _economy.use_owned(_selected)
	_feedback_label.text = str(result["message"])
	_feedback_label.add_theme_color_override("font_color", COLOR_OK if result["ok"] else COLOR_ERROR)
	_refresh()


# ---------- Refreshing ----------

func _refresh() -> void:
	_coins_label.text = "Coins: %d" % GameManager.coins
	var previous_id := _selected.item_id if _selected != null else ""
	_items = ItemDatabase.get_items_in_category(_category)
	_item_list.clear()
	var select_index := 0
	for i in _items.size():
		var item := _items[i]
		_item_list.add_item("%s    %s" % [item.display_name, _list_suffix(item)])
		if item.item_id == previous_id:
			select_index = i
	if _items.is_empty():
		_selected = null
	else:
		_item_list.select(select_index)
		_selected = _items[select_index]
	_show_details()


func _show_details() -> void:
	if _selected == null:
		_name_label.text = "Nothing here yet"
		_price_label.text = ""
		_desc_label.text = ""
		_effect_label.text = ""
		_status_label.text = ""
		_action_button.text = "-"
		_action_button.disabled = true
		return

	var item := _selected
	var owned := InventoryManager.has_item(item.item_id)
	var needs_buying := item.is_consumable() or not owned
	_name_label.text = item.display_name
	_price_label.text = "Price: %d coins" % item.price
	var too_expensive := needs_buying and GameManager.coins < item.price
	_price_label.add_theme_color_override("font_color", COLOR_ERROR if too_expensive else COLOR_GOLD)
	_desc_label.text = item.description
	_effect_label.text = "%s\n%s" % [item.get_effect_text(), item.get_usage_text()]

	if item.is_consumable():
		_status_label.text = "You own %d." % InventoryManager.get_count(item.item_id)
	elif owned:
		_status_label.text = _owned_state(item)
	else:
		_status_label.text = "Not owned yet."

	_action_button.disabled = false
	if needs_buying:
		_action_button.text = "Buy for %d coins" % item.price
	else:
		var state := _owned_state(item)
		if state == "Equipped":
			_action_button.text = "Equipped"
			_action_button.disabled = true
		elif state == "Placed":
			_action_button.text = "Remove from room"
		elif item.category == "Decoration":
			_action_button.text = "Place in room"
		else:
			_action_button.text = "Equip"


func _list_suffix(item: ItemData) -> String:
	if item.is_consumable():
		return "%d coins  (own %d)" % [item.price, InventoryManager.get_count(item.item_id)]
	if not InventoryManager.has_item(item.item_id):
		return "%d coins" % item.price
	return "[%s]" % _owned_state(item)


## "Equipped", "Placed" or "Owned" for an item the player owns.
func _owned_state(item: ItemData) -> String:
	match item.category:
		"Sleep":
			return "Equipped" if InventoryManager.equipped_bed == item.item_id else "Owned"
		"Toy":
			return "Equipped" if InventoryManager.equipped_toy == item.item_id else "Owned"
		"Decoration":
			return "Placed" if InventoryManager.is_placed(item.item_id) else "Owned"
	return "Owned"


# ---------- UI construction ----------

func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.name = "ShopPanel"
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 20)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	# Header: title + coin balance
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "SHOP"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28)
	header.add_child(title)
	_coins_label = Label.new()
	_coins_label.add_theme_font_size_override("font_size", 24)
	_coins_label.add_theme_color_override("font_color", COLOR_GOLD)
	header.add_child(_coins_label)

	# Category tabs
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	for entry in CATEGORIES:
		var tab := Button.new()
		tab.text = str(entry[1])
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = (entry[0] == _category)
		tab.custom_minimum_size = Vector2(130, 40)
		tab.add_theme_font_size_override("font_size", 18)
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(_select_category.bind(entry[0]))
		tabs.add_child(tab)

	# Body: item list (left) + details (right)
	var body := HBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)

	_item_list = ItemList.new()
	_item_list.name = "ItemList"
	_item_list.custom_minimum_size = Vector2(360, 300)
	_item_list.allow_search = false  # otherwise typing "B" would jump in the list instead of closing the shop
	_item_list.add_theme_font_size_override("font_size", 18)
	_item_list.item_selected.connect(_on_item_selected)
	body.add_child(_item_list)

	var details := VBoxContainer.new()
	details.name = "Details"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	body.add_child(details)

	_name_label = _make_label(details, 26)
	_price_label = _make_label(details, 20)
	_desc_label = _make_label(details, 18)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.custom_minimum_size = Vector2(360, 70)
	_effect_label = _make_label(details, 17)
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.custom_minimum_size = Vector2(360, 60)
	_effect_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_status_label = _make_label(details, 18)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(filler)

	_action_button = Button.new()
	_action_button.name = "ActionButton"
	_action_button.custom_minimum_size = Vector2(0, 52)
	_action_button.add_theme_font_size_override("font_size", 22)
	_action_button.focus_mode = Control.FOCUS_NONE
	_action_button.pressed.connect(_on_action_pressed)
	details.add_child(_action_button)

	# Feedback + close
	_feedback_label = Label.new()
	_feedback_label.name = "FeedbackLabel"
	_feedback_label.custom_minimum_size = Vector2(0, 30)
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 18)
	column.add_child(_feedback_label)

	var close_button := Button.new()
	close_button.text = "Close (B / Esc)"
	close_button.custom_minimum_size = Vector2(0, 46)
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close)
	column.add_child(close_button)


func _make_label(parent: Control, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
