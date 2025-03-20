extends CharacterBody3D
class_name EnemyCharacter

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export_group("Movement")
@export var speed = 5.0
@export var acceleration = 4.0
#@export var jump_speed = 8.0

@export_group("Friction")
@export_range(0,1) var FRICTION: float = 1
var base_friction_multiplier = 10

@export_group("Stats")
@export_range(0,100) var health : int = 100

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

@onready var model = $Rig
@onready var anim_player = $AnimationPlayer
@onready var anim_tree = $AnimationTree
@onready var anim_state : AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/AnimationNodeStateMachine/playback")
#@onready var healthbar = $PlayerUi/HealthBar

var attacking = false
var blocking = false

func _ready():
	anim_tree.animation_finished.connect(_on_animation_finished)
	#healthbar.init_health(health)

func _physics_process(delta):
	# Movement Stuff
	velocity += get_gravity() * delta
	get_move_input(delta)
	move_and_slide()
	change_anim_parameters()
	#update_ui()

func get_move_input(delta):
	var vy = velocity.y # Preserve vertical velocity while horizontal velocity is modified
	velocity.y = 0
	var input = Input.get_vector("left", "right", "forward", "back")
	var dir = Vector3(input.x, 0, input.y).rotated(Vector3.UP, model.rotation.y)
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
	if anim_state and anim_state.get_current_node() == "IWR":
		anim_tree.set("parameters/TimeScale/scale", speed / speed_threshold)
	else:  anim_tree.set("parameters/TimeScale/scale", 1)
	anim_tree.set("parameters/AnimationNodeStateMachine/IWR/blend_position", Vector2(vl.x, -vl.z) / speed)

func apply_friction(delta,friction):
	friction *= 0.5
	velocity.x = lerp(velocity.x, 0.0, friction * base_friction_multiplier * delta)
	velocity.z = lerp(velocity.z, 0.0, friction * base_friction_multiplier * delta)

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

func can_move():
	return !(blocking)

func _on_animation_finished(_anim):
	if attacking: 
		attacking = false
