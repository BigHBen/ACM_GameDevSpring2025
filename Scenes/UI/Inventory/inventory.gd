class_name Inventory extends Control

const SLOTS_X = 5
const SLOTS_Y = 2

const SLOT_SIZE : Vector2 = Vector2(128,128)
const HALF_SLOT = SLOT_SIZE * 0.5
const SPACING = Vector2(2,2)

const MAX_SLOTS = SLOTS_X * SLOTS_Y
const MAX_QUANTITY = 10

var slots : Array[InventorySlot]
@onready var window : Panel = $Panel
@onready var info_text : Label = $Panel/Info
@export var starter_items : Array[BaseItem]

@onready var grid_container : GridContainer = $Panel/InventorySlots

var inventory_slot = preload("res://Scenes/UI/Inventory/inventory_slot.tscn")
var hovered_slot : InventorySlot

# Reference to player
var player_ref : PlayerCharacter

signal inventory_toggle(open)

func _ready() -> void:
	toggle_window(false)
	grid_container.columns = SLOTS_X
	for y in SLOTS_Y:
		for x in SLOTS_X:
			var button = inventory_slot.instantiate()
			var button_num = y * SLOTS_X + x + 1
			button.name += str(button_num)
			#button.text = str(button_num)
			grid_container.add_child(button)
			#print("Slot: %s | Item: %s | Quantity: %s" % [button.name, button.item, button.quantity])
	
			# Set up signals - Hovering mouse over slots will change info_text
			button.mouse_entered.connect(_on_slot_hovered.bind(button))
			button.mouse_exited.connect(_on_slot_hover_exit.bind(button))
	set_inventory_array()

# Started off following inventory system tutorial: https://gamedevacademy.org/godot-inventory-system-tutorial/
func toggle_window(open : bool):
	if open: animated_pop_up(open)
	else: await animated_pop_up(open)
	window.visible = open
	inventory_toggle.emit()
	for s in slots: 
		s.toggle_slot_options(false)

func animated_pop_up(open : bool):
	match open:
		true:
			$Panel.scale = Vector2.ONE/8
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_LINEAR)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_property($Panel, "scale", Vector2.ONE, 0.1)
			await tween.finished
		false:
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_LINEAR)
			tween.set_ease(Tween.EASE_IN_OUT)
			tween.tween_property($Panel, "scale", Vector2.ONE/8, 0.1)
			await tween.finished

func set_inventory_array():
	for child in grid_container.get_children():
		slots.append(child)
		child.set_item(null)
		child.inventory = self

func add_starter_items():
	for item in starter_items:
		add_item(item, null)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"): #E
		toggle_window(!window.visible)

# Add item directly to inventory via script
func on_give_player_item (_item : BaseItem, _amount : int):
	pass

func add_item(item : BaseItem, from):
	if from != null and from.is_in_group("Player"):
		player_ref = from
	var slot = get_slot_to_add(item)
	if slot == null: return
	if slot.item == null:
		slot.set_item(item)
	elif slot.item == item:
		slot.add_item()

func remove_item(item : BaseItem):
	var slot = get_slot_to_remove(item)
	if slot == null or slot.item != item: return
	color_flash(slot,Color.RED, 0.25)
	slot.remove_item()

func get_slot_to_add(item : BaseItem) -> InventorySlot:
	for slot in slots:
		if slot.item and item.type:
			match slot.item.type:
				item.ITEM_TYPE.SPECIAL_POTION: 
					if slot.item.type and slot.item.special_name_type == item.special_name_type:
						return slot
				_: if slot.item.type == item.type: return slot
	for slot in slots:
		if slot.item == null:
			return slot
	return null

func get_slot_to_remove(item : BaseItem) -> InventorySlot:
	for slot in slots:
		if slot.item == item:
			return slot
	return null

func get_number_of_item(item : BaseItem) -> int:
	var total = 0
	for slot in slots:
		if slot.item == item: total += slot.quantity
	return total

func color_flash(slot : InventorySlot, color : Color, duration: float):
	var _cur_modulate = slot.modulate
	slot.modulate = color
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(slot, "modulate", Color.WHITE, duration)

func _on_slot_hovered(slot : InventorySlot):
	var slot_item = slot.item
	hovered_slot = slot
	if slot_item == null: return
	info_text.text = slot_item.info

func _on_slot_hover_exit(slot : InventorySlot):
	if hovered_slot.slot_options.mouse_entered: pass
	else: slot.toggle_slot_options(false)
	info_text.text = "Info"
