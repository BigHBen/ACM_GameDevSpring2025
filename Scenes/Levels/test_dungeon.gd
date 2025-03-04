extends Node3D

func group_toggle_ui(group,toggle):
	for child in get_children():
		if child.is_in_group(group):
			for subchild in child.get_children():
				if subchild is CanvasLayer:
					subchild.visible = toggle
