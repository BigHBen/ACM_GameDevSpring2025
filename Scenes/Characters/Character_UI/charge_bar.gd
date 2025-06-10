class_name FloatingChareBar extends ProgressBar

var new_stylebox_normal : StyleBoxFlat
var default_color : Color
var flash_on : bool = false

func _ready() -> void:
	new_stylebox_normal = self.get_theme_stylebox("fill").duplicate()
	default_color = new_stylebox_normal.bg_color

func charge_max_flash(time):
	flash_on = !flash_on
	if flash_on: 
		new_stylebox_normal.bg_color = Color("White")
	else:
		new_stylebox_normal.bg_color = default_color
	self.add_theme_stylebox_override("fill",new_stylebox_normal)
	await get_tree().create_timer(time).timeout

func reset():
	new_stylebox_normal.bg_color = default_color
	self.add_theme_stylebox_override("fill",new_stylebox_normal)
