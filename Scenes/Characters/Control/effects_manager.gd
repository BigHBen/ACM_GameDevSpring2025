class_name PlayerEffectsManager
extends Node3D

@onready var player = $".."

# GPUParticle Nodes - For potions, attacks, transformations, etc
@onready var aura_flame : GPUParticles3D = $Effects/Aura_Flame
@onready var orb_particles : GPUParticles3D = $Effects/Orb_Particles
@onready var glow_light : OmniLight3D = $Effects/Effects_Light

enum EffectType { BUFF, DEBUFF, STATUS}
var active_effects = []
var item_consuming : bool = false

var effect_types = {
	EffectType.BUFF : {"speed": speed_boost.get_method()},
	EffectType.DEBUFF : {"slow": slow_debuff.get_method()},
	EffectType.STATUS : {"freeze": freeze_status.get_method()}
}
var effect_types_names := ["BUFF", "DEBUFF", "STATUS"]

# Armor
var current_armor : int
enum ArmorType { CHEST_DEFAULT, CHEST_GOLD, CHEST_DIAMOND, HELM_DEFAULT, HELM_GOLD, HELM_DIAMOND}
var armor_types = {
	ArmorType.CHEST_DEFAULT : {"chest_default": "res://Assets/RPG/KayKit_Adventurers_1.0_FREE/KayKit_Adventurers_1.0_FREE/Characters/gltf/knight_body.res"},
	ArmorType.CHEST_GOLD : {"chest_gold": "res://Assets/RPG/KayKit_Adventurers_1.0_FREE/KayKit_Adventurers_1.0_FREE/Characters/gltf/knight_body_gold.res"},
	ArmorType.CHEST_DIAMOND: {"chest_diamond": "res://Assets/RPG/KayKit_Adventurers_1.0_FREE/KayKit_Adventurers_1.0_FREE/Characters/gltf/knight_body_diamond.res"},
	
	ArmorType.HELM_DEFAULT : {"helm_default": "res://Assets/RPG/KayKit_Adventurers_1.0_FREE/KayKit_Adventurers_1.0_FREE/Characters/gltf/knight_helmet.res"},
	ArmorType.HELM_GOLD : {"helm_gold": "res://Assets/RPG/KayKit_Adventurers_1.0_FREE/KayKit_Adventurers_1.0_FREE/Characters/gltf/knight_helmet_gold.res"},
	ArmorType.HELM_DIAMOND: {"helm_diamond": "res://Assets/RPG/KayKit_Adventurers_1.0_FREE/KayKit_Adventurers_1.0_FREE/Characters/gltf/knight_helmet_diamond.res"}
}
var armor_types_names := ["CHEST_DEFAULT", "CHEST_GOLD", "CHEST_DIAMOND", "HELM_DEFAULT", "HELM_GOLD", "HELM_DIAMOND"]

# Effect states
var speed_boost_active : bool = false

func _ready() -> void:
	if player: current_armor = ArmorType.CHEST_DEFAULT

func load_effect_item(type:String):
	var e_type_arr = find_item_dict(type,effect_types)
	
	if e_type_arr.size() > 0: 
		start_effect(e_type_arr[0], e_type_arr[1])
		return true
	else: printerr("Item Used has no EffectType")
	return false

func load_armor(type: String):
	var a_type_arr = find_item_dict(type,armor_types)
	if a_type_arr: 
		var new_mesh : ArrayMesh = load(a_type_arr.back())
		if armor_types_names[a_type_arr[0]].to_lower().find("chest") != -1:
			player.chest_mesh.mesh = new_mesh
			player.chest_mesh.force_update_transform()
			current_armor = a_type_arr[0]
		elif armor_types_names[a_type_arr[0]].to_lower().find("helm") != -1:
			if !player.helm_mesh.visible: player.helm_mesh.visible = true
			player.helm_mesh.mesh = new_mesh
			player.helm_mesh.force_update_transform()
		
		var item_consumption = 1.0
		var dress_timer = 0.0
		player.anim_state.travel("Use_Item")
		while dress_timer < item_consumption:
			item_consuming = true
			dress_timer += get_process_delta_time()
			await get_tree().process_frame
		item_consuming = false

func find_item_dict(type:String, types_dict : Dictionary) -> Array:
	var key_to_find = type
	var dict : Dictionary = {}
	for i_type in types_dict.keys():
		var i_dict = types_dict[i_type]
		
		if key_to_find in i_dict:
			dict[key_to_find] = i_dict[key_to_find]
			#print("PlayerEffectsManager: EffectType: ", effect_types_names[effect_type], \
			#" | Key:", key_to_find, " | Func:", effects_dict[key_to_find])
			return [i_type, key_to_find, dict[key_to_find]]
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
	var item_consumption = 1.0
	var drinking_timer = 0.0
	player.anim_state.travel("Use_Item")
	
	var p_mat : ParticleProcessMaterial = orb_particles.process_material
	var _default_mat_color = p_mat.color
	
	while drinking_timer < item_consumption:
		item_consuming = true
		launch_particles(p_mat,Color.GREEN)
		drinking_timer += get_process_delta_time()
		
		await get_tree().process_frame
	item_consuming = false
	stop_particles(p_mat)
	
	# Start speed boost buff
	speed_boost_active = true
	if speed_boost_active: 
		player.speed = player.speed * 2
		start_speed_boost_timer()

func start_speed_boost_timer():
	glow_light.light_color = Color.KHAKI
	glow_light.light_energy = 5.0
	await get_tree().create_timer(6).timeout
	glow_light.light_color = Color.WHITE
	glow_light.light_energy = 0.0
	
	player.speed = player.speed / 2
	speed_boost_active = false
	print("Speed boost over")

func slow_debuff():
	print("Slow player speed for duration")

func freeze_status():
	print("Freeze player for duration")

func launch_particles(mat,c : Color):
	
	mat.color = c
	orb_particles.emitting = true
	glow_light.light_color = c
	if glow_light.light_energy < 1.0:
		glow_light.light_energy = lerp(glow_light.light_energy, 1.0, get_process_delta_time() * 2)

func stop_particles(_mat):
	orb_particles.emitting = false
	while glow_light.light_energy > 0.0:
		glow_light.light_energy = lerp(glow_light.light_energy, 0.0, get_process_delta_time() * 2)
		await get_tree().process_frame
