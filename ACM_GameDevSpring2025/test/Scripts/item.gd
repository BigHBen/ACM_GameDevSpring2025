extends Area3D

@export var item_type: BaseItem

@onready var item_mesh:= $MeshInstance3D

func _init() -> void:
	collision_layer = 0
	collision_mask = 8

func _ready() -> void:
	item_mesh.mesh = item_type.mesh

func _on_body_entered(area: Player) -> void:
	if area == null:
		return
	item_type.add_value(area)
	queue_free()
