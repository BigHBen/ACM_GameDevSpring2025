extends Area3D

@onready var interact_button = $"../PlayerUi/Control/Interact"
@onready var player_inventory : PlayerInventoryController = $"../InventoryController"
var interacted : bool = false : set=set_interacted

var detected_npc: Node3D = null
var detected_chest : Node3D = null
var detected_door : Node3D = null

var entered_areas : Array = []

@export var button_test : bool = false
@onready var interact_button_button : Button = $"../PlayerUi/Control/Interact"
var interact_text : String = "Interact"

func _ready() -> void:
	if interact_button: interact_button.pressed.connect(_on_interact_pressed)

func _process(_delta: float) -> void:
	if detected_npc:
		if !entered_areas.is_empty() and entered_areas.front() == detected_npc:
			interacted = false if detected_npc.target != null else true
			if button_test: interact_button_button.text = interact_text + " " + detected_npc.name
			else: interact_button.text = interact_text
	if detected_chest:
		if !entered_areas.is_empty() and entered_areas.front() == detected_chest:
			interacted = false if (detected_chest.target != null and !detected_chest.opened) else true
			if button_test: interact_button_button.text = interact_text + " " + detected_chest.name
			else: interact_button.text = interact_text
	if detected_door:
		if !entered_areas.is_empty() and entered_areas.front() == detected_door:
			interacted = false if detected_door.target != null else true
			if button_test: interact_button_button.text = interact_text + " " + detected_door.name
			else: interact_button.text = interact_text

func _on_npc_chat_end():
	interacted = false

func _on_interaction_end(area):
	print("Finished player interaction with ", area)
	if !entered_areas.is_empty(): interacted = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if interact_button.visible: _on_interact_pressed()

func _on_interact_body_entered(body: Node3D) -> void:
	if body.is_in_group("NPC"):
		#print("Talk to ",body.name,"?")
		detected_npc = body
		interact_button.visible = true
		
		# Close inventory if player starts chatting
		player_inventory.close_inventory()

func _on_interact_body_exited(body: Node3D) -> void:
	if body.is_in_group("NPC"):
		if body == detected_npc: 
			if detected_npc.chat_end.is_connected(_on_npc_chat_end):
				detected_npc.chat_end.disconnect(_on_npc_chat_end)
			detected_npc.interact(false)
			detected_npc = null
		interact_button.visible = false

func _on_interact_pressed():
	var node_to_check
	if !entered_areas.is_empty():
		if entered_areas.front() == detected_npc: node_to_check = detected_npc
		elif entered_areas.front() == detected_chest: node_to_check = detected_chest
		elif entered_areas.front() == detected_door: node_to_check = detected_door
		if node_to_check and node_to_check.has_method("interact"):
			if node_to_check == detected_npc:
				if !node_to_check.chat_end.is_connected(_on_npc_chat_end):
					node_to_check.chat_end.connect(_on_npc_chat_end)
					node_to_check.interact(true)
			else:
				if !node_to_check.interaction_done.is_connected(_on_interaction_end): 
					node_to_check.interaction_done.connect(_on_interaction_end)
				node_to_check.interact()
			entered_areas.erase(node_to_check)
			interacted = true

	#elif detected_chest and detected_chest.has_method("interact"):
		#detected_chest.interact()
		#interacted = true
	#elif detected_door and detected_door.has_method("interact"):
		#detected_door.interact()
		#interacted = true

func set_interacted(val):
	interacted = val
	if interacted: 
		interact_button.visible = false
	else: 
		interact_button.visible = true
		

func _on_area_entered(area: Area3D) -> void:
	if !get_parent().is_multiplayer_authority(): return
	if area.owner:
		if area.owner.is_in_group("NPC"):
			detected_npc = area.owner
			#if detected_npc.target != null: interacted = false
			
			# Close inventory if player starts chatting
			player_inventory.close_inventory()
			
			if !entered_areas.has(area.owner): entered_areas.append(area.owner)
		if area.owner.is_in_group("Chest"):
			detected_chest = area.owner
			#if !detected_chest.opened and detected_chest.target != null: interacted = false
			if !entered_areas.has(area.owner) and !detected_chest.opened: entered_areas.append(area.owner)
		if area.owner.is_in_group("Door"):
			detected_door = area.owner
			#if detected_door.target != null: interacted = false
			if !entered_areas.has(area.owner):
				entered_areas.append(area.owner)

func _on_area_exited(area: Area3D) -> void:
	if area.owner:
		if area.owner.is_in_group("NPC"):
			if area.owner == detected_npc: 
				if detected_npc.chat_end.is_connected(_on_npc_chat_end):
					detected_npc.chat_end.disconnect(_on_npc_chat_end)
				detected_npc.interact(false)
				detected_npc = null
				if entered_areas.has(detected_npc): entered_areas.erase(detected_npc)
			interact_button.visible = false
		if area.owner.is_in_group("Chest"):
			if area.owner == detected_chest:
				detected_chest = null
				if entered_areas.has(detected_chest): 
					entered_areas.erase(detected_chest)
					print("Removed %s from entered_areas" % [detected_chest])
			interact_button.visible = false
		if area.owner.is_in_group("Door"):
			if area.owner == detected_door:
				detected_door = null
				if entered_areas.has(detected_door): 
					entered_areas.erase(detected_door)
					print("Removed %s from entered_areas" % [detected_door])
		if entered_areas.is_empty(): interacted = true
