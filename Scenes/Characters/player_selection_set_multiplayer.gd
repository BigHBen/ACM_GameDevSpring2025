class_name PlayerSelectionSetMultiplayer extends Node3D


@export_range(0,2) var preview_player_speed : float = 0.25
@onready var camera : Camera3D = $Camera3D
@onready var player_container : Node3D = $Set/Subjects

var subjects : Array = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in $Set/Subjects.get_children():
		subjects.append(child)
	set_process(false)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for subject in subjects:
		subject.rotate_y(delta * preview_player_speed)
