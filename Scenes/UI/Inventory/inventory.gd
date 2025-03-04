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


func _ready() -> void:
	toggle_window(false)
	set_inventory_array()
	grid_container.columns = SLOTS_X
	for y in SLOTS_Y:
		for x in SLOTS_X:
			var button = inventory_slot.instantiate()
			var button_num = y * SLOTS_X + x + 1
			button.name += str(button_num)
			#button.text = str(button_num)
			grid_container.add_child(button)

# Started off following inventory system tutorial: https://gamedevacademy.org/godot-inventory-system-tutorial/
func toggle_window (open : bool):
	window.visible = open

func set_inventory_array():
	for child in grid_container.get_children():
		slots.append(child)
		child.set_item(null)
		child.inventory = self

func add_starter_items():
	for item in starter_items:
		add_item(item)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"): #E
		toggle_window(!window.visible)

func on_give_player_item (item : BaseItem, amount : int):
	pass

func add_item(item : BaseItem):
	var slot = get_slot_to_add(item)
	if slot == null: return
	if slot.item == null:
		slot.set_item(item)
	elif slot.item == item:
		slot.add_item()

func remove_item(item : BaseItem):
	var slot = get_slot_to_remove(item)
	if slot == null or slot.item == item: return
	slot.remove_item()

func get_slot_to_add(item : BaseItem) -> InventorySlot:
	for slot in slots:
		if slot.item == item and slot.quantity < item.max_stack_size:
			return slot
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
