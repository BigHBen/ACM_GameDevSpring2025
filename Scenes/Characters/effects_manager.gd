class_name PlayerEffectsManager
extends Node3D

@onready var player = $".."
enum EffectType { BUFF, DEBUFF, STATUS}
var active_effects = []

var effect_types = {
	EffectType.BUFF : {"speed": speed_boost},
	EffectType.DEBUFF : {"slow": slow_debuff},
	EffectType.STATUS : {"freeze": freeze_status}
}

func _ready() -> void:
	pass # Replace with function body.

func load_potion(type:String):
	print(type)

func start_effect(type: EffectType, e_name: String):
	if e_name in effect_types[type]:
		var effect_function = effect_types[type][e_name]
		print(effect_function)

func speed_boost():
	pass

func slow_debuff():
	pass

func freeze_status():
	pass
