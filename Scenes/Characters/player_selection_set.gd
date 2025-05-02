class_name PlayerSelectionSet extends Node3D


@export_range(0,2) var preview_player_speed : float = 0.25
@onready var camera : Camera3D = $Camera3D
@onready var player_container : Node3D = $Set/Subjects

var subjects : Array = []
var cur_subject : CharacterBody3D :
	set(val):
		cur_subject = val
		for subject in subjects:
			subject.hide()
		cur_subject.show()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in $Set/Subjects.get_children():
		subjects.append(child)
	
	if subjects.size() > 0: cur_subject = subjects[0]

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for subject in subjects:
		subject.rotate_y(delta * preview_player_speed)
