extends Node
class_name  GameManagerMultiplayer

# Autoload scene
@export var debug : TestDebug
@onready var scene_manager : ScenesList = get_node("/root/SceneManager")
@onready var quests_popup : QuestPopMenu = get_node("/root/QuestPopupMenu")
#@onready var lobby : Lobby = get_node("/root/MultiplayerLobby")

@onready var level_container : Node = $Level
var cur_level : Node3D = null :
	set(val):
		cur_level = val
		debug.load_dialogue_nodes()

var level_itr : int : # Iterate through levels array
	set (val):
		level_itr = val
		if level_itr < levels.size(): 
			var scene_name = get_scene_name(levels[level_itr].resource_path)
			print(self.name, ": Preparing to load levels[",level_itr,"]:", scene_name)
			change_level(levels[level_itr],level_itr)
			#if multiplayer.is_server(): request_level_change.rpc(levels[level_itr])
		else: printerr($".", " Error: No more levels to load - Add more scene elements to 'levels' Array")
	get: return level_itr

@export var ui_control : CanvasLayer
@export var players : Array[CharacterBody3D]
@export var players_scenes : Array[PackedScene]
@export var start_level_idx : int = 0
@export var levels : Array[PackedScene]
@export var player_selection : Node

# UI Nodes
@onready var pause_menu : Control = $UI/PauseMenu
@onready var stats_display : Control = $UI/StatsDisplay
@onready var direct_menu : PanelContainer = $Multiplayer_UI/UI/PanelContainer
@onready var back_button : Button = $Multiplayer_UI/UI/Back_to_Main

@onready var address_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/Remote
@onready var ip_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/Remote
@onready var name_entry : LineEdit = $Multiplayer_UI/UI/PanelContainer/MarginContainer/VBoxContainer/NameEntry


# Sync
#@onready var multi_sync : MultiplayerSynchronizer = $MultiplayerSynchronizer

# Conditions
var input_handling : bool = false
var multiplayer_pvp : bool = false

var peer_id = null
#const PORT = 9999
#var peer : ENetMultiplayerPeer = ENetMultiplayerPeer.new()
#var player_idx : int = 0
#var player_info = {"name": "Name"}
#
#var players_loaded = 0

var level_env_temp : Environment

signal _on_game_paused(is_paused : bool)
var game_paused : bool = false :
	set(val):
		game_paused = val
		#get_tree().paused = game_paused # No pausing in multiplayer
		if multiplayer.has_multiplayer_peer(): update_pause_state.rpc(val)
		_on_game_paused.emit(game_paused)
	get:
		return game_paused

signal _on_player_defeat(p_defeat_info : Array)
var player_defeat : Array = []:
	set(val):
		if val.size() > 1: player_defeat = [val[0],val[1]]
		else: player_defeat = []
		_on_player_defeat.emit(player_defeat)
	get:
		return player_defeat

var active_rpc_targets = {}

# Player selection
var cur_pname_position : Dictionary = {}

@rpc("any_peer") #*Not Used*
func update_pause_state(_val):
	var sender_id = multiplayer.get_remote_sender_id()
	var _player = find_player(str(sender_id))
	#if player.process_mode == 1: get_tree().paused = true

func _ready() -> void:

	multiplayer_setup()
	multiplayer_ui_setup()
	if levels.is_empty(): 
		printerr($".", " Error: No levels to load - Add scene elements to 'levels' Array")
		await get_tree().create_timer(1.0).timeout
		#get_tree().call_deferred("quit") # Removed for multiplayer testing
	#else: load_first_level()

func get_scene_name(node_path : String):
	return node_path.right(-node_path.rfind("/") - 1).left(-5)

func initialize(player_scene : PackedScene):
	var player = player_scene.instantiate()
	add_child(player)
	self.move_child(player,1)
	players[0] = player
	start_game()

func start_game():
	if level_itr > 0: next_level()
	else: load_first_level()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if !direct_menu.visible: game_paused = !game_paused
		else: _on_back_button_pressed()
	if event.is_action_pressed("test_level_skip"): # Autoskip levels - Testing
		if level_itr >= 0: 
			if multiplayer.is_server():
				next_level() # SERVER LEVEL SKIP
			else: request_next_level.rpc() # CLIENT LEVEL SKIP
		else: load_first_level()
