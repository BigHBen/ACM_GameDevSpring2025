extends CharacterBody3D
class_name PlayerCharacter


enum PlayerType { KNIGHT, BARBARIAN, ROGUE, MAGE }
@export var player_type: PlayerType = PlayerType.KNIGHT
@export var player_data : PlayerData

#@onready var PLAYER_DATA_TYPES : Dictionary = {
	#PlayerType.KNIGHT : preload("res://Resources/Player_Data/Knight.tres"),
	#PlayerType.BARBARIAN : preload("res://Resources/Player_Data/Barbarian.tres"),
	#PlayerType.ROGUE : preload("res://Resources/Player_Data/Rogue.tres"),
	#PlayerType.MAGE : preload("res://Resources/Player_Data/Mage.tres"),
#} 

@export var CONTROLLER : bool = false
@export_group("Movement")
@export var speed = 5.0
@export var acceleration = 4.0
#@export var jump_speed = 8.0

@export_group("Friction")
@export_range(0,1) var FRICTION: float = 1
var base_friction_multiplier = 10

@export_group("Attacking")
@export_range(0,3) var max_block_time : float = 1.0
@export_range(0,3) var max_charge_time : float = 2.0
@export_range(0,1) var block_damage_multiplier: float = 0.5
@export_range(0.1,10.0) var combo_cooldown : float = 0.5
@export_range(1,10) var combo_length : int = 3
var combo_over : bool = true
var combo_count : int = 0
var attack_cooldown_elapsed := 0.0
var combo_cooldown_elapsed := 0.0
var attack_reset_threshold = 0.5 # seconds before reset if no attack
var attack_reset_elapsed = 0.0


# Armor classes - More damage reduction
var block_multipliers = {
	"default": 1.0, # No blocking
	"gold": 0.75,  
	"diamond": 0.5
}

@export_group("Stats")
@export_range(0,100) var health : int = 100

@export_group("Camera")
#@export var mouse_sensitivity = 0.0015
@export var rotation_speed = 12.0


#@export var something1 = 0.0 # Debug testing
#@export var something2 = 0.0

var speed_threshold = 5.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var jumping = false
var last_floor = true
var attacks : Array[String] = []
var hit_animations = ["Hit_A","Hit_B"]
var rayOrigin = Vector3()
var rayEnd = Vector3()

# Node References
@onready var model = $Rig
@onready var anim_player = $AnimationPlayer
@onready var anim_tree : AnimationTree = $AnimationTree
@onready var anim_state : AnimationNodeStateMachinePlayback = $AnimationTree.get("parameters/AnimationNodeStateMachine/playback")
@onready var camera = $CameraPivot/SpringArm3D/Camera3D
@onready var spring_arm : SpringArm3D = $CameraPivot/SpringArm3D

# Player UI
@onready var player_ui = $PlayerUi
@onready var healthbar = $PlayerUi/HealthBar
@onready var healthbar2 = $PlayerUi/FloatingNamePanel/HealthBar2
@onready var name_label : Label = $PlayerUi/PlayerName
@onready var name_label2 : Label = $PlayerUi/FloatingNamePanel/PlayerName2

# Player meshes (for armor mainly)
@onready var helm_mesh : MeshInstance3D
@onready var chest_mesh : MeshInstance3D

# Effects
@onready var p_effects : Node3D = $EffectsManager
@onready var trail : MeshInstance3D
@onready var trail_effects_anim : AnimationPlayer

# Inventory Controller node
@onready var p_inv_controller : Node3D = $InventoryController

# Interactions (NPCs and Dialogue)
@onready var interact : Area3D = $Interact
@onready var interact_manager : PlayerInteractManager = $PlayerUi/InteractionsManager

# Multiplayer Lobby
@onready var lobby : Lobby = get_node("/root/MultiplayerLobby")

# Player specific nodes
var projectile_launcher : ProjectileLauncher = null # For Rogue and Mage (shoot arrows and spells)

var attacking = false

var blocking = false : set = set_block_state
var stop_block = false
var hit : bool = false
signal took_damage(damage)

var charging = false : set = set_charge_state
var stop_charge = false

