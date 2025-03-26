extends CharacterBody3D

@onready var healthbar = $EnemyUi/HealthBar
@export_group("Stats")
@export_range(0,100) var health : int = 100
var camera: Camera3D
const SPEED = 5.0
const JUMP_VELOCITY = 4.5

var defeated : bool = false

func _ready() -> void:
	healthbar.init_health(health)
	camera = get_viewport().get_camera_3d()

func _process(_delta: float) -> void:
	var screen_pos = camera.unproject_position(self.global_position + Vector3(0, 4, 0))
	$EnemyUi/HealthBar.global_position = screen_pos 
	$EnemyUi/HealthBar.global_position += Vector2(-$EnemyUi/HealthBar.size.x / 2, 0)

func _physics_process(delta: float) -> void:
	if get_parent() is PathFollow3D:
		var p : PathFollow3D = get_parent()
		p.progress += SPEED * delta

func take_damage(damage):
	healthbar._set_health(health - damage)
	health -= damage

func _on_defeat():
	defeated = true
	set_process(false)
	set_physics_process(false)
	queue_free()
