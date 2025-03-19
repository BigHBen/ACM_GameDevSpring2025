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
var effect_types_names := ["BUFF", "DEBUFF", "STATUS"]

func _ready() -> void:
	pass # Replace with function body.

func load_effect_item(type:String):
	var effect_type_arr = find_effect_dict(type)
	
	if effect_type_arr.size() > 0: pass
	else: printerr("Item Used has no EffectType")

func find_effect_dict(type:String) -> Array:
	var key_to_find = type
	var dict : Dictionary = {}
	for effect_type in effect_types.keys():
		var effects_dict = effect_types[effect_type]
		
		if key_to_find in effects_dict:
			dict[key_to_find] = effects_dict[key_to_find]
			print("PlayerEffectsManager: EffectType: ", effect_types_names[effect_type], \
			" | Key:", key_to_find, " | Func:", effects_dict[key_to_find])
			return [key_to_find, effects_dict[key_to_find]]
	return []
	
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