#@rpc
#func request_level_change(level: PackedScene):
	#for peer in get_tree().network_peer.get_peers():
		#change_level.rpc_id(peer, level)

func change_level(new_level_scene: PackedScene,_idx):
	var current_level = level_container.get_child(0) if level_container.get_child_count() > 0 else null
	if current_level and current_level.is_in_group("Level"):
		print(self.name,": deleting ", current_level)
		current_level.call_deferred("queue_free")
	
	var path = new_level_scene.resource_path
	var _scene_name = get_scene_name(path)
	var new_level : Node3D = load(path).instantiate()
	
	#new_level.process_mode = Node.PROCESS_MODE_PAUSABLE
	for player in players: 
		if player != null:
			player.update_spawn_position.rpc(new_level.player_spawn_point)
			#player.position = new_level.player_spawn_point
			player.interact_manager.entered_areas.clear()
	
	level_container.add_child(new_level, true)
	new_level.owner = get_tree().current_scene
	#new_level.name = scene_name
	
	#self.move_child(new_level,0)
	print(self,": Added ",new_level)
	#sync_level(new_level.get_path())
	after_level_loaded.rpc()

@rpc("any_peer","call_local")
func after_level_loaded():
	self.ui_control.ui_fade_reset(1.0) # Undo UI fade effect
	quests_popup.reset()
	quests_popup.toggle_quest_menu(false)
	#quests_popup.toggle_quest_menu_remote.rpc(false) # Took out rpc
	
	change_level_properties_on_client()

@rpc("any_peer")
func change_level_properties_on_client():
	if !multiplayer.is_server():
		if cur_level != null and cur_level.world_environment and !level_env_temp:
			level_env_temp = cur_level.world_environment.environment
			cur_level.world_environment.environment = null

func add_level_properties():
	if level_env_temp:
		cur_level.world_environment.environment = level_env_temp

@rpc("any_peer","call_local")
func request_next_level():
	print("REQUEST: ",multiplayer.get_remote_sender_id())
	if multiplayer.is_server():
		print("switching level via client")
		next_level()


func load_first_level():
	level_itr = start_level_idx

func next_level():
	level_itr += 1

func multiplayer_setup():
	# Set multiplayer_active here so the autoload knows which mode we're in.
	# Both scenes use lobby autoload, so we need to set it when the scene starts.
	MultiplayerLobby.multiplayer_active = true 
	MultiplayerLobby.players_registered.connect(_on_players_updated)

