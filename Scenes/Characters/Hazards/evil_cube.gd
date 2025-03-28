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

func _ready() -> void:
	healthbar.init_health(health)
	camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	if camera != null:
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
	health -= damage

func _on_defeat():
	defeated = true
	set_process(false)
	set_physics_process(false)
	queue_free()
