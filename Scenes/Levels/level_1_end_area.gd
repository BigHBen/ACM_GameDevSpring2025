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
		if game is GameManagerMultiplayer:
			var peer_id := multiplayer.get_unique_id()
			for id in GameManagerMultiplayer.get_active_players_multiplayer():
				if id != peer_id: sync_fade_out.rpc_id(id)
		await game.ui_control.magic_fade_out(1.0)
		
		if game is GameManagerMultiplayer:
			if multiplayer.is_server(): game.next_level()
			else: game.request_next_level.rpc()
			
		elif game is GameManager: 
			game.next_level()
	else: 
		printerr($"."," Error: Game UI not detected - Cannot Transfer Player")
		interaction_done.emit(self)

@rpc("any_peer","call_local")
func sync_fade_out():
	game.ui_control.magic_fade_out(1.0)

func _on_end_area_body_entered(body: Node3D) -> void:
	if body.is_in_group("Player"): 
		if target:
			return
		target = body
		
		# Connect to player interaction manager - Allows player to interact w NPC
		if target.interact_manager:
			if !target.interact_manager.entered_areas.has(self): target.interact_manager.add_area(self)

func _on_end_area_body_exited(body: Node3D) -> void:
	if body == target:
		
		# Connect to player interaction manager - Allows player to interact w NPC
		if target and target.interact_manager:
			if target.interact_manager.entered_areas.has(self): target.interact_manager.remove_area(self)
		
		target = null