# Item/ Currency Variables
var moneyAmount : int = 0
var potionAmount : int = 1

var defeated : bool = false

var camera_viewport : Camera3D

# Multiplayer
var nickname : String
var ping_time : float = 2.0
var ping_timer : float = 0.0
var enter_location : Vector3 = Vector3.ZERO :
	set (val):
		enter_location = val

var game_root

var show_player_ui : bool = false

func _enter_tree() -> void:
	
	# Remove test player that's in level by default
	if get_parent() is not GameManager and get_parent() is not GameManagerMultiplayer:
		if get_tree().current_scene.is_in_group("Level"): pass
		else: 
			self.queue_free()
	
	if get_tree().current_scene is GameManagerMultiplayer:
		set_multiplayer_authority(self.name.to_int())

@rpc("call_local")
func creation_animation():
	if anim_state:
		anim_state.travel("Sit_Floor_StandUp")
	model.scale = Vector3.ONE/8 # Item reveal tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(model, "scale", Vector3.ONE, 0.25)

#@rpc("any_peer","call_local")
func update_player_despawn(_id):
	#print(self.name)
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(model, "scale", Vector3.ONE/8, 0.25)
	await tween.finished
	queue_free()

func _ready():
	
	player_type_setup()
	
	anim_tree.animation_finished.connect(_on_animation_finished)
	healthbar.init_health(health)
	healthbar2.init_health(health)
	
	# Multiplayer startup functions
	if !multiplayer_startup(): return
	
	
	camera.current = true
	set_camera()

func initialize(val):
	show_player_ui = val

func single_player_startup():
	if get_tree().current_scene is GameManager:
		game_root = get_tree().current_scene

func multiplayer_startup():
	if get_tree().current_scene is GameManagerMultiplayer:
		game_root = get_tree().current_scene
		
		self.process_mode = Node.PROCESS_MODE_PAUSABLE
		
		if not is_multiplayer_authority(): 
			#lobby.player_disconnected.connect(update_player_despawn)
			
			#if multiplayer.get_unique_id() in GameManagerMultiplayer.get_active_players_multiplayer():
				## Hide all children except floating healthbar
				#for child in player_ui.get_children():
					#if child.name == "FloatingNamePanel": 
						#child.show()
						#continue
					#child.hide()
			#else:
				# Hide all player ui children except floating healthbar
			for child in player_ui.get_children():
				if child.name == "FloatingNamePanel": 
					child.show()
					continue
				child.hide()
			
			#trail_effects_anim.active = false
			#trail.hide()
			return false
		
		
		if game_root.debug: game_root.debug.get_player_properties(self)
		
		#if game_root.get_node_or_null(str(game_root.peer_id)) == null: # Testing
			#printerr(game_root.peer_id, ": Missing Player, cannot run rpc functions of ",self)
			#return false
				
		# Set player label
		if !game_root.name_entry.text.is_empty():
			nickname = game_root.name_entry.text
			
			for id in GameManagerMultiplayer.get_active_players_multiplayer():
				change_name.rpc_id(id,nickname)
				if id != self.name.to_int(): change_floating_name.rpc_id(id,nickname)
		else: 
			for id in GameManagerMultiplayer.get_active_players_multiplayer():
				change_name.rpc_id(id,self.name)
				if id != self.name.to_int(): change_floating_name.rpc_id(id,self.name)
		
		randomize() # For randomized spawn points
		
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			update_spawn_position.rpc_id(id,null)
			creation_animation.rpc_id(id)
		update_current_camera()
	return true

# Move player to level-specific spawn location
@rpc("any_peer","call_local")
func update_spawn_position(new_level_pos=null): 
	if !is_multiplayer_authority(): return
	var game = get_tree().current_scene
	var random_x = randf_range(-0.5 , 0.5)
	var random_z = randf_range(-0.5 , 0.5)
	var spawn_pos 
	
	# Randomize spawn points slightly
	# Otherwise players collisions will cause physics issues
	if new_level_pos:
		spawn_pos = new_level_pos + Vector3(random_x, 0, random_z) 
		position = spawn_pos
	elif game.level_container.get_child_count() > 0: # Retrieve default spawn from level node
		var level = game.level_container.get_child(0)
		new_level_pos = level.player_spawn_point
		spawn_pos = new_level_pos + Vector3(random_x, 0, random_z) 
		position = spawn_pos
	#print("%s Moved to %s" % [self,spawn_pos])


