extends CharacterBody3D

@onready var skeleton: Skeleton3D = $Rig/Skeleton3D
@onready var new_attachment : Node3D = $Rig/Skeleton3D/Mage_Head
@onready var anim_player : AnimationPlayer = $AnimationPlayer

# Autoload Quest PopuMenu scene
@onready var quests_popup : QuestPopMenu = get_node("/root/QuestPopupMenu")

# Autoload Inventory scene *Not in use*
@onready var player_inventory : Inventory

@export_group("Dialogue")
@export var dialogue : NPCDialogue

#Detection Variables
@export_group("Detection")
@export var vis_radius = 3
@export_range(0,10) var rotation_speed : float = 1.0
var start_head_basis : Basis
var head_rotation_weight = 0.0

# Quests!
@export_group("Quests")
@export var npc_quest : Quest
@export var npc_quest_item : BaseItem = preload("res://UI_Work/ItemsWork/ItemsWork/QuestItem.tres")
var base_item_mesh = preload("res://UI_Work/ItemsWork/ItemsWork/item.tscn")
var quest_item_mesh : Mesh = preload("res://Assets/KayKit_DungeonRemastered_1.1_FREE/Assets/obj/bottle_A_brown.obj")
var quest_item_icon : CompressedTexture2D = preload("res://Assets/UI_Assets/Potion.png")
var quest_reward : BaseItem = preload("res://UI_Work/ItemsWork/ItemsWork/SpecialPotion.tres")
var npc_quest_over : bool = false

#More detection variables
@onready var head : MeshInstance3D = $Rig/Skeleton3D/Mage_Head
var target : PlayerCharacter

# Shared vs Individual (For popup)
var shared_quest : bool = true

signal interaction_done(area)
signal chat_end(response) # When player exits out of dialogue box
signal quest_accepted()
signal quest_rejected()

func _ready():
	var game_multiplayer = get_tree().current_scene is GameManagerMultiplayer
	if game_multiplayer: 
		quest_accepted.connect(_on_quest_accepted)
		chat_end.connect(_on_chat_over.rpc)
	
	chat_end.connect(_on_chat_over)
	if !quest_accepted.is_connected(_on_quest_accepted):
		quest_accepted.connect(_on_quest_accepted)
	quest_rejected.connect(_on_quest_rejected)
	load_quest()
	
	if skeleton:
		start_head_basis = head.global_transform.basis # Store initial head rotation
		
		# Get the index of the bone you want to attach the new object to
		#var bone_index = skeleton.find_bone("Spellbook")
		#if bone_index != -1: # Testing - print bones
			# Get the bone's global transform (position, rotation, scale)
			#var _bone_name_at_index = skeleton.get_bone_name(bone_index)
			#var _bone_rotation = skeleton.get_bone_pose_rotation(bone_index)
			#var _bone_transform = skeleton.get_bone_pose_position(bone_index)
			#print("Bone Rotation: ", bone_rotation)
			# Optionally, make the new attachment a child of the skeleton so it follows the bone
			#new_attachment.get_parent().add_child(new_attachment)

# Movement Section -
# Scan for player position -> Move NPC head to face player
func _process(delta: float) -> void:
	var collisions = $ScanForPlayers.get_overlapping_bodies()
	if !collisions.is_empty() and target:
		var player_pos = null
		for col in collisions:
			if col.is_in_group("Player"):
				player_pos = col.global_transform.origin
		$ScanRaycast.look_at(player_pos, Vector3.UP)
		$ScanRaycast.force_raycast_update()
		if $ScanRaycast.is_colliding():
			var collider = $ScanRaycast.get_collider()
			if collider.is_in_group("Player"):
				$ScanRaycast.debug_shape_custom_color = Color(174,0,0)
				var direction_to_target = (player_pos - head.global_transform.origin).normalized()
				var dir_rotation = atan2(direction_to_target.x, direction_to_target.z)
				var clamped_rotation = deg_to_rad(clamp(rad_to_deg(dir_rotation), -60, 90)+self.rotation_degrees.y)
				var new_basis = head.global_transform.basis
				new_basis = Basis().rotated(Vector3.UP, clamped_rotation)
				head_rotation_weight = min(head_rotation_weight + rotation_speed * delta, 1.0)
				look_toward(new_basis,head_rotation_weight)

func look_toward(target_basis,weight):
	var start_basis = head.global_transform.basis
	head.global_transform.basis = start_basis.slerp(target_basis, weight)

