extends CharacterBody3D

@onready var skeleton: Skeleton3D = $Rig/Skeleton3D
@onready var new_attachment : Node3D = $Rig/Skeleton3D/Mage_Head

# Autoload Questmanager scene
@onready var quest_manager : QuestManager = get_node("/root/QuestManager")

@export_group("Dialogue")
@export var dialogue : NPCDialogue

#Detection Variables
@export_group("Detection")
@export var vis_radius = 3

# Quests!
@export_group("Quests")
@export var npc_quest : Quest

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
	npc_quest.rewards = quest_manager.load_reward("Coin")

func interact(talk):
	if talk:
		if dialogue:
			dialogue.start()
		else: printerr("Make sure to assign Dialogue!")
	else: dialogue.d_active = false

func _on_quest_accepted():
	quest_manager.accept_quest(npc_quest)

func _on_quest_rejected():
	print("quest rejected")

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
