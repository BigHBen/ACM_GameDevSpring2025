@tool
class_name BaseItem_Mesh extends Area3D

const ITEM_ROTATE_SPEED : float = 1.0
@export var item_type: BaseItem
@export var needs_update := false
@export var item_glow : bool = false

@onready var item_mesh:= $MeshInstance3D
@onready var light:= $SpotLight3D

func _init() -> void:
	collision_layer = 0
	collision_mask = 8

func _ready() -> void:
	if item_type != null:
		item_mesh.mesh = item_type.mesh
		item_spawn_animation()
	else:
		print("No type given to an item!w")

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if needs_update:
			item_mesh.mesh = item_type.mesh
			needs_update = false
	else:
		self.rotate_y(delta * ITEM_ROTATE_SPEED)
		if light:
			if item_glow: light.light_energy = 5
			else: light.light_energy = 0.0

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
