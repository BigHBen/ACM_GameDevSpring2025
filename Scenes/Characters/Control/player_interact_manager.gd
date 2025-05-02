class_name PlayerInteractManager extends Control

@onready var player_inventory: Inventory = $"../Inventory"
@export var button_test : bool = false
@onready var interact_button : Button = $Interact
var interact_text : String = "Interact"

var entered_areas : Array[Node] = []

func add_area(value):
	if !entered_areas.has(value): entered_areas.append(value)
	area_changed()

func remove_area(value):
	if entered_areas.has(value): entered_areas.erase(value)
	area_changed()

func area_changed():
	if !entered_areas.is_empty():
		if button_test: interact_button.text = interact_text + " " + entered_areas.front().name
		else: interact_button.text = interact_text 
		if !interact_button.visible: 
			interact_button.show()
		player_inventory.toggle_window(false) # Close inventory while near NPCs
	else: interact_button.hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		if interact_button.visible: _on_interact_pressed()

func _on_interact_pressed():
	if entered_areas.is_empty():
		printerr("No detected NPCs to interact: Entered_Areas: ", entered_areas)
		return
	interact_button.hide()
	var talk_to = entered_areas.front()
	if talk_to.has_method("interact"):
		if !talk_to.interaction_done.is_connected(_on_interaction_end): 
			talk_to.interaction_done.connect(_on_interaction_end)
		@warning_ignore("standalone_ternary")
		talk_to.interact(true) if talk_to.is_in_group("NPC") else await talk_to.interact()

func _on_interaction_end(area):
	print("Finished player interaction with ", area)
	remove_area(area)
