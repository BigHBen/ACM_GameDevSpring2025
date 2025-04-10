extends CharacterBody3D

@export_group("Movement")
@export var SPEED = 5.0
const JUMP_VELOCITY = 4.5

@onready var healthbar = $EnemyUi/HealthBar
@export_group("Stats")
@export_range(0,100) var health : int = 100
var camera: Camera3D

var defeated : bool = false
var path_dir : bool = true

var target
func _ready() -> void:
	healthbar.init_health(health)
	update_current_camera()

func update_current_camera():
	camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	if camera != null: update_floating_healthbar()

func update_floating_healthbar():
	if !camera or !camera.is_visible_in_tree(): 
		update_current_camera()
		return
	var screen_pos = camera.unproject_position(self.global_position + Vector3(0, 4, 0))
	$EnemyUi/HealthBar.global_position = screen_pos 
	$EnemyUi/HealthBar.global_position += Vector2(-$EnemyUi/HealthBar.size.x / 2, 0)

func _physics_process(delta: float) -> void:
	if get_parent() is PathFollow3D:
		var p : PathFollow3D = get_parent()
		
		if p.progress_ratio == 1.0:
			path_dir = false
		elif p.progress_ratio == 0.0:
			path_dir = true
		
		if !p.loop:
			if path_dir: p.progress += SPEED * delta
			else: p.progress -= SPEED * delta
		else: p.progress += SPEED * delta

func take_damage(damage):
	healthbar._set_health(health - damage)
	#if multiplayer.is_server(): take_damage_client.rpc(damage)
	health -= damage

#func take_damage_client(damage):
	#healthbar._set_health(health - damage)
	#health -= damage

func _on_defeat():
	defeated = true
	set_process(false)
	set_physics_process(false)
	if multiplayer.is_server(): 
		$MultiplayerSynchronizer.public_visibility = false
	queue_free()


func _on_detection_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if !target: target = body
		if !healthbar.visible: 
			update_current_camera()
			healthbar.show()


func _on_detection_area_body_exited(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if body==target: 
			update_current_camera()
			healthbar.hide()

func _on_tree_exiting() -> void:
	# Disable multiplayersyncronizer when deleting self
	if multiplayer.is_server(): 
		$MultiplayerSynchronizer.public_visibility = false
