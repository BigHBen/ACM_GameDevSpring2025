extends Node3D
class_name PlayerInventoryController

@onready var player : = $".."
@onready var interactions_node : PlayerInteractManager = $"../PlayerUi/InteractionsManager"

# Autoload Inventory scene
#@onready var inventory : Inventory = get_node("/root/PlayerInventory")
@onready var inventory : Inventory = $"../PlayerUi/Inventory"

# Autoload Quest Manager Scene
@onready var quest_man : QuestManager = get_node("/root/QuestManager")

# Autoload Quest Menu Scene
@onready var quest_pop : QuestPopMenu = get_node("/root/QuestPopupMenu")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	inventory.inventory_toggle.connect(inventory_window_toggled)
	inventory.focus_mode_set = player.CONTROLLER


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func collect(item : BaseItem):
	var _game = get_tree().current_scene is GameManagerMultiplayer
	inventory.add_item(item,player)
	if item.ITEM_TYPE.QUEST_ITEM: quest_man.quest_check(item)
	player.anim_state.travel("PickUp")
	#print(multiplayer.get_unique_id()," Picked up ",item.info)

func inventory_window_toggled():
	if inventory_close_conditions(): inventory.window.visible = false

func open_inventory():
	inventory.toggle_window(true)

func close_inventory():
	inventory.toggle_window(false)

func inventory_close_conditions():
	return !interactions_node.entered_areas.is_empty()

func get_baseitem_as_dict(item : BaseItem) -> Dictionary:
	var dict = {}
	var script = item.get_script()
	for prop in script.get_script_property_list():
		if prop.usage & PROPERTY_USAGE_STORAGE:
			var prop_name = prop.name
			var prop_value = item.get(prop_name)
			dict[prop_name] = prop_value
	return dict
