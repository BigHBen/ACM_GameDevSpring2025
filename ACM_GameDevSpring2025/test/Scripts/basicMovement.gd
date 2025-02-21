extends CharacterBody3D
class_name Player

@export_category("Movement Stats")
@export var speed = 5.0
@export var acceleration = 4.0
@export var jump_speed = 8.0
@export var mouse_sensitivity = 0.0015
@export var rotation_speed = 8.0
@export_category("Player Stats")
@export var health = 100
@export var moneyAmount = 10
@export var potionAmount = 5


var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false
var attacks = [
	"1H_Melee_Attack_Slice_Horizontal",
	"1H_Melee_Attack_Slice_Diagonal",
	"1H_Melee_Attack_Chop"
]
var rayOrigin = Vector3()
var rayEnd = Vector3()


@onready var model : Node3D = $Rig
@onready var anim_tree : AnimationTree = $AnimationTree
@onready var anim_state = $AnimationTree.get("parameters/playback")
@onready var camera : Camera3D = $CameraPivot/Camera3D
@onready var healthbar : TextureProgressBar = $PlayerUi/Control/Player_Health
@onready var money : Label = $PlayerUi/Control/Coins/Label
@onready var potions : Label = $PlayerUi/Control/Potions/Label



func _ready() -> void:
	healthbar.init_health(health)
	money.text = str(moneyAmount)
	potions.text = str(potionAmount)
# Movement is HEAVILY modified code from KidsCanCode
# https://www.youtube.com/@Kidscancode/featured

# Look at Cursor Provided from Nolkaloid and edited to fit Godot 4
# https://www.youtube.com/watch?v=mmvIkkKJVlQ
func _physics_process(delta):
	# Variables
		# Get Current Physics State
	var space_state = get_world_3d().direct_space_state
		# Get Current Mouse Position in the Viewport
	var mouse_position = get_viewport().get_mouse_position()
	
	rayOrigin =  camera.project_ray_origin(mouse_position) # Set ray origin
	rayEnd = rayOrigin + camera.project_ray_normal(mouse_position) * 2000 # set ray end point
	
	# The Final Value sets what collision mask the ray is on.
	# The default value is on every collision mask
	# The value is a bitmask. The current value inserted is for collision mask 3.
	# What this means is that ray will only collide with objects on layer 3. (Like the world border)
	# Or that's what I could tell from the docs and random threads on the internet
		# Collision layer vs mask: https://gamedev.stackexchange.com/questions/185178/whats-the-difference-between-collision-layers-and-collision-masks
		# How to set .create bitmask value: https://www.reddit.com/r/godot/comments/mai6fa/exclude_parameter_in_intersect_raywhat_does_it_do/
	var query = PhysicsRayQueryParameters3D.create(rayOrigin, rayEnd, 0b00000000000000000100)
	var intersection = space_state.intersect_ray(query)
	
	# Character Rotation
	if not intersection.is_empty():
		var pos = intersection.position
		model.look_at(Vector3(pos.x, position.y, pos.z), Vector3.UP)
	# Movement Stuff
	velocity.y += -gravity * delta
	get_move_input(delta)
	move_and_slide()


func get_move_input(delta):
	var vy = velocity.y
	velocity.y = 0
	var input = Input.get_vector("left", "right", "forward", "back")
	var dir = Vector3(input.x, 0, input.y).rotated(Vector3.UP, camera.rotation.y)
	velocity = lerp(velocity, dir * speed, acceleration * delta)
	var vl = velocity * model.transform.basis
	anim_tree.set("parameters/IWR/blend_position", Vector2(vl.x, -vl.z) / speed)
	velocity.y = vy

var cooldown = false
func _unhandled_input(event):
	if event.is_action_pressed("attack"):
		anim_state.travel(attacks.pick_random())
	if event.is_action_pressed("use_item") and potionAmount > 0 and cooldown == false:
		var cooldown_timer = get_tree().create_timer(2.0)
		cooldown = true
		cooldown_timer.timeout.connect(self._on_timeout)
		$"Rig/Skeleton3D/1H_Sword/Potion".visible = true
		$"Rig/Skeleton3D/1H_Sword/1H_Sword".visible = false
		anim_state.travel("Use_Item")
		potionAmount -= 1
		update_ui()
		take_damage(-10)
		await get_tree().create_timer(1.5).timeout
		$"Rig/Skeleton3D/1H_Sword/Potion".visible = false
		$"Rig/Skeleton3D/1H_Sword/1H_Sword".visible = true
func _on_timeout():
	cooldown = false

func take_damage(damage):
	healthbar._set_health(health - damage)
	health -= damage

func update_ui():
	money.text = str(moneyAmount)
	potions.text = str(potionAmount)
