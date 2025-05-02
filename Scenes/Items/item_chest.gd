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

signal interaction_done(area) # Signal to player_interact

var item_revealed : bool = false : 
	set(val):
		item_revealed = val
		if val and target:
			if !loot.is_empty(): pass
			else: print(self, " is empty!")
	get:
		return item_revealed

func interact():
	if target and not opened:
		anim_player.play("open")
		for item in loot: if target: await reveal_item(item)
		opened = true
		interaction_done.emit(self)

func reveal_item(item : BaseItem):
	if !target: return
	var game = null
	var pause_menu = null
	if get_tree().current_scene is GameManager:
		game = target.get_tree().current_scene
		pause_menu = game.ui_control.pause_menu
		pause_menu.tween_shader_property("lod",2.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
	
	if !item_display.visible:  # Show item popup icon
		item_display_icon.texture = item.icon
		item_display.visible = true
	item_display_anim.play("rotate")
	item_display.scale = Vector2.ONE/8 # Item reveal tween
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(item_display, "scale", Vector2.ONE, 0.25)
	
	item_revealed = true
	give_item(item,target)
	
	await get_tree().create_timer(item_reveal_wait).timeout
	var tween_out = create_tween() # Shrink item popup and reverse blur effect
	tween_out.set_trans(Tween.TRANS_LINEAR)
	tween_out.set_ease(Tween.EASE_IN_OUT)
	tween_out.tween_property(item_display, "scale", Vector2.ONE/8, 0.25)
	await tween_out.finished
	
	if pause_menu != null:
		pause_menu.tween_shader_property("lod",0.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
	item_display.visible = false
	item_revealed = false


func give_item(item,to):
	if item is BaseItem: item.add_value(to)

func _on_chest_entered(body):
	if body.is_in_group("Player"):
		target = body
		
		# Connect to player interaction manager - Allows player to interact w NPC
		if target.interact_manager and !opened:
			if !target.interact_manager.entered_areas.has(self): target.interact_manager.add_area(self)

func _on_chest_exited(_body):
	
	# Connect to player interaction manager - Allows player to interact w NPC
	if target != null and target.interact_manager:
		if target.interact_manager.entered_areas.has(self): target.interact_manager.remove_area(self)
	
	#target = null
	if opened: pass #anim_player.play("close")

func _on_area_entered(area: Area3D) -> void:
	if area.owner:
		if area.owner.is_in_group("Player"): pass
			#if target:
				#return
			#target = area.owner

func _on_area_exited(area: Area3D) -> void:
	if area.owner:
		if area.owner.is_in_group("Player"): pass
			#if area.owner == target: 
				#pass
