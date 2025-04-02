extends CharacterBody3D
class_name EnemyCharacter

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

enum States {INACTIVE = 0,IDLE = 1,CHASE = 2, ATTACK = 3, DEFEATED = 4}
var state = States.INACTIVE : 
	set(val):
		state = val
		match state:
			1: check_pathfinding()
			_: pass

@export_group("Movement")
@export var speed = 5.0
@export var acceleration = 4.0
@export var min_attack_distance = 2.5  # Closest distance enemy can move toward target
@export var max_attack_distance = 5.0  # Furthest distance enemy can move toward target
@export_range(0,10) var rotation_speed : float = 5.0
#@export var jump_speed = 8.0

@export_group("Friction")
@export_range(0,1) var FRICTION: float = 1
var base_friction_multiplier = 10

@export_group("Attacking")
@export_range(0.1,10.0) var attack_cooldown : float = 0.25
@export_range(0.1,10.0) var combo_cooldown : float = 1.0
@export_range(1,10) var combo_length : int = 3
@export var exclude_enemies : bool = true
var combo_over : bool = true
var combo_count : int = 0
var attack_cooldown_elapsed := 0.0
var combo_cooldown_elapsed := 0.0

@export_group("Stats")
@export_range(0,100) var health : int = 100

var speed_threshold = 5.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false
var last_floor = true
var attacks = [
	#"1H_Melee_Attack_Slice_Horizontal",
	#"1H_Melee_Attack_Slice_Diagonal",
	"1H_Melee_Attack_Chop"
]
var rayOrigin = Vector3()
var rayEnd = Vector3()

# Node References
@onready var nav_agent : NavigationAgent3D = $NavigationAgent3D
@onready var model = $Rig
@onready var anim_player : AnimationPlayer = $AnimationPlayer
@onready var anim_tree : AnimationTree = $AnimationTree
@onready var anim_state : AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/AnimationNodeStateMachine/playback")
@onready var healthbar = $EnemyUi/HealthBar

#Detection variables
var target
var player_pos

# When player enters detection area, skeleton will rise
var wake_up = false

# Navigation Region 3d Pathfinding
var nav_pathfinding_enabled : bool = false

# Action variables
var attacking = false
var blocking = false

# For healthbar positioning
var camera: Camera3D

var defeated : bool = false

func _ready():
	anim_tree.animation_finished.connect(_on_animation_finished)
	healthbar.init_health(health)
	camera = get_viewport().get_camera_3d()

func check_pathfinding():
	if owner.is_in_group("Level"):
		var level := owner
		# Make sure navigation region is acive before state transition
		if level.nav_region and level.nav_region.navigation_mesh: 
			var mesh_data = level.nav_region.navigation_mesh
			if mesh_data.get_polygon_count() > 0:
				nav_pathfinding_enabled = true
			else:
				nav_pathfinding_enabled = false
				printerr(level.nav_region.navigation_mesh," is NOT baked. Enemy pathfinding disabled")

func _process(_delta: float) -> void:
	if camera != null: update_floating_healthbar()

func update_floating_healthbar():
	var screen_pos = camera.unproject_position(self.global_position + Vector3(0, 4, 0))
	$EnemyUi/HealthBar.global_position = screen_pos 
	$EnemyUi/HealthBar.global_position += Vector2(-$EnemyUi/HealthBar.size.x / 2, 0)

func _physics_process(delta):
	# Movement Stuff
	velocity += get_gravity() * delta
	state_transitions()
	state_actions(delta)
	player_collision_scan(delta)
	move_and_slide()
	change_anim_parameters()
	#update_ui()

func state_transitions() -> void:
	if is_on_floor():
		if wake_up and state == States.INACTIVE:
			if anim_state and anim_state.get_current_node() == "IWR":
				state = States.IDLE
		if target and state == States.IDLE and nav_pathfinding_enabled: 
			# Check animation before
			if anim_state and anim_state.get_current_node() == "IWR":
				state = States.CHASE
		if player_pos and state == States.CHASE:
			var distance_to_player = self.position.distance_to(player_pos)
			if distance_to_player >= min_attack_distance and \
			distance_to_player <= max_attack_distance:
				state = States.ATTACK
			else: pass

func state_actions(delta_time):
	match state:
		0: pass
		1: pass
		2:
			target_position() # Update NavigationAgent with player position
			handle_movement(delta_time)
		3: 
			target_position()
			handle_movement(delta_time)
			handle_attack(delta_time)
		4: pass