func player_type_setup():
	# Player_Data entries contain default values for each player (Knight, Mage, etc)
	# Set player stats from Player_Data if mismatched
	if player_data: 
		var mismatched_fields := []
		if player_data.hp != self.health: mismatched_fields.append("health")
		if player_data.speed != self.speed: mismatched_fields.append("speed")
		if mismatched_fields.size() > 0:
			#printerr(self,": (PlayerData) Mismatched fields in player: %s" % ", ".join(mismatched_fields))
			self.health = player_data.hp
			self.speed = player_data.speed
			#print(self,": (PlayerData) Fixed mismatched fields: %s" % ", ".join(mismatched_fields))
			mismatched_fields.clear()
	match player_type:
		PlayerType.KNIGHT:
			#print("Knight time")
			helm_mesh = $Rig/Skeleton3D/Knight_Helmet/Knight_Helmet
			chest_mesh = $Rig/Skeleton3D/Knight_Body
			trail_effects_anim = $trail_anim_player
			trail = $"Rig/Skeleton3D/1H_Sword/Trail"
			attacks = ["1H_Melee_Attack_Slice_Horizontal",
			"1H_Melee_Attack_Slice_Diagonal",
			"1H_Melee_Attack_Chop"]
			combo_length = 3 # 3 hits per combo
		PlayerType.BARBARIAN:
			#print("Big Barbarian")
			helm_mesh = $Rig/Skeleton3D/Barbarian_Hat/Barbarian_Hat
			chest_mesh = $Rig/Skeleton3D/Barbarian_Body
			trail_effects_anim = $trail_anim_player
			trail = $"Rig/Skeleton3D/1H_Axe/Trail"
			attacks = ["1H_Melee_Attack_Slice_Horizontal",
			"1H_Melee_Attack_Slice_Diagonal",
			"1H_Melee_Attack_Chop"]
			combo_length = 4 
		PlayerType.ROGUE:
			#print("Rogue...")
			attacks = ["1H_Ranged_Shoot"]
			combo_length = 3
			projectile_launcher = $Rig/ProjectileLauncher
			projectile_launcher.configure_launcher(PlayerType.ROGUE)
		PlayerType.MAGE:
			#print("Mage Caster")
			attacks = ["Spellcast_Shoot"]
			combo_length = 2
			projectile_launcher = $Rig/ProjectileLauncher
			projectile_launcher.configure_launcher(PlayerType.MAGE)

func update_current_camera():
	camera_viewport = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	for id in GameManagerMultiplayer.get_active_players_multiplayer():
		if multiplayer.has_multiplayer_peer():
			update_floating_healthbar.rpc_id(id)
	#if camera_viewport != null: update_floating_healthbar.rpc()

@rpc("any_peer","call_local")
func update_floating_healthbar():
	if !multiplayer: return
	var screen_pos = get_viewport().get_camera_3d().unproject_position(self.global_position + Vector3(0, 4, 0))
	$PlayerUi/FloatingNamePanel.global_position = screen_pos 
	$PlayerUi/FloatingNamePanel.global_position += Vector2(-$PlayerUi/FloatingNamePanel.size.x / 2, 0)


# _Ready() runs once for both server and client
# Show which is running and player authority mode
func test_authority():
	if multiplayer.is_server():
		print("SERVER: Ready function: Player[%s] multiplayer authority: %s" % [self.name,is_multiplayer_authority()])
	else: print("CLIENT: Ready function: Player[%s] multiplayer authority: %s" % [self.name,is_multiplayer_authority()])

@rpc("call_local")
func change_name(val):
	#print("Changing name for ", val)
	name_label.text = val
	name_label2.text = val

@rpc("any_peer")
func change_floating_name(_val):
	var sender_id = multiplayer.get_remote_sender_id()
	name_label2.text = str(sender_id)

