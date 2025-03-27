extends Node3D
class_name ItemChest1

@onready var anim_player : AnimationPlayer = $AnimationPlayer
@onready var item_display : Control = $UI/Control
@onready var item_display_anim : AnimationPlayer = $UI/Control/AnimationPlayer
@onready var item_display_icon : TextureRect = $UI/Control/item_icon

@export var loot : Array[BaseItem] = []
@export_range(0,5) var item_reveal_wait : float = 2.0
var target
var opened : bool = false
var item_revealed : bool = false : 
	set(val):
		item_revealed = val
		if val and target:
			if !loot.is_empty(): pass
			else: print(self, " is empty!")
	get:
		return item_revealed

func interact():
	anim_player.play("open")
	if not opened:
		for item in loot: if target: await reveal_item(item)
		opened = true

func reveal_item(item : BaseItem):
	if !target: return
	if target.get_parent().is_in_group("Level"):
		var game = target.get_parent().game
		var pause_menu = game.pause_menu
		pause_menu.tween_shader_property("lod",2.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
		
		if !item_display.visible: 
			item_display_icon.texture = item.icon
			item_display.visible = true
		item_display_anim.play("rotate")
		item_display.scale = Vector2.ONE/8 # Show item reveal
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_LINEAR)
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(item_display, "scale", Vector2.ONE, 0.25)
		
		item_revealed = true
		give_item(item,target)
		
		await get_tree().create_timer(item_reveal_wait).timeout
		var tween_out = create_tween()
		tween_out.set_trans(Tween.TRANS_LINEAR)
		tween_out.set_ease(Tween.EASE_IN_OUT)
		tween_out.tween_property(item_display, "scale", Vector2.ONE/8, 0.25)
		await tween_out.finished
		pause_menu.tween_shader_property("lod",0.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
		item_display.visible = false
		item_revealed = false


func give_item(item,to):
	if item is BaseItem: item.add_value(to)

func _on_chest_entered(body):
	if body.is_in_group("Player"):
		if target:
			return
		target = body

func _on_chest_exited(body):
	if body == target:
		target = null
		if opened: anim_player.play("close")
