@tool
extends GridMap
class_name WallGridSpawner


@export var start : bool = false : set = set_start
@export var clear_fill : bool = false : set = set_clear

@export_category("Parameters")
@export var source_gridmap : GridMap
@export var border_size : int = 20 : set = set_border_size
@export var fill_height : int = 4 : set = set_fill_height

var center_x = 0  # Assuming 0 is the center in the x direction
var center_z = 0  # Assuming 0 is the center in the z direction

# Spawn wall tiles
func set_start(val:bool)->void:
	start = val
	if Engine.is_editor_hint():
		if source_gridmap: iterate_grid_cells()

# Clear wall tiles
func set_clear(val:bool)->void:
	clear_fill = val
	if Engine.is_editor_hint():
		self.clear()

# Sets size of the red border square
# Tiles inside border are scanned for wall spawning
func set_border_size(val : int) -> void:
	border_size = val
	if Engine.is_editor_hint():
		visualize_border()

func visualize_border():
	if self: 
		self.clear()
		for i in range(-border_size, border_size + 1):
			self.set_cell_item(Vector3i(center_x + i, 0, center_z - border_size), 1)  # Top border
			self.set_cell_item(Vector3i(center_x + i, 0, center_z + border_size), 1)  # Bottom border
			self.set_cell_item(Vector3i(center_x - border_size, 0, center_z + i), 1)  # Left border
			self.set_cell_item(Vector3i(center_x + border_size, 0, center_z + i), 1)  # Right border

# Number of floors wall tiles will span
func set_fill_height(val : int) -> void:
	fill_height = val


func iterate_grid_cells():
	var positions = []
	self.clear()
	visualize_border()
	
	# Set all empty tiles from source gridmap to wall
	for x in range(-border_size + 1, border_size):
		for z in range(-border_size + 1, border_size):
			var pos = Vector3i(x, 0, z)
			if source_gridmap.get_cell_item(pos) == -1: # if empty tile
				self.set_cell_item(pos, 0)
				positions.append(pos)
	
	for y in range(fill_height):
		for t in positions:
			t.y = y
			if self.get_cell_item(t) == -1:
				self.set_cell_item(t,0)
				positions.append(t)
	
	print("Generated %s shadow boxes" % [positions.size()])