# Movement is HEAVILY modified code from KidsCanCode
# https://www.youtube.com/@Kidscancode/featured

# Look at Cursor Provided from Nolkaloid and edited to fit Godot 4
# https://www.youtube.com/watch?v=mmvIkkKJVlQ
func _physics_process(delta):
	if not is_multiplayer_authority(): return
	
	client_functions(delta)
	# The Final Value sets what collision mask the ray is on.
	# The default value is on every collision mask
	# The value is a bitmask. The current value inserted is for collision mask 3.
	# What this means is that ray will only collide with objects on layer 3. (Like the world border)
	# Or that's what I could tell from the docs and random threads on the internet
	# Collision layer vs mask: https://gamedev.stackexchange.com/questions/185178/whats-the-difference-between-collision-layers-and-collision-masks
	# How to set .create bitmask value: https://www.reddit.com/r/godot/comments/mai6fa/exclude_parameter_in_intersect_raywhat_does_it_do/
	handle_rotation(delta)
	handle_combo_cooldown(delta)
	# Movement Stuff
	velocity += get_gravity() * delta
	get_move_input(delta)
	move_and_slide()
	change_anim_parameters()
	if game_root: 
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			update_ui.rpc_id(id)
	else: update_ui()
	

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
	if game_root: 
		#print(self.name,": ",GameManagerMultiplayer.get_active_players_multiplayer())
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			if multiplayer.has_multiplayer_peer():
				update_input_animations.rpc_id(id,vl)
	else: update_input_animations(vl)

@rpc("call_local")
func update_input_animations(vel_to_blend):
	#print(multiplayer.get_unique_id()," - ",GameManagerMultiplayer.get_active_players_multiplayer().size())
	var vl = vel_to_blend
	# Change movement animation speed
	if anim_state and anim_state.get_current_node() == "IWR":
		anim_tree.set("parameters/TimeScale/scale", speed / speed_threshold)
	else:  anim_tree.set("parameters/TimeScale/scale", 1)
	anim_tree.set("parameters/AnimationNodeStateMachine/IWR/blend_position", Vector2(vl.x, -vl.z) / speed)

func apply_friction(delta,friction):
	friction *= 0.5
	velocity.x = lerp(velocity.x, 0.0, friction * base_friction_multiplier * delta)
	velocity.z = lerp(velocity.z, 0.0, friction * base_friction_multiplier * delta)

func handle_rotation(_delta):
	
	# Variables
		# Get Current Physics State
	var space_state = get_world_3d().direct_space_state
		# Get Current Mouse Position in the Viewport
	var mouse_position = get_viewport().get_mouse_position()
	rayOrigin =  camera.project_ray_origin(mouse_position) # Set ray origin
	rayEnd = rayOrigin + camera.project_ray_normal(mouse_position) * 2000 # set ray end point

	var query = PhysicsRayQueryParameters3D.create(rayOrigin, rayEnd, 0b00000000000000000100)
	var intersection = space_state.intersect_ray(query)
	
	# Controller Input
	var controller_right_input = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var controller_3d_rot = Vector3(controller_right_input.x, position.y, controller_right_input.y)
	controller_3d_rot = controller_3d_rot.normalized()
	
	var target_position = model.global_transform.origin + controller_3d_rot
	target_position.y = model.global_transform.origin.y
	var direction = (target_position - model.global_transform.origin).normalized()
	if can_move() or blocking or charging:
		if CONTROLLER:
			if controller_right_input != Vector2.ZERO: # Character Controller Rotation
				var target_rotation = Transform3D.IDENTITY.looking_at(direction, Vector3.UP).basis.get_euler()
				var _angle_diff = model.rotation.angle_to(target_rotation)
				
				model.rotation.y = lerp_angle(model.rotation.y, target_rotation.y, 0.1)
				$"Hit_Hurt Boxes".rotation.y = lerp_angle($"Hit_Hurt Boxes".rotation.y, target_rotation.y, 0.1)
		else:
			if not intersection.is_empty(): # Character Mouse Rotation
				var pos = intersection.position
				model.look_at(Vector3(pos.x, position.y, pos.z), Vector3.UP)
				$"Hit_Hurt Boxes".look_at(Vector3(pos.x, position.y, pos.z), Vector3.UP)
	
	# Smooth rotation using rotation_speed
	#if velocity.length() > 0.0:
		#model.rotation.y = lerp_angle(model.rotation.y, camera.rotation.y, rotation_speed * delta)

