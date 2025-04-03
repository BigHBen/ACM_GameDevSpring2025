extends Node3D
#class_name Level

@export var dungeon_level_1 : PackedScene = preload("res://Scenes/Levels/test_dungeon.tscn")
@export var player_spawn_point = Vector3(0,2,-16)

@onready var preview_camera : Camera3D = $Level_Preview/TestCamera3D2
@export_range(0,2) var preview_camera_speed : float = 0.25

func _on_end_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if owner is GameManager: owner.next_level()

func _process(delta: float) -> void:
	if preview_camera.current: preview_camera.rotate_y(delta * preview_camera_speed)
