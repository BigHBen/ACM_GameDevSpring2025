extends Node3D

var game
var target

signal interaction_done(area) # Signal to player_interact

func _ready() -> void:
	if get_tree().current_scene is GameManager: 
		game = get_tree().current_scene
	if get_tree().current_scene is GameManagerMultiplayer:
		game = get_tree().current_scene

func interact():
	if game and game.ui_control:
		#await game.ui_control.magic_fade_out(1.0)
		if multiplayer.is_server(): game.next_level()
		else: game.request_next_level.rpc()
	else: 
		printerr($"."," Error: Game UI not detected - Cannot Transfer Player")
		interaction_done.emit(self)


func _on_end_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if target:
			return
		target = body
	#if body.is_multiplayer_authority(): owner.next_level() # SERVER - NEXT LEVEL
	#else: 
		#print("Is Server:", multiplayer.is_server())
		#print("This peer ID:", multiplayer.get_unique_id())
		#print("Body owner ID:", body.get_multiplayer_authority())
		#owner.request_next_level.rpc_id(body.get_multiplayer_authority()) # CLIENT - NEXT LEVEL

func _on_end_area_body_exited(body: Node3D) -> void:
	if body == target:
		target = null