func handle_attack():
	if hit or defeated: return
	if anim_state.get_current_node() == "IWR":
		#print("Combo Count: ",combo_count)
		if combo_over: return
		var attack = attacks.pick_random()
		attacking = true
		if game_root: 
			for id in GameManagerMultiplayer.get_active_players_multiplayer():
				attack_animations.rpc_id(id,attack)
		else: attack_animations(attack)
		combo_count += 1
		attack_reset_elapsed = 0.0
		if combo_count >= combo_length: 
			combo_over = true
			return

@rpc("call_local")
func attack_animations(anim):
	anim_state.travel(anim)
	var use_sword_effects = (player_type == PlayerType.KNIGHT or player_type == PlayerType.BARBARIAN)
	if player_type == PlayerType.ROGUE:
		rogue_shoot(anim)
		return
	elif player_type == PlayerType.MAGE:
		mage_spellcast(anim)
		return
	match attacks.find(anim):
		0: # Horizontal
			await get_tree().create_timer(0.2).timeout
			if use_sword_effects: update_sword_effects(true)
			$"Hit_Hurt Boxes/HitBox1/CollisionShape3D".disabled = false
			await get_tree().create_timer(0.2).timeout
			$"Hit_Hurt Boxes/HitBox1/CollisionShape3D".disabled = true
		1: # Diagonal
			await get_tree().create_timer(0.4).timeout
			if use_sword_effects: update_sword_effects(true)
			$"Hit_Hurt Boxes/HitBox1/CollisionShape3D".disabled = false
			await get_tree().create_timer(0.2).timeout
			$"Hit_Hurt Boxes/HitBox1/CollisionShape3D".disabled = true
		2: # Chop
			await get_tree().create_timer(0.5).timeout
			if use_sword_effects: update_sword_effects(true)
			$"Hit_Hurt Boxes/HitBox1/CollisionShape3D".disabled = false
			await get_tree().create_timer(0.3).timeout
			$"Hit_Hurt Boxes/HitBox1/CollisionShape3D".disabled = true

func rogue_shoot(_anim):
	if projectile_launcher:
		await get_tree().create_timer(0.3).timeout
		projectile_launcher.fire()

func mage_spellcast(_anim):
	if projectile_launcher:
		await get_tree().create_timer(0.225).timeout
		projectile_launcher.fire()

#@rpc("any_peer")
func update_sword_effects(in_progress : bool): # Sync sword trail animation
	if in_progress:
		trail_effects_anim.play("new_animation")

func handle_combo_cooldown(delta):
	if combo_over:
		#print("Attack Cooldown: %s ..." % [combo_cooldown_elapsed])
		if combo_cooldown_elapsed > combo_cooldown: 
			combo_count = 0
			combo_cooldown_elapsed = 0.0
			combo_over = false
		else: combo_cooldown_elapsed += delta
	elif attack_reset_elapsed > attack_reset_threshold:
		#print("Combo Count Reset")
		combo_count = 0
		attack_reset_elapsed = 0.0
	elif anim_state.get_current_node() =="IWR" and combo_count > 0: attack_reset_elapsed += delta

func handle_block():
	var block_timer : float = 0.0
	
	blocking = true
	while Input.is_action_pressed("block") and block_timer < max_block_time:
		#_set_animation_state_params.rpc("parameters/AnimationNodeStateMachine/conditions/blocking", true)
		block_timer += get_process_delta_time()
		await get_tree().process_frame
	#_set_animation_state_params.rpc("parameters/AnimationNodeStateMachine/conditions/blocking", false)
	blocking = false