func look_away(target_basis,_weight):
	head_rotation_weight = 0.0
	var start_basis = head.global_transform.basis
	while !target and head_rotation_weight < 1.0:
		head_rotation_weight = min(head_rotation_weight + rotation_speed*2 * get_process_delta_time(), 1.0)
		head.global_transform.basis = start_basis.slerp(target_basis, head_rotation_weight)
		await get_tree().process_frame

# Chat Section - Interact w player -> Start Dialogue
func interact(talk):
	if talk:
		if dialogue:
			if QuestManager.has_quest(npc_quest.id): 
				quest_check()
				dialogue.start()
			else: 
				dialogue.start()
		else: printerr("Make sure to assign Dialogue!")
	else: dialogue.d_active = false

# Quest Section - Load, Accept/Reject, Check (for QuestItem) and Finish/Reward
func load_quest():
	if !npc_quest: npc_quest = Quest.new()
	npc_quest.id = QuestManager.get_next_quest_id()
	npc_quest.title = "Lost Sauce!"
	npc_quest.description = "The Wizard Apprentice needs help finding their sauce bottle!"
	npc_quest.is_completed = false
	npc_quest.objectives = ["Look around dungeon for a brown sauce bottle"]
	npc_quest.desired_item = npc_quest_item
	npc_quest.desired_item_quantity = 1
	
	# Configure reward (Speed Potion)
	var potion_type = "Speed_Potion"
	var quest_reward_dict = QuestManager.load_reward(potion_type)
	quest_reward.value = quest_reward_dict["quantity"]
	quest_reward.icon = load(quest_reward_dict["ref"])
	quest_reward.info = quest_reward_dict["info"]
	quest_reward.max_stack_size = quest_reward_dict["max"]
	quest_reward.special_name_type = "speed"
	npc_quest.rewards[quest_reward_dict["name"]] = quest_reward
	
	# Configure desired QuestItem (BaseItem resource)
	npc_quest_item.value = 1
	npc_quest_item.max_stack_size = 1
	npc_quest_item.mesh = quest_item_mesh
	npc_quest_item.icon = quest_item_icon
	npc_quest_item.info = "A bottle of mysterious sauce"

func q_item_spawn_loc_condition(marker_name): # Marker Nodes within "Items" Node should include name of NPC
	return self.name in marker_name

func _on_quest_accepted():
	var level = get_parent() if get_parent().is_in_group("Level") else null
	var level_items : Node = level.get_node_or_null("Items")
	var markers : Array = []
	var random_marker
	var random_marker_pos
	
	for child in level_items.get_children(): # Set random location for quest item to spawn
		if child is Marker3D and q_item_spawn_loc_condition(child.name): markers.append(child)
	
	if markers.size() > 0:
		random_marker = markers[randi() % markers.size()]
		random_marker_pos = random_marker.position
	
	if get_tree().current_scene is GameManagerMultiplayer: # Multiplayer Section
		var peer_id := multiplayer.get_unique_id()
		var game = get_tree().current_scene
		var player = game.find_player(str(peer_id))
		if player != null: npc_quest.player = player
		QuestManager.accept_quest(npc_quest,peer_id)
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			if id != peer_id: sync_quest_accept.rpc_id(id,random_marker_pos)
		
	elif target: 
		npc_quest.player = target # SinglepLayer Section
		if !QuestManager.accept_quest(npc_quest): 
			printerr("Failed to create Quest! (", npc_quest.title,")")
			return
	
	if random_marker_pos != null: spawn_quest_item(random_marker_pos)
	else: printerr("Failed to Spawn QuestItem")

@rpc("any_peer","call_local")
func sync_quest_accept(pos):
	var peer_id := multiplayer.get_unique_id()
	var game = get_tree().current_scene
	var player = game.find_player(str(peer_id))
	if player != null: npc_quest.player = player
	QuestManager.accept_quest(npc_quest,peer_id)
	dialogue.quest_lock = true # Update dialogue player for all peers
	spawn_quest_item(pos)

# Spawn Quest Item 
# Pick a random Marker3D child from level
# Place Item Mesh at Marker3D position
func spawn_quest_item(pos : Vector3):
	var level = get_parent() if get_parent().is_in_group("Level") else null
	var level_items : Node = level.get_node_or_null("Items")
	var quest_item = base_item_mesh.instantiate()
	quest_item.item_type = npc_quest_item
	quest_item.item_glow = true
	quest_item.position = pos
	level_items.add_child(quest_item)

