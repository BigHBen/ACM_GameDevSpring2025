extends Node

# Autoload
@onready var scene_manager : ScenesList = get_node("/root/SceneManager")

@onready var player_set : Node3D = $SubViewportContainer/SubViewport/PlayerSelectionSet
@onready var player_shine : SpotLight3D = $SubViewportContainer/SubViewport/PlayerSelectionSet/Set/PlayerShine

# UI Nodes
@onready var player_info : Control = $SelectionUI/PlayerInfo
@onready var player_name_label : Label = $SelectionUI/PlayerInfo/PanelContainer/MarginContainer/VBoxContainer/StatsContainer/PlayerName
@onready var player_desc_label : Label = $SelectionUI/PlayerInfo/PanelContainer/MarginContainer/VBoxContainer/Description
@onready var stats_container : HBoxContainer = $SelectionUI/PlayerInfo/PanelContainer/MarginContainer/VBoxContainer/StatsContainer
@onready var start_game : Button = $SelectionUI/SelectButtons/VBoxContainer/Start
@onready var back_button : Button = $SelectionUI/SelectButtons/UnReady

# Player Display UI
@onready var network_display : Control = $SelectionUI/Network
@onready var player_name_container : VBoxContainer = $SelectionUI/Network/PanelContainer/MarginContainer/PlayerDisplayContainer
@onready var notification_label : Label = $SelectionUI/Network/NotificationLabel

@onready var PLAYER_DATA_TYPES : Dictionary = {
	"Knight" : preload("res://Resources/Player_Data/Knight_Data.tres"),
	"Barbarian" : preload("res://Resources/Player_Data/Barbarian_Data.tres"),
	"Rogue" : preload("res://Resources/Player_Data/Rogue_Data.tres"),
	"Mage": preload("res://Resources/Player_Data/Mage_Data.tres"),
} 

@onready var PLAYER_TO_SCENE : Dictionary = {
	"Knight" : preload("res://Scenes/Characters/knight.tscn"),
	"Barbarian" : preload("res://Scenes/Characters/barbarian.tscn"),
	"Rogue" : preload("res://Scenes/Characters/rogue_hooded.tscn"),
	"Mage": preload("res://Scenes/Characters/mage.tscn"),
} 

var hp_icon : Texture2D = preload("res://Assets/UI_Assets/icons8-heart-stamp/icons8-heart-96.png")
var speed_icon : Texture2D = preload("res://Assets/UI_Assets/icons8-fast-ios-17-filled/icons8-fast-100.png")

var player_models : Array[Node]
var subject_anim_player : AnimationPlayer 
var subject_anim_tree : AnimationTree
var current_index = 0 :
	set(val):
		current_index = val
		update_player_info()
		update_visible_model()

var game_root : GameManagerMultiplayer = null
var player_ready : bool = false

var player_name_labels : Array[Label] = []
var player_name_hovers : Dictionary = {}
var connected_player_spotlights : Dictionary = {}
var player_color : Array[Color]
var player_hover_height : float = 3.5

func _ready() -> void:
	if get_tree().current_scene is GameManagerMultiplayer: 
		game_root = get_tree().current_scene
		
	if player_set.player_container.get_child_count() > 0: 
		player_models = player_set.player_container.get_children()
	start_game.pressed.connect(_on_start_pressed)
	back_button.pressed.connect(_on_undo_pressed)
	
	current_index = 0
	
	toggle_player_selection(false)

func toggle_player_selection(on):
	$SubViewportContainer.visible = on
	player_set.visible = on
	$SelectionUI.visible = on

func _on_start_pressed():
	var cur_player : CharacterBody3D = player_models[current_index] # Get current player from player selection set
	var player_scene : PackedScene = get_player_scene_from_name(cur_player.name) # Get player scene
	
	if !multiplayer.is_server() and 1 not in GameManagerMultiplayer.get_active_players_multiplayer(): # Only allow clients after player 1 starts game
		notification_label.pivot_offset = notification_label.size * 0.5
		notification_popop("Only the host can start the game!", 1.5)
		return 
	game_root.players_scenes.append(player_scene)
	
	player_ready = true
	start_game.hide()
	character_cheer_animation(cur_player)
	
	
	await fade_out($SelectionUI/PlayerInfo/Change_Fade,1.0) # Default 1.0
	
	# Use selected player scene and start game
	if multiplayer.is_server(): game_root.start_game()
	else: game_root.add_level_properties()
	
	if !multiplayer.is_server(): 
		MultiplayerLobby.player_character_chosen.rpc_id(1, game_root.peer_id, player_scene.resource_path)
	else:
		# If this IS the server, just call it directly
		MultiplayerLobby.player_character_chosen(game_root.peer_id, player_scene.resource_path)
	
	#if multiplayer.is_server(): MultiplayerLobby.player_character_chosen(game_root.peer_id,player_scene.resource_path)
	#else: MultiplayerLobby.player_character_chosen.rpc_id(1,game_root.peer_id,player_scene.resource_path)
	#create_player_ready(game_root.peer_id,player_scene)
	#MultiplayerLobby.create_player(game_root.peer_id)
	game_root.player_selection = null
	queue_free() # Finally, delete player selection

