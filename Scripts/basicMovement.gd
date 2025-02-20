extends CharacterBody3D
class_name Player2

@export_group("Movement")
@export var speed = 5.0
@export var acceleration = 4.0
#@export var jump_speed = 8.0

@export_group("Friction")
@export_range(0,1) var FRICTION: float = 1
var base_friction_multiplier = 10

@export_group("Camera")
#@export var mouse_sensitivity = 0.0015
@export var rotation_speed = 12.0


#@export var something1 = 0.0 # Debug testing
#@export var something2 = 0.0

var speed_threshold = 5.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false
var last_floor = true
var attacks = [
	"1H_Melee_Attack_Slice_Horizontal",
	"1H_Melee_Attack_Slice_Diagonal",
	"1H_Melee_Attack_Chop"
]
var rayOrigin = Vector3()
var rayEnd = Vector3()

# Node References
@onready var model = $Rig
@onready var anim_player = $AnimationPlayer
@onready var anim_tree = $AnimationTree
@onready var anim_state : AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/AnimationNodeStateMachine/playback")
@onready var camera = $CameraPivot/Camera3D

var attacking = false
var blocking = false

func _ready():
	anim_tree.animation_finished.connect(_on_animation_finished)
	set_camera()

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
	handle_rotation(space_state,delta)
	
	# Movement Stuff
	velocity += get_gravity() * delta
	get_move_input(delta)
	move_and_slide()
	change_anim_parameters()
	

func get_move_input(delta):
	var vy = velocity.y # Preserve vertical velocity while horizontal velocity is modified
	velocity.y = 0
	var input = Input.get_vector("left", "right", "forward", "back")
	var dir = Vector3(input.x, 0, input.y).rotated(Vector3.UP, camera.rotation.y)
	if can_move() && dir.length()>0:
		velocity = lerp(velocity, dir * speed, acceleration * delta)
	elif velocity.x != 0 or velocity.z != 0:
		apply_friction(delta, FRICTION)
	
	velocity.y = vy
	# Update animation blend position based on velocity
	var vl = velocity * model.transform.basis
	if velocity.length() > speed_threshold * 2: 
		vl = velocity * model.transform.basis * 2
	
	# Change movement animation speed
	if anim_state.get_current_node() == "IWR":
		anim_tree.set("parameters/TimeScale/scale", speed / speed_threshold)
	else:  anim_tree.set("parameters/TimeScale/scale", 1)
	anim_tree.set("parameters/AnimationNodeStateMachine/IWR/blend_position", Vector2(vl.x, -vl.z) / speed)

func apply_friction(delta,friction):
	friction *= 0.5
	velocity.x = lerp(velocity.x, 0.0, friction * base_friction_multiplier * delta)
	velocity.z = lerp(velocity.z, 0.0, friction * base_friction_multiplier * delta)

func handle_rotation(space,_delta):
	var query = PhysicsRayQueryParameters3D.create(rayOrigin, rayEnd, 0b00000000000000000100)
	var intersection = space.intersect_ray(query)
	
	# Character Rotation
	if not intersection.is_empty():
		var pos = intersection.position
		model.look_at(Vector3(pos.x, position.y, pos.z), Vector3.UP)
	
	# Smooth rotation using rotation_speed
	#if velocity.length() > 0.0:
		#model.rotation.y = lerp_angle(model.rotation.y, camera.rotation.y, rotation_speed * delta)

func _input(event):
	if event.is_action_pressed("attack"):
		anim_state.travel(attacks.pick_random())
		attacking = true
	if event.is_action_pressed("block"): # Blocking
		anim_tree.set("parameters/AnimationNodeStateMachine/conditions/blocking", true)
		blocking = true
	if event.is_action_released("block"):
		anim_tree.set("parameters/AnimationNodeStateMachine/conditions/blocking", false)
		blocking = false

func can_move():
	return !(blocking)

func set_camera():
	camera.position.y = 12.5

func change_anim_parameters():
	if is_on_floor() and not last_floor:
		jumping = false
		#if velocity.length() > 1.0:
		#anim_tree.set("parameters/conditions/jumping", false)
		anim_tree.set("parameters/AnimationNodeStateMachine/conditions/grounded", true)
	if not is_on_floor() and not jumping:
		# Check animation tree state machine for conditions
		anim_tree.set("parameters/AnimationNodeStateMachine/conditions/grounded", false)
	# Check if player is still on floor (before next frame)
	last_floor = is_on_floor()

func _on_animation_finished(_anim):
	if attacking: 
		attacking = false
