extends Area3D

@onready var interact_button = $"../PlayerUi/Control/Interact"
@onready var player_inventory : PlayerInventoryController = $"../InventoryController"
var detected_npc: Node3D = null
var interacted : bool = false : set=set_interacted

var detected_chest : Node3D = null

func _ready() -> void:
	if interact_button: interact_button.pressed.connect(_on_interact_pressed)

func _on_npc_chat_end():
	interact_button.visible = true

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
	if detected_npc and detected_npc.has_method("interact"):
		if !detected_npc.chat_end.is_connected(_on_npc_chat_end):
			detected_npc.chat_end.connect(_on_npc_chat_end)
		detected_npc.interact(true)
		interacted = true
	elif detected_chest and detected_chest.has_method("interact"):
		detected_chest.interact()
		interacted = true

func set_interacted(val):
	interacted = val
	if interacted: interact_button.visible = false
	else: interact_button.visible = true


func _on_area_entered(area: Area3D) -> void:
	if area.owner.is_in_group("NPC"):
		detected_npc = area.owner
		interact_button.visible = true
		
		# Close inventory if player starts chatting
		player_inventory.close_inventory()
	
	if area.owner.is_in_group("Chest"):
		detected_chest = area.owner
		interact_button.visible = true


func _on_area_exited(area: Area3D) -> void:
	if area.owner.is_in_group("NPC"):
		if area.owner == detected_npc: 
			if detected_npc.chat_end.is_connected(_on_npc_chat_end):
				detected_npc.chat_end.disconnect(_on_npc_chat_end)
			detected_npc.interact(false)
			detected_npc = null
		interact_button.visible = false
	if area.owner and area.owner.is_in_group("Chest"):
		if area == detected_chest:
			detected_chest = null
		interact_button.visible = false
