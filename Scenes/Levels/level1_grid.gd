@tool
extends GridMap

@export var start : bool = false : set = set_start
@export var clear_fill : bool = false : set = set_clear
@onready var grid_map2 : GridMap = $"../level1_Grid2"
@export var border_size : int = 100 : set = set_border_size
@export var fill_height : int = 4 : set = set_fill_height

var center_x = 0  # Assuming 0 is the center in the x direction
var center_z = 0  # Assuming 0 is the center in the z direction

func set_start(val:bool)->void:
	start = val
	if Engine.is_editor_hint():
		iterate_grid_cells()

func set_clear(val:bool)->void:
	clear_fill = val
	if Engine.is_editor_hint() and grid_map2:
		grid_map2.clear()

func set_border_size(val : int) -> void:
	border_size = val
	if Engine.is_editor_hint():
		visualize_border()

func visualize_border():
	if grid_map2: 
		grid_map2.clear()
		for i in range(-border_size, border_size + 1):
			grid_map2.set_cell_item(Vector3i(center_x + i, 0, center_z - border_size), 1)  # Top border
			grid_map2.set_cell_item(Vector3i(center_x + i, 0, center_z + border_size), 1)  # Bottom border
			grid_map2.set_cell_item(Vector3i(center_x - border_size, 0, center_z + i), 1)  # Left border
			grid_map2.set_cell_item(Vector3i(center_x + border_size, 0, center_z + i), 1)  # Right border

func set_fill_height(val : int) -> void:
	fill_height = val

func iterate_grid_cells():
	var positions = []
	if grid_map2:
		grid_map2.clear()
		visualize_border()
		
		for x in range(-border_size + 1, border_size):
			for z in range(-border_size + 1, border_size):
				var pos = Vector3i(x, 0, z)
				if self.get_cell_item(pos) == -1:
					grid_map2.set_cell_item(pos, 0)
					positions.append(pos)
		
		for y in range(fill_height):
			for t in positions:
				t.y = y
				if grid_map2.get_cell_item(t) == -1:
					grid_map2.set_cell_item(t,0)
					positions.append(t)
		print("Generated %s shadow boxes" % [positions.size()])
