extends Node3D

# Autoload Questmanager scene
@onready var quest_manager : QuestManager = get_node("/root/QuestManager")

# Autoload Quest PopuMenu scene
@onready var quests_popup : QuestPopMenu = get_node("/root/QuestPopupMenu")

# Autoload Inventory scene *Not in use*
#@onready var player_inventory : Inventory

@onready var anim_player : AnimationPlayer = $AnimationPlayer

@export_group("Dialogue")
@export var dialogue : NPCDialogue

#Detection Variables
@export_group("Detection")
@export var vis_radius = 3

# Quests!
@export_group("Quests")
@export var npc_quest : Quest
@export var npc_quest_item : BaseItem = preload("res://UI_Work/ItemsWork/ItemsWork/QuestItem.tres")
var base_item_mesh = preload("res://UI_Work/ItemsWork/ItemsWork/item.tscn")
var quest_item_mesh : Mesh = preload("res://Assets/KayKit_DungeonRemastered_1.1_FREE/Assets/obj/key.obj")
var quest_item_icon : CompressedTexture2D = preload("res://Assets/UI_Assets/Key.png")
var quest_reward : BaseItem = null
var npc_quest_over : bool = false

#More detection variables
var target = null

signal chat_end(response) # When player exits out of dialogue box
signal quest_accepted()
signal quest_rejected()

func _ready():
	chat_end.connect(_on_chat_over)
	quest_accepted.connect(_on_quest_accepted)
	quest_rejected.connect(_on_quest_rejected)
	load_quest()
	#process_mode = PROCESS_MODE_DISABLED

func load_quest():
	if !npc_quest: npc_quest = Quest.new()
	npc_quest.id = quest_manager.get_next_quest_id()
	npc_quest.title = "Dungeon Key"
	npc_quest.description = "There must be a dungeon key around here somewhere.."
	npc_quest.is_completed = false
	npc_quest.objectives = ["Look around woods for dungeon key"]
	npc_quest.desired_item = npc_quest_item
	npc_quest.desired_item_quantity = 1
	
	# Configure reward (Speed Potion)
	#var potion_type = "Speed_Potion"
	#var quest_reward_dict = quest_manager.load_reward(potion_type)
	#quest_reward.value = quest_reward_dict["quantity"]
	#quest_reward.icon = load(quest_reward_dict["ref"])
	#quest_reward.info = quest_reward_dict["info"]
	#quest_reward.max_stack_size = quest_reward_dict["max"]
	#quest_reward.special_name_type = "speed"
	#npc_quest.rewards[quest_reward_dict["name"]] = quest_reward
	
	# Configure desired QuestItem (BaseItem resource)
	npc_quest_item.value = 1
	npc_quest_item.max_stack_size = 1
	npc_quest_item.mesh = quest_item_mesh
	npc_quest_item.icon = quest_item_icon
	npc_quest_item.info = "A rusty key"

@rpc("call_local")
func interact(talk):
	if target and !target.is_multiplayer_authority(): return
	if talk:
		if dialogue:
			if quest_manager.has_quest(npc_quest.id): 
				quest_check()
				dialogue.start()
			else: dialogue.start()
		else: printerr("Make sure to assign Dialogue!")
	else: dialogue.d_active = false

# Check for npc quest item in player inventory
# Finish quest if player has desired amount of quest item
func quest_check():
	if npc_quest == null: return
	if target:
<<<<<<< Updated upstream
		print("Looking for %s..." % [npc_quest.desired_item.info.to_lower()])
		var detected_q_items : int = player_inventory.get_number_of_item(npc_quest.desired_item)
=======
		print(self.name,": Looking for QuestItem [%s] from %s" % [npc_quest.desired_item.info.to_lower(),target])
		var player_inv = target.p_inv_controller.inventory
		var detected_q_items : int = player_inv.get_number_of_item(npc_quest.desired_item)
>>>>>>> Stashed changes
		if detected_q_items == npc_quest.desired_item_quantity:
			player_inv.remove_item(npc_quest.desired_item)
			npc_quest_finish()

func npc_quest_finish():
	quest_manager.quest_finish(npc_quest.id)
	quest_manager.give_rewards(npc_quest.player,npc_quest.rewards)

func _on_quest_accepted():
<<<<<<< Updated upstream
	if target: npc_quest.player = target
