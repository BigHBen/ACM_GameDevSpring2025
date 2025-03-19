class_name BaseItem extends Resource

enum ITEM_TYPE {COIN, POTION, SPECIAL_POTION, KEY, QUEST_ITEM}

@export var value : int
@export var mesh : Mesh
@export var type : ITEM_TYPE
@export var icon : CompressedTexture2D
@export var usable : bool
@export var removeable : bool
@export var info : String

var special_potion_type : String

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

func use(player: PlayerCharacter):
	match type:
		ITEM_TYPE.SPECIAL_POTION:
			player.p_effects.load_potion(special_potion_type)
			return true