func multiplayer_ui_setup():
	back_button.pressed.connect(_on_back_button_pressed)
	pause_menu.tween_shader_property("lod",2.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
	ip_entry.grab_focus() # For controllers

# Multiplayer section
func _on_host_pressed() -> void:
	direct_menu.hide()
	back_button.hide()
	$mainmenubackground.queue_free() # Enable for player_selection functionality
	
	#if level_itr > 0: next_level() # Disable for player selection functionality
	#else: load_first_level()
	
	MultiplayerLobby._on_host()
	input_handling = true
	
	if player_selection: 
		pause_menu.tween_shader_property("lod",0.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
		player_selection.toggle_player_selection(true) # Turn on player selection menu


func _on_connect_pressed() -> void:
	direct_menu.hide()
	back_button.hide()
	$mainmenubackground.queue_free() # Enable for player_selection functionality
	
	MultiplayerLobby._on_connect(ip_entry.text)
	input_handling = true
	
	if player_selection: 
		pause_menu.tween_shader_property("lod",0.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
		player_selection.toggle_player_selection(true) # Turn on player selection menu

func _on_back_button_pressed() -> void:
	# Switch back to main
	switch_to_main_menu()

func switch_to_main_menu(): # Resets game
	var main_menu_scene = scene_manager.scenes_packed[scene_manager.SCENES.MAIN_MENU]
	scene_manager.skip_titlecard = true
	print(self,": Returning to Main Menu...")
	if multiplayer.is_server(): MultiplayerLobby.notify_server_shutdown.rpc()
	else: 
		MultiplayerLobby.request_player_disconnect.rpc(peer_id)
		#MultiplayerLobby._on_player_disconnected(multiplayer.get_unique_id())
	get_tree().change_scene_to_packed(main_menu_scene)

func find_player(player_name : String):
	for player in players:
		if player != null and player.name == player_name:
			return player
	return null

func get_players():
	return players

func get_npcs():
	var npcs : Array
	if cur_level: 
		for child in cur_level.get_children():
			if child.is_in_group("NPC"):
				npcs.append(child)
	return npcs

func _on_players_updated():
	var ids = []
	var names = []
	for player in MultiplayerLobby.connected_players.keys():
		ids.append(player)
		names.append(MultiplayerLobby.get_display_name(player))
	
	# Add labels displaying connected peers
	for id in MultiplayerLobby.connected_players.keys():
		if id == 1: add_player_name_labels(MultiplayerLobby.connected_players)
		else: add_player_name_labels.rpc_id(id,MultiplayerLobby.connected_players)
	
	
	# Goal - Sync player selection ui stuff between peers
	# Add color-coded name tags hovering above each player
	# Add color-coded spotlights above each player
	#if multiplayer.is_server() and names.size() > 0: # Sync player selection between peers
		#for peer in MultiplayerLobby.connected_players.keys():
			#if !MultiplayerLobby.connected_players[peer].keys().has("player_scene"):
				#add_connected_player_labels.rpc(MultiplayerLobby.connected_players) # Buggy - scrapped
				#break
			
	#print(self,": Player List Updated: ",names)
	#if is_multiplayer_authority(): get_game_peer.rpc()

@rpc("call_local")
func get_game_peer():
	print(self,": Peer ID: ",peer_id)

func _on_child_entered_tree(node: Node) -> void:
	if node.is_in_group("Player"):
		players.append(node)
		pause_menu.tween_shader_property("lod",0.0, 0.25) # Blur effect - Tween that changes blur strength over 0.25 seconds
		
		if node.is_multiplayer_authority(): 
			stats_display.show()
			
		#MultiplayerLobby.player_loaded.rpc_id(node.name.to_int())

func _on_child_exiting_tree(node: Node) -> void:
	if node.is_in_group("Player"):
		players.erase(node)
		stats_display.hide()


func _on_level_child_entered_tree(node: Node) -> void:
	if node.is_in_group("Level"):
		cur_level = node

func setup_debug(player):
	if debug: debug.get_player_properties(player)

func _on_name_entry_text_submitted(_new_text: String) -> void:
	pass

# MultiplayerSpawner - spawn nodes between host/client players
func _on_multiplayer_spawner_spawned(_node: Node) -> void:
	pass
	#print("Spawner: Node spawned of type:", node.name, " on peer:", multiplayer.get_unique_id())
	#print("Spawner: Spawned node name:", node.name)

func _on_level_spawner_spawned(_node: Node) -> void:
	pass
	#print(self,": Spawned ", node)
	#print(players)

func _on_player_ready(id): # When player leaves player selection screen
	active_rpc_targets.erase(id)

#@rpc("call_local")
#func _on_player_active(peer_id): # When player reaches player selection screen
	#if peer_id == multiplayer.get_unique_id(): return
	#active_rpc_targets[peer_id] = true
	#print(multiplayer.get_unique_id(),": ",active_rpc_targets.keys()," - ",active_rpc_targets[peer_id])

#region Player Selection Sync Functions

@rpc("any_peer")
func add_player_name_labels(players_dict: Dictionary):
	if !player_selection: return
	for child in player_selection.player_name_container.get_children(): # Clear all player_name labels
		if child is Label and "Header" not in child.name: child.queue_free()
	player_selection.player_name_labels.clear()
	var header : Label = player_selection.player_name_container.get_node("Header")
	for i in range(players_dict.size()):
		#if game_root.peer_id == 1: print(players.size())
		var new_id = players_dict.keys()[i]
		var pname = players_dict[new_id]["name"]

		var label := Label.new()
		label.text = "Player %s - %s" % [i + 1, pname]
		label.label_settings = header.label_settings.duplicate()
		#label.label_settings.font_color = player_selection.player_color[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		player_selection.player_name_container.add_child(label)
		player_selection.player_name_labels.append(label)

# When players connect to the server, add UI elements
@rpc("authority","call_local")
func add_connected_player_labels(players_dict: Dictionary):
	if !player_selection: return
	#print("RPC called on peer:", multiplayer.get_unique_id(), "Players:", players.size())
	
	player_selection._clear_old()
	var header : Label = player_selection.player_name_container.get_node("Header")
	
	player_selection._assign_player_colors(players_dict)
	for i in range(players_dict.size()):
		#if game_root.peer_id == 1: print(players.size())
		var new_id = players_dict.keys()[i]
		var pname = players_dict[new_id]["name"]

		var label := Label.new()
		label.text = "Player %s - %s" % [i + 1, pname]
		label.label_settings = header.label_settings.duplicate()
		label.label_settings.font_color = player_selection.player_color[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		player_selection.player_name_container.add_child(label)
		player_selection.player_name_labels.append(label)
		
		# More labels
		var label_hover := Label3D.new()
		label_hover.name = "PlayerNameHover_" + str(new_id)
		label_hover.text = "P%s" % [i+1]
		label_hover.font = header.label_settings.font.duplicate()
		if new_id == peer_id:
			label_hover.font_size = 75
		else: label_hover.font_size = 30
		label_hover.modulate = player_selection.player_color[i]
		label_hover.position = \
		Vector3(player_selection.player_models[player_selection.current_index].position.x + 3,player_selection.player_hover_height,0)
		player_selection.player_set.get_node("Set").add_child(label_hover)
		player_selection.player_name_hovers[new_id] = label_hover
		
		if new_id == peer_id:
			continue

		var light : SpotLight3D = player_selection.player_shine.duplicate()
		light.name = "OtherPlayerSpotlight_" + str(new_id)
		light.light_color = player_selection.player_color[i]
		player_selection.player_set.get_node("Set").add_child(light)
		player_selection.connected_player_spotlights[new_id] = light
		
		for id in cur_pname_position.keys():
			if player_selection: player_selection._on_player_chosen_idx_changed(id,cur_pname_position[id])
@rpc("call_remote")
func sync_player_colors(colors: Array):
	if !player_selection: return
	player_selection.player_color = colors.duplicate()
	player_selection._update_player_labels()
	#else: printerr(multiplayer.get_unique_id(),": sync_player_colors() PlayerSelection Node not found!")

@rpc("any_peer","call_remote")
func sync_player_shine(new_id, pos_x: float):
	if !player_selection or !new_id: return
	if player_selection.connected_player_spotlights.has(new_id):
		player_selection.connected_player_spotlights[new_id].position.x = pos_x
	#else: printerr(multiplayer.get_unique_id(),": sync_player_shine() PlayerSelection Node not found!")

@rpc("any_peer","call_remote")
func sync_player_hover(new_id, pos_x: float):
	if !player_selection or !new_id: return
	if player_selection.player_name_hovers.has(new_id):
		player_selection.player_name_hovers[new_id].position.x = pos_x
	#else: printerr(multiplayer.get_unique_id(),": sync_player_hover() PlayerSelection Node not found!")

@rpc("any_peer")
func store_pname_pos(new_id, pos):
	cur_pname_position[new_id] = pos
	sync_pname_pos.rpc(cur_pname_position)

@rpc("any_peer","call_remote")
func sync_pname_pos(dict: Dictionary):
	cur_pname_position = dict.duplicate()

@rpc("any_peer","call_remote")
func sync_cheer_animation(player_idx):
	if !player_selection: return
	player_selection.sync_cheer_animation.rpc(player_idx)



#endregion

static func get_active_players_multiplayer() -> Array:
	var ids = []
	for peer in MultiplayerLobby.connected_players.keys():
		if MultiplayerLobby.connected_players[peer].keys().has("player_scene"):
			ids.append(peer)
	return ids

static func get_inactive_players_multiplayer() -> Array:
	var ids = []
	#if !multiplayer.is_server(): print(self.name,": ", MultiplayerLobby.connected_players)
	for peer in MultiplayerLobby.connected_players.keys():
		if !MultiplayerLobby.connected_players[peer].keys().has("player_scene"):
			ids.append(peer)
	return ids
