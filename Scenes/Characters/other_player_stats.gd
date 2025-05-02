class_name Player_Stats_Debug extends Control

@onready var inventory : Inventory = $"../Inventory"
@onready var inventory_controller : PlayerInventoryController = $"../../InventoryController"
@onready var effects_manager : PlayerEffectsManager = $"../../EffectsManager"
@onready var player_interact_manager : PlayerInteractManager = $"../InteractionsManager"

@onready var panel : Panel = $Panel
@onready var area_list_label : Label = $Panel/VBoxContainer/area_list
@onready var effects_list_label : Label = $Panel/VBoxContainer/active_effects

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if player_interact_manager: update_interact_manager_debug()
	if effects_manager: update_effects_manager_debug()

func update_interact_manager_debug():
	area_list_label.text = "ENTERED_AREAS: " + str(player_interact_manager.entered_areas)
	update_label_width()

func update_effects_manager_debug():
	effects_list_label.text = "Active Effects: " + str(effects_manager.active_effects)
	update_label_width()

func update_label_width():
	var area_list_label_size = area_list_label.get_minimum_size() # Resize label panel to fit array text
	var effects_list_label_size = effects_list_label.get_minimum_size() # Resize label panel to fit array text
	var label_size = area_list_label_size.max(effects_list_label_size)
	panel.custom_minimum_size = label_size + Vector2(25,0)
