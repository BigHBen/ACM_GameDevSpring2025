class_name Enemy_Turret extends Node3D

@export_group("Detection")
@export_range(12.0,36.0) var detection_radius : float = 12.0

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
@onready var healthbar = $EnemyUi/HealthBar

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var target
var player_pos = Vector3.ZERO
var hit_from : Vector3 = Vector3.ZERO : set = set_hit_from # Stores position of outside hitboxes after hit
var defeated : bool = false

# Action variables
var attacking = false
var projectile_launcher : EnemyProjectileLauncher = null

# For healthbar positioning
var camera: Camera3D

func _ready():
	randomize()
	projectile_launcher = $ProjectileLauncher
	$detection_area/CollisionShape3D.shape.radius = detection_radius
	healthbar.init_health(health)
	update_current_camera()

func _process(_delta: float) -> void:
	if camera != null: update_floating_healthbar()

func _physics_process(delta: float) -> void:
	if target: handle_attack(delta)

func handle_attack(delta):
	if combo_over:
		if combo_cooldown_elapsed > combo_cooldown: 
			combo_count = 0
			combo_cooldown_elapsed = 0.0
			attack_cooldown_elapsed = 0.0
			combo_over = false
		elif !animation_player.is_playing(): combo_cooldown_elapsed += delta
	if attack_cooldown_elapsed > attack_cooldown and !combo_over:
		if combo_count >= combo_length: 
			combo_over = true
			return
		if !animation_player.is_playing():
			#print("Attack ", target.name, " ", combo_count)
			attack_animations()
			attacking = true
			attack_cooldown_elapsed = 0.0
			combo_count += 1
	else: 
		attacking = false
		if !animation_player.is_playing(): attack_cooldown_elapsed += delta

func attack_animations():
	animation_player.play("Fire")
	if projectile_launcher:
		projectile_launcher.fire()

func update_current_camera():
	camera = get_viewport().get_camera_3d()

func update_floating_healthbar():
	if !camera or !camera.is_visible_in_tree(): 
		update_current_camera()
		return
	#if get_tree().current_scene.players.has(self): # Make sure player isnt deleted
	var screen_pos = camera.unproject_position(self.global_position + Vector3(0, 4, 0))
	$EnemyUi/HealthBar.global_position = screen_pos 
	$EnemyUi/HealthBar.global_position += Vector2(-$EnemyUi/HealthBar.size.x / 2, 0)

func set_hit_from(val):
	hit_from = val

@rpc("call_local")
func take_damage(damage):
	healthbar._set_health(health - damage)
	#if multiplayer.is_server(): take_damage_client.rpc(damage)
	health -= damage

func _on_defeat():
	defeated = true
	set_physics_process(false)
	$HurtBox.set_deferred("monitorable", false)
	$HurtBox.set_deferred("monitoring", false)
	await get_tree().create_timer(2.0).timeout
	set_process(false)
	set_deferred("process_mode", PROCESS_MODE_DISABLED)
	$Physics.set_deferred("disabled",true)
	if multiplayer.is_server(): 
		$MultiplayerSynchronizer.public_visibility = false
		$MultiplayerSynchronizer.queue_free()
	
	$EnemyUi.hide() # Finally, hide enemy and its healthbar
	hide()
	#queue_free()

func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"):
		if target != null: return
		target = body
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
