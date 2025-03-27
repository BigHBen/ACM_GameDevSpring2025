extends Node3D
#class_name Level

@export var dungeon_level_1 : PackedScene = preload("res://Scenes/Levels/test_dungeon.tscn")

func _on_end_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		get_tree().call_deferred("change_scene_to_packed",dungeon_level_1)