func _on_quest_rejected():
	print("quest rejected") # Do nothing

# Check for npc quest item in player inventory
# Finish quest if player has desired amount of quest item
#@rpc("any_peer","call_local") - Not Synced anymore

func quest_check():
	if npc_quest == null: return
	if target:
		print(self.name,": Looking for QuestItem [%s] from %s" % [npc_quest.desired_item.info.to_lower(),target])
		var player_inv = target.p_inv_controller.inventory
		var detected_q_items : int = player_inv.get_number_of_item(npc_quest.desired_item)
		if detected_q_items == npc_quest.desired_item_quantity:
			player_inv.remove_item(npc_quest.desired_item)
			var game_multiplayer = get_tree().current_scene is GameManagerMultiplayer
			if game_multiplayer: # Multiplayer Section
				var peer_id := multiplayer.get_unique_id()
				for id in GameManagerMultiplayer.get_active_players_multiplayer():
					if id != peer_id and shared_quest: npc_quest_finish.rpc_id(id) # If shared_quest, finish for both players
		npc_quest_finish() # Run locally

@rpc("any_peer","call_local")
func npc_quest_finish():
	QuestManager.quest_finish(npc_quest.id,npc_quest.player)
	QuestManager.give_rewards(npc_quest.player,npc_quest.rewards)

func npc_quest_reward():
	# Reward animation
	var quest_reward_mesh : Node
	var tween : Tween
	if target and !npc_quest_over:
		var level = get_parent() if get_parent().is_in_group("Level") else null
		var _level_items : Node = level.get_node_or_null("Items")
		
		var start_pos = self.position
		var end_pos = target.position 
		
		quest_reward_mesh = base_item_mesh.instantiate()
		quest_reward_mesh.monitoring = false
		quest_reward_mesh.item_type = quest_reward
		quest_reward_mesh.position = start_pos
		level.add_child(quest_reward_mesh)
		
		# Interact animation when handing reward
		anim_player.play("Interact")
		tween = create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(quest_reward_mesh, "position", end_pos, 1.0)
		npc_quest_over = true
		await tween.finished
		if quest_reward_mesh and quest_reward_mesh.is_inside_tree():
			quest_reward_mesh.queue_free()

# Signals Section
@rpc("any_peer","call_local")
func _on_chat_over():
	interaction_done.emit(self)
	if npc_quest.is_completed:
		npc_quest_reward()
		if quests_popup.menu_windows.has(npc_quest.id):
			if quests_popup.menu_windows[npc_quest.id].visible:
				await get_tree().create_timer(2.0).timeout
				if shared_quest: quests_popup.toggle_quest_menu(false,npc_quest.id)
					#quests_popup.toggle_quest_menu_remote.rpc(false,npc_quest.id)
				else: quests_popup.toggle_quest_menu(false,npc_quest.id)
	elif QuestManager.has_quest(npc_quest.id):
		if quests_popup.menu_windows.has(npc_quest.id):
			if quests_popup.menu_windows[npc_quest.id].visible: return
		
		if shared_quest: quests_popup.toggle_quest_menu(true,npc_quest.id)
			#quests_popup.toggle_quest_menu_remote.rpc(true,npc_quest.id)
		else: quests_popup.toggle_quest_menu(true,npc_quest.id)

func _on_chatzone_entered(body):
	if body.is_in_group("Player"):
		if target:
			return
		target = body
		
		# Connect to player interaction manager - Allows player to interact w NPC
		if target.interact_manager:
			if !target.interact_manager.entered_areas.has(self): target.interact_manager.add_area(self)
		
		head_rotation_weight = 0.0
		$ScanRaycast.position = Vector3.ZERO

func _on_chatzone_exited(body):
	if body == target:
		
		# Connect to player interaction manager - Allows player to interact w NPC
		if target and target.interact_manager:
			if target.interact_manager.entered_areas.has(self): target.interact_manager.remove_area(self)
		
		target = null
		look_away(start_head_basis,head_rotation_weight)
		if dialogue and dialogue.d_active: 
			dialogue.cancel_dialogue()
			_on_chat_over()

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	match anim_name:
		"Interact":
			anim_player.play("Sit_Floor_Down")
		"Sit_Floor_Down":
			anim_player.play("Sit_Floor_Idle")
