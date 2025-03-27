extends Node3D
#class_name Level

@export var dungeon_level_1 : PackedScene = preload("res://Scenes/Levels/test_dungeon.tscn")
@export var player_spawn_point = Vector3(0,2,-16)

func _on_end_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if owner is GameManager: owner.next_level()
