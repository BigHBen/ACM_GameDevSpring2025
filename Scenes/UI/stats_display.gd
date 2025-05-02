extends Control

@export var game_root : Node
@export var debug : TestDebug
@onready var fps : Label
@onready var ping : Label
var ping_val : float = 0 : set=update_ping_text

func _ready() -> void:
	if game_root is GameManager:
		fps = $FPS
		ping = null
	elif game_root is GameManagerMultiplayer:
		fps = $VBoxContainer/FPS
		ping = $VBoxContainer/Ping
		hide()
	else:
		if get_tree().current_scene is GameManager: 
			game_root = get_tree().current_scene
			fps = $FPS
			ping = null
		elif get_tree().current_scene is GameManagerMultiplayer: 
			game_root = get_tree().current_scene
			fps = $VBoxContainer/FPS
			ping = $VBoxContainer/Ping
			hide()
	if game_root: debug = game_root.debug
	if debug: 
		debug.fps_vis.connect(_on_fps_vis)
		debug.ping_vis.connect(_on_ping_vis)

func _process(_delta: float) -> void:
	fps.text = "FPS - " + str(Engine.get_frames_per_second())

func update_ping_text(val):
	ping_val = val
	ping.text = "PING - " + str(ping_val)

func _on_fps_vis(active):
	set_process(active)
	fps.visible = active

func _on_ping_vis(active):
	ping.visible = active
