class_name BaseItem extends Resource

enum ITEM_TYPE {COIN, POTION, SPECIAL_POTION, KEY, QUEST_ITEM}
var item_type_map = [
	0,  # COIN
	1,  # POTION
	2,  # SPECIAL_POTION
	3,  # KEY
	4,  # QUEST_ITEM
]
const ITEM_TYPE_NAMES := ["COIN", "POTION", "SPECIAL_POTION", "KEY", "QUEST_ITEM"]

@export var value : int
@export var mesh : Mesh
@export var type : ITEM_TYPE
@export var icon : CompressedTexture2D
@export var usable : bool
@export var removeable : bool
@export var player_removable : bool
@export var info : String
@export var max_stack_size : int

var special_name_type : String

func add_value(player: PlayerCharacter):
	match type:
		ITEM_TYPE.COIN:
			player.moneyAmount += value
			player.update_ui()
		ITEM_TYPE.POTION:
			player.potionAmount += value
			player.update_ui()
		ITEM_TYPE.SPECIAL_POTION:
			player.p_inv_controller.collect(self)
		ITEM_TYPE.QUEST_ITEM:
			player.p_inv_controller.collect(self)

func use(player: PlayerCharacter) -> bool:
	match type:
		ITEM_TYPE.SPECIAL_POTION:
			player.p_effects.load_effect_item(special_name_type)
			return true
	return false

func get_item_type_name() -> String:
	return ITEM_TYPE_NAMES[type]
