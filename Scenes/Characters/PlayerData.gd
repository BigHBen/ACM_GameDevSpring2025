class_name PlayerData extends Resource

enum PLAYER_TYPE {KNIGHT, BARBARIAN, ROGUE, MAGE}
var item_type_map = [
	0,  # KNIGHT
	1,  # BARBARIAN
	2,  # ROGUE
	3,  # MAGE
]
const ITEM_TYPE_NAMES := ["KNIGHT", "BARBARIAN", "ROGUE", "MAGE"]

const MAX_HEALTH : int= 100
const MAX_SPEED : float = 7.5

@export var type : PLAYER_TYPE
@export var display_name : String
@export var description : String
@export_range(0,MAX_HEALTH) var hp : int
@export_range(0,MAX_SPEED) var speed : float
@export var icon : Texture2D

func get_item_type_name() -> String:
	return ITEM_TYPE_NAMES[type]