#@rpc("any_peer","reliable")
#func create_player_ready(id,scene):
	#game_root.players_scenes.append(scene)
	#print(multiplayer.get_unique_id())
	#MultiplayerLobby.create_player_ready(id)

func _on_undo_pressed():
	#player_ready = false # instead just send back to main menu
	#player_shine.light_energy = 0
	#start_game.show()
	# Switch back to main
	MultiplayerLobby._on_player_disconnected(game_root.peer_id)
	game_root.switch_to_main_menu()

func _input(event: InputEvent) -> void:
	if player_ready: return
	if event.is_action_pressed("left"):
		current_index = (current_index - 1 + player_models.size()) % player_models.size()
	elif event.is_action_pressed("right"):
		current_index = (current_index + 1) % player_models.size()

# Called only on the server
func _assign_player_colors(players: Dictionary):
	player_color.resize(players.size())
	for i in range(players.size()):
		player_color[i] = Color(randf(), randf(), randf(), 1.0)
	if is_multiplayer_authority(): 
		game_root.sync_player_colors.rpc(player_color)

#@rpc("call_remote")
#func sync_player_colors(colors: Array):
	#player_color = colors.duplicate()
	#_update_player_labels()

func _update_player_labels():
	for i in range(player_name_labels.size()):
		player_name_labels[i].label_settings.font_color = player_color[i]
	for j in range(player_name_hovers.size()):
		var key = player_name_hovers.keys()[j]
		player_name_hovers[key].modulate = player_color[j]
	for k in range(connected_player_spotlights.size()):
		var key = connected_player_spotlights.keys()[k]
		connected_player_spotlights[key].light_color = player_color[k]

func _clear_old():
	for child in player_name_container.get_children(): # Clear all player_name labels
		if child is Label and "Header" not in child.name: child.queue_free()
	player_name_labels.clear()
	
	for child in player_set.get_node("Set").get_children():
		if child is Label3D: child.queue_free()
		if child is SpotLight3D and "Other" in child.name: child.queue_free()
	player_name_hovers.clear()
	connected_player_spotlights.clear()

func notification_popop(text : String,sec: float):
	
	
	notification_label.text = text
	notification_label.pivot_offset = notification_label.size * 0.5
	notification_label.scale = Vector2(0.1, 0.1)  # Start very small
	notification_label.show()
	
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(notification_label, "scale", Vector2(1.2, 1.2), sec * 0.5)
	
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(notification_label, "scale", Vector2(0.0, 0.0), sec * 0.5)
	await tween.finished
	notification_label.hide()

func fade_out(s,sec:float):
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(s, "color", Color(0, 0, 0, 1), sec)
	await tween.finished

func get_player_data_from_name(node_name : String) -> PlayerData:
	for key in PLAYER_DATA_TYPES.keys():
		if key in node_name: return PLAYER_DATA_TYPES[key]
	printerr("No matching player data for name: ", node_name)
	return null

func get_player_scene_from_name(node_name : String) -> PackedScene:
	for key in PLAYER_TO_SCENE.keys():
		if key in node_name: return PLAYER_TO_SCENE[key]
	printerr("No matching player data for name: ", node_name)
	return null

func update_player_info():
	var cur_player : CharacterBody3D = player_models[current_index]
	var info : PlayerData = get_player_data_from_name(cur_player.name)
	player_name_label.text = info.display_name
	player_desc_label.text = info.description
	
	for child in stats_container.get_children():
		if child is TextureRect or child.name.contains("VSeparator"): child.queue_free()
	
	var health_icon_count : int = get_icon_count(info.hp,info.MAX_HEALTH)
	var speed_icon_count : int = get_icon_count(info.speed,info.MAX_SPEED)
	
	for i in range(health_icon_count):
		var new_texture : TextureRect = TextureRect.new()
		new_texture.texture = hp_icon
		new_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		stats_container.add_child(new_texture)
	
	var v : VSeparator = VSeparator.new() # Add new spacer between health and speed icons
	v.add_theme_stylebox_override("separator",StyleBoxEmpty.new())
	v.add_theme_constant_override("separation", 30)
	stats_container.add_child(v)
	
	for i in range(speed_icon_count):
		var new_texture : TextureRect = TextureRect.new()
		new_texture.texture = speed_icon
		new_texture.expand_mode = TextureRect.EXPAND_FIT_WIDTH
		stats_container.add_child(new_texture)


