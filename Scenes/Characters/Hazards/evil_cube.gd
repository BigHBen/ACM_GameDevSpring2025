extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 4.5


func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if get_parent() is PathFollow3D:
		var p : PathFollow3D = get_parent()
		p.progress += SPEED * delta
