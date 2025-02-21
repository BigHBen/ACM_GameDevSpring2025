@tool
extends Area3D

@export var item_type: BaseItem
@export var needs_update := false

@onready var item_mesh:= $MeshInstance3D

func _init() -> void:
	collision_layer = 0
	collision_mask = 8

func _ready() -> void:
	item_mesh.mesh = item_type.mesh

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if needs_update:
			item_mesh.mesh = item_type.mesh
			needs_update = false

func _on_body_entered(area: Player) -> void:
	if area == null:
		return
	item_type.add_value(area)
	queue_free()