=======
	#print("starting shared quest")
	if get_tree().current_scene is GameManagerMultiplayer: 
		var game = get_tree().current_scene
		var player = game.find_player(str(multiplayer.get_unique_id()))
		npc_quest.player = player
	elif target: npc_quest.player = target
	
	if npc_quest.player != null:
		quest_manager.accept_quest(npc_quest)
		
		# Spawn Quest Item 
		# Pick a random Marker3D child from level
		# Place Item Mesh at Marker3D position
		var level = get_parent() if get_parent().is_in_group("Level") else null
		var level_items : Node = level.get_node_or_null("Items")
		var markers : Array = []
		var random_marker
		for child in level_items.get_children():
			if child is Marker3D: markers.append(child)
		if markers.size() > 0:
			#random_marker = markers[randi() % markers.size()]
			random_marker = markers[1]
		
		var quest_item = base_item_mesh.instantiate()
		quest_item.item_type = npc_quest_item
		quest_item.position = random_marker.position
		level_items.add_child(quest_item)
	
	#if multiplayer.is_server(): update_quest_accepted_remote.rpc()

#@rpc("any_peer")
#func update_quest_accepted_remote(): # Sync quest item spawn for client players
	#var level = get_parent() if get_parent().is_in_group("Level") else null
	#var level_items : Node = level.get_node_or_null("Items")
	#var markers : Array = []
	#var random_marker
	#for child in level_items.get_children():
		#if child is Marker3D: markers.append(child)
	#if markers.size() > 0:
		##random_marker = markers[randi() % markers.size()]
		#random_marker = markers[1]
	#
	#var quest_item = base_item_mesh.instantiate()
	#quest_item.item_type = npc_quest_item
	#quest_item.position = random_marker.position
	#level_items.add_child(quest_item)

@rpc("any_peer")
func _on_quest_accepted_remote(): # Client version of _on_quest_accepted()
	#print("starting individual quest")
	var receiver_id = multiplayer.get_unique_id()
	if target: npc_quest.player = get_tree().current_scene.find_player(str(receiver_id))
>>>>>>> Stashed changes
	quest_manager.accept_quest(npc_quest)
	# Spawn Quest Item 
	# Pick a random Marker3D child from level
	# Place Item Mesh at Marker3D position
	var level = get_parent() if get_parent().is_in_group("Level") else null
	var level_items : Node = level.get_node_or_null("Items")
	var markers : Array = []
	var random_marker
	for child in level_items.get_children():
		if child is Marker3D: markers.append(child)
	if markers.size() > 0:
		#random_marker = markers[randi() % markers.size()]
		random_marker = markers[1]
	
	var quest_item = base_item_mesh.instantiate()
	quest_item.item_type = npc_quest_item
	quest_item.position = random_marker.position
	level_items.add_child(quest_item)

func _on_quest_rejected():
	print("quest rejected") # Do nothing

func _on_chat_over():
	if npc_quest.is_completed:
		npc_quest_reward()
		if quests_popup.window.visible: 
			await get_tree().create_timer(2.0).timeout
			quests_popup.toggle_quest_menu(false)
		
	elif quest_manager.has_quest(npc_quest.id):
		if !quests_popup.window.visible: quests_popup.toggle_quest_menu(true)

func npc_quest_reward():
	# Reward animation
	anim_player.play("open")

func _on_chatzone_entered(body):
	if body.is_in_group("Player"):
		if target:
			return
		target = body

func _on_chatzone_exited(body):
	if body == target:
		target = null

func _on_area_entered(area: Area3D) -> void:
	if area.owner:
		if area.owner.is_in_group("Player"): pass
			#if target:
				#return
			#target = area.owner

func _on_area_exited(area: Area3D) -> void:
	if area.owner:
		if area.owner.is_in_group("Player"): pass
			#if area.owner == target: 
				#pass

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	pass
	#match anim_name:
		#"Interact":
			#anim_player.play("Sit_Floor_Down")
		#"Sit_Floor_Down":
			#anim_player.play("Sit_Floor_Idle")


func _on_multiplayer_synchronizer_tree_exiting() -> void:
	# Disable multiplayersyncronizer when deleting self
	if multiplayer.is_server(): 
		$MultiplayerSynchronizer.public_visibility = false
