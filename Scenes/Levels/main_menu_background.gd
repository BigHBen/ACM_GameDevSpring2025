extends Node3D


@onready var preview_camera : Camera3D = $Camera/Camera3D
@export_range(0,2) var preview_camera_speed : float = 0.25

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if preview_camera.current: preview_camera.rotate_y(delta * preview_camera_speed)
