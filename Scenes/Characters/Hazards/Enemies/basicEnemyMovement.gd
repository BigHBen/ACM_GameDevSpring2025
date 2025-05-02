extends CharacterBody3D
class_name EnemyCharacter

enum EnemyType { SKELETON_WARRIOR, SKELETON_MINION }
@export var enemy_type: EnemyType = EnemyType.SKELETON_WARRIOR
@export var enemy_data : EnemyData

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
@export var min_attack_distance = 1.5  # Closest distance enemy can move toward target
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
var combo_over : bool = false
var combo_count : int = 0
var attack_cooldown_elapsed := 0.0
var combo_cooldown_elapsed := 0.0

@export_group("Stats")
@export_range(0,100) var health : int = 100

var speed_threshold = 5.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false
var last_floor = true
var attacks = []
var hit_animations = ["Hit_A","Hit_B"]
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
var player_pos = Vector3.ZERO
var hit_from : Vector3 = Vector3.ZERO : set = set_hit_from # Stores position of outside hitboxes after hit
 
# When player enters detection area, skeleton will rise
var wake_up = false

# Navigation Region 3d Pathfinding
var nav_pathfinding_enabled : bool = false

# Action variables
var attacking = false
var blocking = false
var hit : bool = false

# For healthbar positioning
var camera: Camera3D

var defeated : bool = false

func _ready():
	randomize()
	enemy_type_setup()
	
	anim_tree.animation_finished.connect(_on_animation_finished)
	healthbar.init_health(health)
	update_current_camera()

func enemy_type_setup():
	# Enemy_Data entries contain default values for each enemy (Warrior, Minion, etc)
	# Set player stats from Player_Data if mismatched
	if enemy_data: 
		var mismatched_fields := []
		if enemy_data.hp != self.health: mismatched_fields.append("health")
		if enemy_data.speed != self.speed: mismatched_fields.append("speed")
		if mismatched_fields.size() > 0:
			#printerr(self,": (PlayerData) Mismatched fields in player: %s" % ", ".join(mismatched_fields))
			self.health = enemy_data.hp
			self.speed = enemy_data.speed
			#print(self,": (PlayerData) Fixed mismatched fields: %s" % ", ".join(mismatched_fields))
			mismatched_fields.clear()
		if healthbar != null and healthbar.get_child_count() > 0:
			if healthbar.get_children().back() is Label: 
				healthbar.get_children().back().text = enemy_data.display_name
	match enemy_type:
		EnemyType.SKELETON_WARRIOR:
			attacks = ["1H_Melee_Attack_Slice_Horizontal",
			"1H_Melee_Attack_Slice_Diagonal",
			"1H_Melee_Attack_Chop"]
			combo_length = 3 # 3 hits per combo
		EnemyType.SKELETON_MINION:
			attacks = ["Unarmed_Melee_Attack_Punch_A",
			"Unarmed_Melee_Attack_Punch_B",
			"Unarmed_Melee_Attack_Kick"]
			combo_length = 4 

func update_current_camera():
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
	if !camera or !camera.is_visible_in_tree(): 
		update_current_camera()
		return
	#if get_tree().current_scene.players.has(self): # Make sure player isnt deleted
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
		if state == States.ATTACK and (!target or target.defeated): # Switch to new target
			if $attack_area.has_overlapping_bodies(): 
				if $attack_area.get_overlapping_bodies().back().is_in_group("Player"):
					target = $attack_area.get_overlapping_bodies().back()
					#print("New Skele target: ",target)
				else: target = null
				state = States.IDLE

func state_actions(delta_time):
	match state:
		0: pass
		1:  
			handle_movement(delta_time)
			if hit_from != Vector3.ZERO: target_position() # If hit by projectile, find them
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
	if player_pos != Vector3.ZERO:
		var distance_to_player = self.global_transform.origin.distance_to(player_pos)
		if distance_to_player > min_attack_distance and can_move():
			var dir := (next_loc - cur).normalized()
			velocity = lerp(velocity, dir * SPEED, acceleration * delta)
		else: 
			velocity = lerp(velocity, Vector3(0,velocity.y,0), acceleration * delta)
	elif hit_from != Vector3.ZERO:
		var distance_to_player = self.global_transform.origin.distance_to(hit_from)
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
	elif hit_from != Vector3.ZERO: nav_agent.target_position = hit_from

