extends CharacterBody3D

@onready var skeleton: Skeleton3D = $Rig/Skeleton3D
@onready var new_attachment : Node3D = $Rig/Skeleton3D/Mage_Head

# Autoload Questmanager scene
@onready var quest_manager : QuestManager = get_node("/root/QuestManager")

# Autoload Inventory scene
@onready var player_inventory : Inventory = get_node("/root/PlayerInventory")

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
var quest_item_mesh : Mesh = preload("res://Assets/KayKit_DungeonRemastered_1.1_FREE/Assets/obj/bottle_A_brown.obj")
var quest_item_icon : CompressedTexture2D = preload("res://Assets/UI_Assets/Potion.png")
var quest_reward : BaseItem = preload("res://UI_Work/ItemsWork/ItemsWork/SpecialPotion.tres")


#Visibility/Raycasts
var prev_raycast_endpoint := Vector2.ZERO
var curr_endpoint_position := Vector2.ZERO

#More detection variables
var target
var target2
var hit_pos
var params
var target_raycast
var raycast_endpoint := Vector2.ZERO
var target_displacement := Vector2.ZERO
var target_velocity := Vector2.ZERO
var player_spotted: bool
var rid_array = []
@export var exclude_enemies : bool = true
@onready var head : MeshInstance3D = $Rig/Skeleton3D/Mage_Head

var rotation_speed : float = 0.001

signal chat_end(response) # When player exits out of dialogue box
signal quest_accepted()
signal quest_rejected()

func _ready():
	chat_end.connect(_on_chat_over)
	quest_accepted.connect(_on_quest_accepted)
	quest_rejected.connect(_on_quest_rejected)
	load_quest()
	
	# Mesh testing - not used
	if skeleton:
		# Get the index of the bone you want to attach the new object to
		var bone_index = skeleton.find_bone("Spellbook")
		
		if bone_index != -1:
			# Get the bone's global transform (position, rotation, scale)
			var _bone_name_at_index = skeleton.get_bone_name(bone_index)
			var _bone_rotation = skeleton.get_bone_pose_rotation(bone_index)
			var _bone_transform = skeleton.get_bone_pose_position(bone_index)
			#print("Bone Rotation: ", bone_rotation)
			# Optionally, make the new attachment a child of the skeleton so it follows the bone
			#new_attachment.get_parent().add_child(new_attachment)

func _process(delta: float) -> void:
	var collisions = $Area3D.get_overlapping_bodies()
	if !collisions.is_empty():
		for col in collisions:
			if col.is_in_group("Player"):
				var player_pos = col.global_transform.origin
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
						head.global_transform.basis = new_basis
					else:
						$ScanRaycast.debug_shape_custom_color = Color(0,225,0)
						var new_basis = head.global_transform.basis
						new_basis = Basis().rotated(Vector3.UP, deg_to_rad(self.rotation.y))
						head.global_transform.basis = new_basis
				else: 
					$ScanRaycast.debug_shape_custom_color = Color(0,0,100)
					var new_basis = head.global_transform.basis
					new_basis = Basis().rotated(Vector3.UP, deg_to_rad(self.rotation.y))
					head.global_transform.basis = new_basis
			else:
				var new_rotation_degrees = lerp(self.rotation.y, 0.0, rotation_speed * delta)
				var new_basis = head.global_transform.basis
				new_basis = Basis().rotated(Vector3.UP, deg_to_rad(new_rotation_degrees))
				head.global_transform.basis = new_basis

func load_quest():
	if !npc_quest: npc_quest = Quest.new()
	npc_quest.id = quest_manager.get_next_quest_id()
	npc_quest.title = "Lost Sauce!"
	npc_quest.description = "The Wizard Apprentice needs help finding their sauce bottle!"
	npc_quest.is_completed = false
	npc_quest.objectives = ["Look around dungeon for a brown sauce bottle"]
	npc_quest.desired_item = npc_quest_item
	npc_quest.desired_item_quantity = 1
	
	# Configure reward (Speed Potion)
	var potion_type = "Speed_Potion"
	var quest_reward_dict = quest_manager.load_reward(potion_type)
	quest_reward.value = quest_reward_dict["quantity"]
	quest_reward.icon = load(quest_reward_dict["ref"])
	quest_reward.info = quest_reward_dict["info"]
	quest_reward.special_potion_type = "speed"
	npc_quest.rewards[quest_reward_dict["name"]] = quest_reward
	
	# Configure desired QuestItem (BaseItem resource)
	npc_quest_item.value = 1
	npc_quest_item.mesh = quest_item_mesh
	npc_quest_item.icon = quest_item_icon
	npc_quest_item.info = "A bottle of mysterious sauce"


func interact(talk):
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
		print("Looking for %s..." % [npc_quest.desired_item.info.to_lower()])
		var detected_q_items : int = player_inventory.get_number_of_item(npc_quest.desired_item)
		if detected_q_items == npc_quest.desired_item_quantity:
			npc_quest_finish()


func npc_quest_finish():
	quest_manager.quest_finish(npc_quest.id)
	
	# Reward animation
	
	if target:
		var start_pos = self.position
		var end_pos = target.position 
		
		var quest_reward_mesh = quest_reward.instantiate()
		quest_reward.position = start_pos

func _on_quest_accepted():
	if target: npc_quest.player = target
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
		random_marker = markers[randi() % markers.size()]
	
	var quest_item = base_item_mesh.instantiate()
	quest_item.item_type = npc_quest_item
	quest_item.position = random_marker.position
	level_items.add_child(quest_item)

func _on_quest_rejected():
	print("quest rejected") # Do nothing

func _on_chat_over():
	pass

func _on_chatzone_entered(body):
	if body.is_in_group("Player"):
		if target:
			return
		target = body

func _on_chatzone_exited(body):
		if body == target:
			target = null


func _on_scan_timeout() -> void:
	pass
