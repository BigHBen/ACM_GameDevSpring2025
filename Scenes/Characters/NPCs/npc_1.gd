extends CharacterBody3D

# Reference to the Skeleton3D node of the rig
@onready var skeleton: Skeleton3D = $Rig/Skeleton3D

# Reference to the new bone attachment (e.g., a new MeshInstance3D or other object)
@onready var new_attachment : Node3D = $Rig/Skeleton3D/Mage_Head

#Detection Variables
@export_group("Detection")
@export var vis_radius = 3

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


func _ready():
	if skeleton:
		# Get the index of the bone you want to attach the new object to
		var bone_index = skeleton.find_bone("Spellbook")
		
		if bone_index != -1:
			# Get the bone's global transform (position, rotation, scale)
			var _bone_transform = skeleton.get_bone_pose_position(bone_index)
			
			# Optionally, make the new attachment a child of the skeleton so it follows the bone
			#new_attachment.get_parent().add_child(new_attachment)

func _process(_delta: float) -> void:
	pass

func _on_chatzone_entered(body):
	if body.is_in_group("Player"):
		if target:
			return
		target = body

func _on_chatzone_exited(body):
		if body == target:
			target = null