func handle_movement(delta):
	# Retrieve next path position from NavigationRegion3D (AI pathfinding node)
	var next_loc = nav_agent.get_next_path_position()
	var cur = global_transform.origin
	
	var vy = velocity.y # Preserve vertical velocity while horizontal velocity is modified
	velocity.y = 0
	if player_pos:
		var distance_to_player = self.global_transform.origin.distance_to(player_pos)
		if distance_to_player > min_attack_distance and can_move():
			var dir := (next_loc - cur).normalized()
			velocity = lerp(velocity, dir * SPEED, acceleration * delta)
		else: 
			velocity = lerp(velocity, Vector3(0,velocity.y,0), acceleration * delta)
	
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

func target_position():
	if player_pos: nav_agent.target_position = player_pos

# Enemy attacks after attack cooldown ends
# Each attack adds one combo_count
# When enemy exceeds combo length (ex: 3) stop attacking for a couple seconds
# Repeat
func handle_attack(delta):
	if combo_over:
		if combo_cooldown_elapsed > combo_cooldown: 
			combo_count = 0
			combo_cooldown_elapsed = 0.0
			attack_cooldown_elapsed = 0.0
			combo_over = false
		elif anim_state.get_current_node() == "IWR": combo_cooldown_elapsed += delta
	if attack_cooldown_elapsed > attack_cooldown and !combo_over:
		if combo_count >= combo_length: 
			combo_over = true
			return
		if anim_state.get_current_node() == "IWR":
			#print("Attack ", target.name, " ", combo_count)
			anim_state.travel(attacks.pick_random())
			attacking = true
			attack_cooldown_elapsed = 0.0
			combo_count += 1
	else: 
		attacking = false
		if anim_state.get_current_node() == "IWR": attack_cooldown_elapsed += delta


func player_collision_scan(delta):
	var collisions = $detection_area.get_overlapping_bodies()
	if state != States.INACTIVE and target:
		if !collisions.is_empty():
			for col in collisions:
				if col.is_in_group("Player"): player_pos = col.global_transform.origin
		$ScanRaycast.look_at(player_pos, Vector3.UP)
		$ScanRaycast.force_raycast_update()
		if $ScanRaycast.is_colliding():
			var collider = $ScanRaycast.get_collider()
			if collider.is_in_group("Player"):
				var direction_to_target = (player_pos - self.global_transform.origin).normalized()
				var dir_rotation = atan2(direction_to_target.x, direction_to_target.z)
				
				# Switched to lerp_angle - Stops rotation snapping
				self.rotation.y = lerp_angle(self.rotation.y, dir_rotation, delta * rotation_speed)
				#self.rotation.y = dir_rotation
			else:
				$ScanRaycast.debug_shape_custom_color = Color(0,225,0)
				var new_basis = self.global_transform.basis
				var target_rotation = deg_to_rad(self.rotation_degrees.y)  # Or some other target rotation
				new_basis = Basis().rotated(Vector3.UP, target_rotation)
				self.global_transform.basis = new_basis

func apply_friction(delta,friction):
	friction *= 0.5
	velocity.x = lerp(velocity.x, 0.0, friction * base_friction_multiplier * delta)
	velocity.z = lerp(velocity.z, 0.0, friction * base_friction_multiplier * delta)

func take_damage(damage):
	healthbar._set_health(health - damage)
	health -= damage

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
	return !(blocking || defeated)

func _on_defeat():
	defeated = true
	set_process(false)
	set_physics_process(false)
	#var cur_module = self.modulate
	#var tween = create_tween()
	#tween.set_trans(Tween.TRANS_LINEAR)
	#tween.set_ease(Tween.EASE_IN_OUT)
	## Animate the modulate property to a fully transparent color (Alpha = 0)
	#tween.tween_property(self, "modulate", Color(cur_module.r, cur_module.g, cur_module.b, 0), 2.0)
	await get_tree().create_timer(2.0).timeout
	if anim_state.get_current_node() == "Death_A": 
		queue_free()

func _on_animation_finished(_anim):
	if attacking: 
		attacking = false

func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if is_on_floor() and state == States.INACTIVE: wake_up = true
		if !healthbar.visible: 
			update_floating_healthbar()
			healthbar.show()

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player") and target:
		target = null
		if body==target: 
			update_floating_healthbar()
			healthbar.hide()

func _on_attack_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and target == null:
		target = body

func _on_attack_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player") and target:
		target = null

func _on_detection_scan_timeout() -> void:
	if state == States.INACTIVE:
		var collisions = $detection_area.get_overlapping_bodies()
		if !collisions.is_empty():
			for col in collisions:
				if col.is_in_group("Player"): 
					wake_up = true
					return
