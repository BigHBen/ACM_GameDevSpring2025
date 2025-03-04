extends Resource
class_name Quest

@export var id: int
@export var title: String
@export var description: String
@export var is_completed: bool = false
@export var objectives: Array[String]
@export var rewards: Dictionary
