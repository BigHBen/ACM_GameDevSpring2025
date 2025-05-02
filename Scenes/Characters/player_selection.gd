extends Node

# Autoload
@onready var scene_manager : ScenesList = get_node("/root/SceneManager")

@onready var player_set : PlayerSelectionSet = $SubViewportContainer/SubViewport/PlayerSelectionSet
@onready var left_arrow : Button = $SelectionUI/SelectButtons/VBoxContainer/HBoxContainer/LeftArrow
@onready var right_arrow : Button = $SelectionUI/SelectButtons/VBoxContainer/HBoxContainer/RightArrow

# UI Nodes
@onready var player_info : Control = $SelectionUI/PlayerInfo
@onready var player_name_label : Label = $SelectionUI/PlayerInfo/PanelContainer/MarginContainer/VBoxContainer/StatsContainer/PlayerName
@onready var player_desc_label : Label = $SelectionUI/PlayerInfo/PanelContainer/MarginContainer/VBoxContainer/Description
@onready var stats_container : HBoxContainer = $SelectionUI/PlayerInfo/PanelContainer/MarginContainer/VBoxContainer/StatsContainer
@onready var choose_player : Button = $SelectionUI/SelectButtons/VBoxContainer/Choose

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

var game_root : GameManager = null

func _ready() -> void:
	if get_tree().current_scene is GameManager: game_root = get_tree().current_scene
	
	if player_set.player_container.get_child_count() > 0: 
		player_models = player_set.player_container.get_children()
	left_arrow.pressed.connect(_on_LeftArrow_pressed)
	right_arrow.pressed.connect(_on_RightArrow_pressed)
	choose_player.pressed.connect(_on_player_chosen)
	current_index = 0
	
	if game_root: 
		show_player_selection()

func show_player_selection():
	$SubViewportContainer.show()
	player_set.show()
	$SelectionUI.show()

func _on_LeftArrow_pressed():
	current_index = (current_index - 1 + player_models.size()) % player_models.size()

func _on_RightArrow_pressed():
	current_index = (current_index + 1) % player_models.size()

func _on_player_chosen():
	var cur_player : CharacterBody3D = player_models[current_index] # Get current player from player selection set
	var player_scene : PackedScene = get_player_scene_from_name(cur_player.name) # Get player scene
	character_cheer_animation(cur_player)
	await fade_out($SelectionUI/PlayerInfo/Change_Fade,1.0)
	
	# Use selected player scene and start game
	if game_root: game_root.initialize(player_scene)
	queue_free() # Finally, delete player selection

func character_cheer_animation(player):
	get_subject_animation_nodes(player)
	if subject_anim_player == null or subject_anim_tree == null: return
	var anim_state : AnimationNodeStateMachinePlayback = subject_anim_tree.get("parameters/AnimationNodeStateMachine/playback")
	subject_anim_tree.active = false
	subject_anim_tree.active = true
	anim_state.start("Cheer")

func get_subject_animation_nodes(player):
	for child in player.get_children():
		if child is AnimationPlayer: 
			subject_anim_player = child
		elif child is AnimationTree:
			subject_anim_tree = child

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("left"):
		_on_LeftArrow_pressed()
	elif event.is_action_pressed("right"):
		_on_RightArrow_pressed()

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
	for player in player_set.player_container.get_children():
		player.hide()
	player_models[current_index].show()