# Enemy attacks after attack cooldown ends
# Each attack adds one combo_count
# When enemy exceeds combo length (ex: 3) stop attacking for a couple seconds
# Repeat
func handle_attack(delta):
	#if hit and !defeated: # abort attack combo if hit
		#if !combo_over: 
			#anim_tree.active = false
			#anim_tree.active = true
			#update_damage_anim.rpc(true)
		#combo_over = true
		#return
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
				if col.is_in_group("Player"): 
					var player : PlayerCharacter = col
					player_pos = player.global_transform.origin
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

func set_hit_from(val):
	hit_from = val

@rpc("call_local")
func take_damage(damage):
	healthbar._set_health(health - damage)
	health -= damage
	hit = true
	if is_multiplayer_authority(): 
		if attacks.has(anim_state.get_current_node()):
			anim_tree.active = false
			anim_tree.active = true
			update_damage_anim.rpc(true)
		else: update_damage_anim.rpc(false)

@rpc("call_local")
func update_damage_anim(from_abort):
	if from_abort: anim_state.start(hit_animations.pick_random())
	else: anim_state.travel(hit_animations.pick_random())

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
	anim_tree.active = false # Reset animation tree -> Interrupts any current animation
	anim_tree.active = true
	anim_state.start("Death_A") # Set to default animation node -> transition to death animation
	
	defeated = true
	set_physics_process(false)
	$"Hit_Hurt Boxes/HurtBox".set_deferred("monitorable", false)
	$"Hit_Hurt Boxes/HitBox1".set_deferred("monitorable", false)
	$"Hit_Hurt Boxes/HurtBox".set_deferred("monitoring", false)
	$"Hit_Hurt Boxes/HitBox1".set_deferred("monitoring", false)
	
	await get_tree().create_timer(2.0).timeout
	if anim_state.get_current_node() == "Death_A": 
		#camera.current = false
		set_process(false)
		set_deferred("process_mode", PROCESS_MODE_DISABLED)
		$Physics.set_deferred("disabled",true)
		$EnemyUi.hide()
		delete_enemy()
		delete_enemy.rpc()
		#queue_free()

@rpc("any_peer")
func delete_enemy():
	$MultiplayerSynchronizer.public_visibility = false
	#if multiplayer.is_server(): 
	#print("CLIENT: ",multiplayer.get_unique_id()," SKELE DEAD")
	#$MultiplayerSynchronizer.public_visibility = false

func _on_animation_finished(_anim):
	if attacking: 
		attacking = false

func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if is_on_floor() and state == States.INACTIVE: wake_up = true
		if !healthbar.visible: 
			update_current_camera()
			healthbar.show()

func _on_detection_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if target:
			target = null
			if body==target: 
				update_current_camera()
				healthbar.hide()

func _on_attack_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player") and target == null:
		target = body

func _on_attack_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player") and target:
		target = null
		player_pos = Vector3.ZERO

func _on_detection_scan_timeout() -> void:
	if state == States.INACTIVE:
		var collisions = $detection_area.get_overlapping_bodies()
		if !collisions.is_empty():
			for col in collisions:
				if col.is_in_group("Player"): 
					wake_up = true
					return
	if state == States.ATTACK:
		var collisions = $attack_area.get_overlapping_bodies()
		if !collisions.is_empty():
			for col in collisions:
				if col.is_in_group("Player"): 
					target = col

func _on_animation_tree_animation_finished(_anim_name: StringName) -> void:
	if hit: hit = false


func _on_navigation_agent_3d_navigation_finished() -> void:
	if player_pos != Vector3.ZERO: player_pos = Vector3.ZERO
	if hit_from != Vector3.ZERO: hit_from = Vector3.ZERO
