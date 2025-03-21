extends Node3D

@onready var nav_region : NavigationRegion3D = $Gridmaps/NavigationRegion3D

func group_toggle_ui(group,toggle):
	for child in get_children():
		if child.is_in_group(group):
			for subchild in child.get_children():
				if subchild is CanvasLayer:
					subchild.visible = toggle

#func _process(delta: float) -> void:
	#get_tree().call_group("Enemy", "target_position", target.global_transform.origin)
