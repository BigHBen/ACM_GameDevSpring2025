@tool
class_name BaseItem_Mesh
extends Area3D

@export var item_type: BaseItem
@export var needs_update := false

@onready var item_mesh:= $MeshInstance3D

func _init() -> void:
	collision_layer = 0
	collision_mask = 8

func _ready() -> void:
	if item_type != null:
		item_mesh.mesh = item_type.mesh
		item_spawn_animation()
	else:
		print("No type given to an item!w")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if needs_update:
			item_mesh.mesh = item_type.mesh
			needs_update = false

func item_spawn_animation():
	self.scale = Vector3.ONE/8
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector3.ONE, 0.5)
	
func _on_body_entered(area: PlayerCharacter) -> void:
	if area == null:
		return
	if item_type != null:
		item_type.add_value(area)
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(self, "scale", Vector3.ONE/8, 0.5)
		await tween.finished
		
		queue_free()
	else:
		print("This item doesn't have a valid type!")
