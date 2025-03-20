class_name PlayerEffectsManager
extends Node3D

@onready var player = $".."
enum EffectType { BUFF, DEBUFF, STATUS}
var active_effects = []

var effect_types = {
	EffectType.BUFF : {"speed": speed_boost.get_method()},
	EffectType.DEBUFF : {"slow": slow_debuff.get_method()},
	EffectType.STATUS : {"freeze": freeze_status.get_method()}
}
var effect_types_names := ["BUFF", "DEBUFF", "STATUS"]

func _ready() -> void:
	pass # Replace with function body.

func load_effect_item(type:String):
	var e_type_arr = find_effect_dict(type)
	
	if e_type_arr.size() > 0: 
		start_effect(e_type_arr[0], e_type_arr[1])
		return true
	else: printerr("Item Used has no EffectType")
	return false

func find_effect_dict(type:String) -> Array:
	var key_to_find = type
	var dict : Dictionary = {}
	for effect_type in effect_types.keys():
		var effects_dict = effect_types[effect_type]
		
		if key_to_find in effects_dict:
			dict[key_to_find] = effects_dict[key_to_find]
			#print("PlayerEffectsManager: EffectType: ", effect_types_names[effect_type], \
			#" | Key:", key_to_find, " | Func:", effects_dict[key_to_find])
			return [effect_type, key_to_find, effects_dict[key_to_find]]
	return []
	
func start_effect(type: EffectType, e_name: String):
	if e_name in effect_types[type]:
		var effect_function = effect_types[type][e_name]
		match effect_function:
			"speed_boost": speed_boost()
			"slow_debuff": slow_debuff()
			"freeze_status": freeze_status()


func speed_boost():
	print("Blitz em")

func slow_debuff():
	print("Slow player speed for duration")

func freeze_status():
	print("Freeze player for duration")
