extends Node
class_name GameManager

@export var debug : TestDebug

@onready var level_container : Node = $Level
var level_itr : int : # Iterate through levels array
	set (val):
		level_itr = val
		if level_itr < levels.size(): change_level(levels[level_itr])
		else: printerr($".", " Error: No more levels to load - Add more scene elements to 'levels' Array")
	get: return level_itr

@export var ui_control : CanvasLayer
@export var players : Array[CharacterBody3D]
@export var start_level_idx : int = 0
@export var levels : Array[PackedScene]

signal _on_game_paused(is_paused : bool)
var game_paused : bool = false :
	set(val):
		game_paused = val
		get_tree().paused = game_paused
		_on_game_paused.emit(game_paused)
	get:
		return game_paused

func _ready() -> void:
	if levels.is_empty(): 
		printerr($".", " Error: No levels to load - Add scene elements to 'levels' Array")
		await get_tree().create_timer(1.0).timeout
		get_tree().call_deferred("quit")
	else: load_first_level()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		game_paused = !game_paused
	if event.is_action_pressed("test_level_skip"): # Autoskip levels - Testing
		if level_itr >= 0: next_level()
		else: load_first_level()

func change_level(new_level_scene: PackedScene):
	var current_level = level_container.get_child(0) if level_container.get_child_count() > 0 else null
	if current_level and current_level.is_in_group("Level"):
		current_level.call_deferred("queue_free")
	
	var new_level : Node3D = load(new_level_scene.resource_path).instantiate()
	for player in players:
		if player != null: 
			player.position = new_level.player_spawn_point
			player.interact.entered_areas.clear()
	
	level_container.add_child(new_level)
	new_level.owner = get_tree().current_scene
	#self.move_child(new_level,0)


func load_first_level():
	level_itr = start_level_idx

func next_level():
	level_itr += 1
