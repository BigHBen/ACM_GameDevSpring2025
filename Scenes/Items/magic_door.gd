extends Node3D

@onready var anim_player : AnimationPlayer = $AnimationPlayer

#Detection Variables
@export_group("Detection")
@export var vis_radius = 3

#More detection variables
var target
var game

signal interaction_done(area) # Signal to player_interact

func _ready() -> void:
	if get_tree().current_scene is GameManager or get_tree().current_scene is GameManagerMultiplayer:
		game = get_tree().current_scene
	else: 
		printerr($"."," Error: GameManager not detected - Cannot Finish Level")

func interact():
	if game and game.ui_control:
		anim_player.play("open")
		await game.ui_control.magic_fade_out(1.0)
		game.next_level()
		game.switch_to_main_menu()
	else: 
		printerr($"."," Error: Game UI not detected - Cannot Transfer Player")
		interaction_done.emit(self)

func _on_magic_door_area_entered(body):
	if body.is_in_group("Player"):
		if target:
			return
		target = body
		
		# Connect to player interaction manager - Allows player to interact w NPC
		if target.interact_manager:
			if !target.interact_manager.entered_areas.has(self): target.interact_manager.add_area(self)

func _on_magic_door_area_exited(body):
	if body == target:
		
		# Connect to player interaction manager - Allows player to interact w NPC
		if target and  target.interact_manager:
			if target.interact_manager.entered_areas.has(self): target.interact_manager.remove_area(self)
		
		target = null

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

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	pass