func handle_charge():
	var charge_timer : float = 0.0
	
	charging = true
	while Input.is_action_pressed("block") and charge_timer < max_charge_time:
		#_set_animation_state_params.rpc("parameters/AnimationNodeStateMachine/conditions/blocking", true)
		charge_timer += get_process_delta_time()
		await get_tree().process_frame
	#_set_animation_state_params.rpc("parameters/AnimationNodeStateMachine/conditions/blocking", false)
	charging = false

func set_block_state(state):
	blocking = state
	if game_root: 
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			_set_animation_state_params.rpc_id(id,"parameters/AnimationNodeStateMachine/conditions/blocking", state)
	else: _set_animation_state_params("parameters/AnimationNodeStateMachine/conditions/blocking", state)
	# Transition back to Idle
	if game_root: 
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			_set_animation_state_params.rpc_id(id,"parameters/AnimationNodeStateMachine/conditions/stop_block", !state)
	else: _set_animation_state_params("parameters/AnimationNodeStateMachine/conditions/stop_block", !state)

func set_charge_state(state):
	charging = state
	if game_root: 
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			_set_animation_state_params.rpc_id(id,"parameters/AnimationNodeStateMachine/conditions/charging", state)
	else: _set_animation_state_params("parameters/AnimationNodeStateMachine/conditions/charging", state)
	# Transition back to Idle
	if game_root: 
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			_set_animation_state_params.rpc_id(id,"parameters/AnimationNodeStateMachine/conditions/stop_charge", !state)
	else: _set_animation_state_params("parameters/AnimationNodeStateMachine/conditions/stop_charge", !state)

@rpc("call_local")
func _set_animation_state_params(params,val):
	anim_tree.set(params,val)

func _input(event):
	if not is_multiplayer_authority() or not can_move(): return
	if event.is_action_pressed("attack") and can_attack():
		handle_attack()
	if event.is_action_pressed("block") and can_block(): # Block or Charge
		if player_type == PlayerType.BARBARIAN or player_type == PlayerType.ROGUE or \
		player_type == PlayerType.MAGE: handle_charge()
		else: handle_block()
	if event.is_action_released("block"):
		if game_root: _set_animation_state_params("parameters/AnimationNodeStateMachine/conditions/blocking", false)
		else: _set_animation_state_params("parameters/AnimationNodeStateMachine/conditions/blocking", false)
		blocking = false

func can_move():
	if get_tree().current_scene is GameManager or get_tree().current_scene is GameManagerMultiplayer:
		if get_tree().current_scene.game_paused: return false
	return !(blocking or charging or defeated or p_effects.item_consuming)

func can_attack():
	return !(p_inv_controller.inventory.window.visible)

func can_block():
	return !(p_inv_controller.inventory.window.visible)

func set_camera():
	spring_arm.position.y = 12.5
	spring_arm.position.z = -4

func change_anim_parameters():
	#update_animations.rpc()
	if is_on_floor() and not last_floor:
		jumping = false
		#if velocity.length() > 1.0:
		#anim_tree.set("parameters/conditions/jumping", false)
		if game_root: 
			for id in GameManagerMultiplayer.get_active_players_multiplayer():
				_set_animation_state_params.rpc_id(id,"parameters/AnimationNodeStateMachine/conditions/grounded", true)
		else: _set_animation_state_params("parameters/AnimationNodeStateMachine/conditions/grounded", true)
	if not is_on_floor() and not jumping:
		# Check animation tree state machine for conditions
		if game_root: 
			for id in GameManagerMultiplayer.get_active_players_multiplayer():
				_set_animation_state_params.rpc_id(id,"parameters/AnimationNodeStateMachine/conditions/grounded", false)
		else: _set_animation_state_params("parameters/AnimationNodeStateMachine/conditions/grounded", false)
	# Check if player is still on floor (before next frame)
	last_floor = is_on_floor()

#@rpc("any_peer", "call_remote")
#func update_animations():
	#pass
	#anim_player.play(anim_state.get_current_node().animation)

