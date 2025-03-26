extends Node3D
class_name ItemChest1

@onready var anim_player : AnimationPlayer = $AnimationPlayer
var target
var opened : bool = false

func interact():
	anim_player.play("open")
	opened = true

func give_item():
	pass

func _on_chest_entered(body):
	if body.is_in_group("Player"):
		if target:
			return
		target = body

func _on_chest_exited(body):
	if body == target:
		target = null
		if opened: anim_player.play("close")
