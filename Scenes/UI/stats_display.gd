extends Control

@onready var game_root
@onready var debug : TestDebug
@onready var fps : Label = $FPS

func _ready() -> void:
	if get_tree().current_scene is GameManager: game_root = get_tree().current_scene
	elif get_tree().current_scene is GameManagerMultiplayer: game_root = get_tree().current_scene
	debug = game_root.debug
	if debug: debug.fps_vis.connect(_on_fps_vis)

func _process(_delta: float) -> void:
	fps.text = "FPS - " + str(Engine.get_frames_per_second())

func _on_fps_vis(active):
	set_process(active)
	fps.visible = active
