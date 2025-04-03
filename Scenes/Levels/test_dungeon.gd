extends Node3D

@onready var game : Node = get_parent()
@onready var nav_region : NavigationRegion3D = $Gridmaps/NavigationRegion3D
@export var level_chest : PackedScene
@export var player_spawn_point = Vector3(0,2,0)

func _ready() -> void:
	if level_chest: spawn_chests()

func group_toggle_ui(group,toggle):
	for child in get_children():
		if child.is_in_group(group):
			for subchild in child.get_children():
				if subchild is CanvasLayer:
					subchild.visible = toggle

func spawn_chests():
	var level_items : Node = get_node_or_null("Items")
	var markers : Array = []
	var random_marker
	for child in level_items.get_children():
		if child is Marker3D and child.name.to_lower().find("chest") != -1: 
			markers.append(child)
	if markers.size() > 0:
		random_marker = markers[randi() % markers.size()]
	
	var chest = level_chest.instantiate()
	#quest_item.item_type = npc_quest_item
	chest.position = random_marker.position
	level_items.add_child(chest)
