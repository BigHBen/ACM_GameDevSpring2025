extends Area3D

@onready var interact_button = $"../PlayerUi/Control/Interact"
var detected_npc: Node3D = null
var interacted : bool = false : set=set_interacted

func _ready() -> void:
	if interact_button: interact_button.pressed.connect(_on_interact_pressed)

func _on_npc_chat_end():
	interact_button.visible = true

func _on_interact_body_entered(body: Node3D) -> void:
	if body.is_in_group("NPC"):
		#print("Talk to ",body.name,"?")
		detected_npc = body
		interact_button.visible = true

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

func set_interacted(val):
	interacted = val
	if interacted: interact_button.visible = false
	else: interact_button.visible = true