func get_icon_count(val, max_val, max_icons : int = 3):
	if max_val <= 0: return
	var per = clamp(float(val) / max_val, 0, 1.0)
	var icon_count = int(floor(per * max_icons))
	return max(1, icon_count)

func update_visible_model():
	#for player in player_set.player_container.get_children():
		#player.hide()
	var cur_player = player_models[current_index]
	cur_player.show()
	player_shine.light_energy = 16
	player_shine.position.x = cur_player.position.x + 3
	if game_root:
		_on_player_chosen_idx_changed(game_root.peer_id,cur_player.position.x + 3)
	#sync_player_shine.rpc(current_index) # Broken dont call
	
	get_subject_animation_nodes(cur_player)

	#if subject_anim_player.animation_finished.is_connected(_on_subject_anim_finished):
		#subject_anim_player.animation_finished.connect(_on_subject_anim_finished)
	
	var anim_state : AnimationNodeStateMachinePlayback = subject_anim_tree.get("parameters/AnimationNodeStateMachine/playback")
	subject_anim_tree.active = false
	subject_anim_tree.active = true
	anim_state.start("Jump_Full_Short")
	character_pick_tween(cur_player)
	#subject_anim_tree.active = true

func get_subject_animation_nodes(player):
	for child in player.get_children():
		if child is AnimationPlayer: 
			subject_anim_player = child
		elif child is AnimationTree:
			subject_anim_tree = child

func character_cheer_animation(player):
	get_subject_animation_nodes(player)
	var anim_state : AnimationNodeStateMachinePlayback = subject_anim_tree.get("parameters/AnimationNodeStateMachine/playback")
	subject_anim_tree.active = false
	subject_anim_tree.active = true
	anim_state.start("Cheer")
	var players_in_selection = GameManagerMultiplayer.get_inactive_players_multiplayer()
	if players_in_selection.size() > 1:
		for id in players_in_selection:
			if id != game_root.peer_id: sync_cheer_animation.rpc_id(id,current_index)

func _on_player_chosen_idx_changed(peer_id, new_position_x: float):
	
	if multiplayer.is_server(): 
		if peer_id and new_position_x: game_root.store_pname_pos(peer_id,new_position_x)
	elif peer_id and new_position_x: game_root.store_pname_pos.rpc(peer_id,new_position_x)
	
	game_root.sync_player_shine.rpc(peer_id, new_position_x)
	if player_name_hovers.has(peer_id):
		#print(peer_id,": ",player_name_hovers[peer_id].position.x)
		player_name_hovers[peer_id].position.x = new_position_x
	game_root.sync_player_hover.rpc(peer_id,new_position_x)
	
#@rpc("any_peer","call_remote")
#func sync_player_shine(peer_id: int, pos_x: float):
	#if connected_player_spotlights.has(peer_id):
		#connected_player_spotlights[peer_id].position.x = pos_x
	#
	##for spotlight in connected_player_spotlights:
		###print(multiplayer.get_unique_id()," Checking: ", spotlight["set_for"])
		##if spotlight["set_for"] != multiplayer.get_unique_id():
			##spotlight["node"].light_energy = 8
			##spotlight["node"].position.x = player_models[player_idx].position.x + 3
			##break

#@rpc("any_peer","call_remote")
#func sync_player_hover(peer_id: int, pos_x: float):
	#if player_name_hovers.has(peer_id):
		#player_name_hovers[peer_id].position.x = pos_x

@rpc("any_peer","call_remote")
func sync_cheer_animation(player_idx):
	for child in player_models[player_idx].get_children():
		if child is AnimationPlayer: 
			subject_anim_player = child
		elif child is AnimationTree:
			subject_anim_tree = child
	var anim_state : AnimationNodeStateMachinePlayback = subject_anim_tree.get("parameters/AnimationNodeStateMachine/playback")
	subject_anim_tree.active = false
	subject_anim_tree.active = true
	anim_state.start("Cheer")

func character_pick_tween(player : CharacterBody3D):
	var start_rot = player.rotation.y
	var end_rot = start_rot + deg_to_rad(360)

	var spin_tween = create_tween()
	var spin_duration = 1.0
	
	spin_tween.set_trans(Tween.TRANS_QUAD)
	spin_tween.set_ease(Tween.EASE_IN_OUT)
	spin_tween.tween_property(player, "rotation:y", end_rot, spin_duration)
	await spin_tween.finished
	player.rotation.y = deg_to_rad(0)

func _on_subject_anim_finished(_anim_name): # Not Used
	if !subject_anim_tree.active: subject_anim_tree.active = true
