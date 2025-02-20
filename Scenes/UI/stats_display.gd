extends Control

@onready var debug = get_node("/root/Debug")
@onready var fps : Label = $FPS

func _ready() -> void:
	
	debug.fps_vis.connect(_on_fps_vis)

func _process(_delta: float) -> void:
	fps.text = "FPS - " + str(Engine.get_frames_per_second())

func _on_fps_vis(active):
	set_process(active)
	fps.visible = active