@rpc("call_local")
func take_damage(damage):
	#print($Rig/Skeleton3D/Knight_Head.get("surface_material_override/0"))
	var armor_reduction = 1.0
	match p_effects.current_armor:
		0: armor_reduction = block_multipliers["default"]
		1: armor_reduction = block_multipliers["gold"]
		2: armor_reduction = block_multipliers["diamond"]
	if blocking: damage *= block_damage_multiplier
	elif is_multiplayer_authority(): 
		
		if attacks.has(anim_state.get_current_node()):
			anim_tree.active = false # Reset animation tree -> Interrupts any current animation
			anim_tree.active = true
			if game_root: 
				for id in GameManagerMultiplayer.get_active_players_multiplayer():
					update_damage_anim.rpc_id(id,true)
			else: update_damage_anim(true)
		else: 
			if game_root: 
				for id in GameManagerMultiplayer.get_active_players_multiplayer():
					update_damage_anim.rpc_id(id,false)
			else: update_damage_anim(false)
	
	#print(self, " taking %s damage" % [(damage * armor_reduction)])
	healthbar._set_health(health - (damage * armor_reduction))
	healthbar2._set_health(health - (damage * armor_reduction))
	health -= damage
	took_damage.emit(damage * armor_reduction)
	
	if is_multiplayer_authority():
		var tween = create_tween()
		tween.tween_property(healthbar2.damagebar, "value", healthbar2.health, 1).from(healthbar2.damagebar.value)
	hit = true

@rpc("call_local")
func update_damage_anim(from_abort):
	if from_abort: anim_state.start(hit_animations.pick_random()) # After resetting anim_tree -> skip to player hit animation
	else: anim_state.travel(hit_animations.pick_random()) # Animations
	
func _on_defeat():
	defeated = true
	set_physics_process(false)
	
	if get_tree().current_scene is GameManager or get_tree().current_scene is GameManagerMultiplayer:
		game_root = get_tree().current_scene
	
	if get_tree().current_scene is GameManagerMultiplayer: # Multiplayer Section
		if not is_multiplayer_authority(): return
		death_animation()
		for id in GameManagerMultiplayer.get_active_players_multiplayer():
			death_animation.rpc_id(id)
	else: # Singleplayer Section
		death_animation()
	
	await get_tree().create_timer(2.0).timeout
	if anim_state.get_current_node() == "Death_A": 
		set_process(false)
		camera.current = false
		
		if get_tree().current_scene is GameManagerMultiplayer: # Multiplayer Section
			var _peer_id = multiplayer.get_unique_id()
			#for id in GameManagerMultiplayer.get_active_players_multiplayer():
				#if id != peer_id: delete_player.rpc_id(id)
			game_root.player_defeat = [self,true] # For game over screen
			#delete_player()
		else: # Singleplayer Section
			game_root.player_defeat = [self,true] # For game over screen
			delete_player()

#@rpc("any_peer","call_local")
func delete_player():
	# Disable multiplayersyncronizer
		if self.name.to_int() == multiplayer.get_unique_id():
			$PlayerInputSynchronizer.public_visibility = false
		#$"Hit_Hurt Boxes/HitBox1".monitoring = false
		#$"Hit_Hurt Boxes/HurtBox".monitoring = false
		#$"Hit_Hurt Boxes/HitBox1".monitorable = false
		#$"Hit_Hurt Boxes/HurtBox".monitorable = false
		#Server has to queue_free() to avoid debug error
		if !multiplayer.is_server() or !is_multiplayer_authority(): return
		queue_free()

@rpc("call_local")
func death_animation():
	anim_state.travel("Death_A")

func pause_anim_tree():
	anim_tree.active = false
func play_anim_tree():
	anim_tree.active = true

func client_functions(delta): 
	if multiplayer.is_server(): return
	# For now, just check ping time every few seconds
	if ping_timer > ping_time:
		lobby.do_ping()
		ping_timer = 0.0
	else: 
		ping_timer += delta
	

func _on_animation_finished(_anim):
	if attacking: 
		attacking = false
		$"Hit_Hurt Boxes/HitBox1/CollisionShape3D".disabled = true
	if hit: hit = false

@rpc("call_local")
func update_ui() -> void:
	$PlayerUi/Coins/Label.text = str(moneyAmount)
	$PlayerUi/Potions/Label.text = str(potionAmount)
