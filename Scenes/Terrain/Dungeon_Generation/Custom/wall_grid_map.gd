@tool
extends GridMap
class_name WallGridSpawner


@export var start : bool = false : set = set_start
@export var start_rect : bool = false : set = set_start_rect
@export var clear_fill : bool = false : set = set_clear
@export var keep : bool = false

@export_category("Parameters")
@export var dun_gen : DunGen
@export var source_gridmap : GridMap
@export var border_size : int = 20 : set = set_border_size
@export var border_size_x : int = 20 : set = set_border_size_x
@export var border_size_y : int = 20 : set = set_border_size_y
@export var fill_height : int = 4 : set = set_fill_height

var center_x = 0  # Assuming 0 is the center in the x direction
var center_z = 0  # Assuming 0 is the center in the z direction

# 6 tile types - used for mesh placement
enum TileType {
	ROOM,
	HALLWAY,
	DOOR,
	BORDER,
	HIGHLIGHT,
	WALL,
}

# Should find a better way to assign indexes
var tile_index_map = [
	0,  # ROOM
	2,  # HALLWAY
	3,  # DOOR
	1,  # BORDER
	1,  # HIGHLIGHT
	4,  # WALL
]

# Spawn wall tiles
func set_start(val:bool)->void:
	start = val
	if Engine.is_editor_hint() and start and source_gridmap:
		iterate_grid_cells()
		print("Walls Generated")
		start = false

func set_start_rect(val:bool)->void:
	start_rect = val
	if Engine.is_editor_hint() and start_rect and source_gridmap:
		iterate_grid_cells_rect()
		print("Walls Generated")
		start_rect = false

# Clear wall tiles
func set_clear(val:bool)->void:
	clear_fill = val
	if Engine.is_editor_hint() and clear_fill:
		self.clear()
		clear_fill = false

func set_border_size_x(val : int) -> void:
	border_size_x = val
	if Engine.is_editor_hint() and !keep:
		#center_x = int(border_size / 2)
		#center_z = int(border_size / 2)
		visualize_border_new()

func set_border_size_y(val : int) -> void:
	border_size_y = val
	if Engine.is_editor_hint() and !keep:
		#center_x = int(border_size / 2)
		#center_z = int(border_size / 2)
		visualize_border_new()

# Sets size of the red border square
# Tiles inside border are scanned for wall spawning
func set_border_size(val : int) -> void:
	border_size = val
	if Engine.is_editor_hint() and !keep:
		#center_x = int(border_size / 2)
		#center_z = int(border_size / 2)
		visualize_border()

func visualize_border_new():
	self.clear()
	if dun_gen and source_gridmap: 
		var _center = (border_size / 2) * cell_size.x
		#self.position = Vector3(center,0,center)
	for i in range(-border_size_x, border_size_x + 1):
		self.set_cell_item(Vector3i(i, 0, -border_size_y), self.get_tile_index(TileType.BORDER))
	for i in range(-border_size_x, border_size_x + 1):
		self.set_cell_item(Vector3i(i, 0, border_size_y + 1), self.get_tile_index(TileType.BORDER))
	for i in range(-border_size_y, border_size_y + 1):
		self.set_cell_item(Vector3i(-border_size_x, 0, i), self.get_tile_index(TileType.BORDER))
	for i in range(-border_size_y, border_size_y + 1):
		self.set_cell_item(Vector3i(border_size_x + 1, 0, i), self.get_tile_index(TileType.BORDER))

func visualize_border():
	self.clear()
	if dun_gen and source_gridmap: 
		var center = (border_size / 2) * cell_size.x
		self.position = Vector3(center,0,center)
	for i in range(-border_size, border_size + 1):
		self.set_cell_item(Vector3i(i, 0, -border_size), self.get_tile_index(TileType.BORDER))  # Bottom
		self.set_cell_item(Vector3i(i, 0, border_size + 1), self.get_tile_index(TileType.BORDER))  # Top
		self.set_cell_item(Vector3i(-border_size, 0, i), self.get_tile_index(TileType.BORDER))  # Left
		self.set_cell_item(Vector3i(border_size + 1, 0, i), self.get_tile_index(TileType.BORDER))  # Right

func clear_border(node : GridMap):
	for i in range(-border_size, border_size + 1):
		node.set_cell_item(Vector3i(i, 0, -border_size), -1)  # Bottom
		node.set_cell_item(Vector3i(i, 0, border_size + 1), -1)  # Top
		node.set_cell_item(Vector3i(-border_size, 0, i), -1)  # Left
		node.set_cell_item(Vector3i(border_size + 1, 0, i), -1)  # Right

#func visualize_border_centered():
		#self.clear()
		#for i in range(-border_size, border_size + 1):
			#self.set_cell_item(Vector3i(center_x + i, 0, center_z - border_size), get_tile_index(TileType.BORDER))
			#self.set_cell_item(Vector3i(center_x + i, 0, center_z + border_size), get_tile_index(TileType.BORDER))
			#self.set_cell_item(Vector3i(center_x - border_size, 0, center_z + i), get_tile_index(TileType.BORDER)) 
			#self.set_cell_item(Vector3i(center_x + border_size, 0, center_z + i), get_tile_index(TileType.BORDER)) 

func get_tile_index(tile_type: TileType) -> int:
	return tile_index_map[tile_type]

# Number of floors wall tiles will span
func set_fill_height(val : int) -> void:
	fill_height = val


func iterate_grid_cells_rect():
	var positions = []
	self.clear()
	
	# Get the GridMap's world position (its transform in the scene)
	var gridmap_position = Vector3i(self.transform.origin)
	
	# Define the range for iterating based on border_size_x and border_size_y
	var border_start_x = -border_size_x + gridmap_position.x/2
	var border_end_x = border_size_x + gridmap_position.x/2
	var border_start_z = -border_size_y + gridmap_position.z/2
	var border_end_z = border_size_y + gridmap_position.z/2
	
	# Iterate over the grid in the defined rectangular area
	for x in range(border_start_x, border_end_x + 1):
		for z in range(border_start_z, border_end_z + 1):
			var pos = Vector3i(x, 0, z)
			
			#print(pos+gridmap_position/2)
			# If the grid cell is empty, place a wall block
			if source_gridmap.get_cell_item(pos) == -1:  # If empty tile
				# Adjust the position to take the GridMap's transform into account
				#var world_pos = gridmap_position + Vector3(x, 0, z)
				
				self.set_cell_item(pos-gridmap_position/2, 0)  # Set the tile in the target gridmap
				positions.append(pos-gridmap_position/2)  # Add position to the list of positions

	for y in range(fill_height):
		for t in positions:
			t.y = y
			if self.get_cell_item(t) == -1:
				self.set_cell_item(t,0)
				positions.append(t)
	
	#self.position = Vector3i.ZERO
	print("Generated %s shadow boxes" % [positions.size()])

func iterate_grid_cells():
	var positions = []
	self.clear()
	#visualize_border()
	
	#for x in range(-border_size + 1, border_size): # If centered
		#for z in range(-border_size + 1, border_size):
	# Set all empty tiles from source gridmap to wall
	var adjustment1 = 0
	var adjustment2 = 1
	
	var border_start = -border_size+adjustment1
	var border_end = border_size*adjustment2
	if dun_gen: 
		adjustment1 = 0
		var offset_x = border_size/2 # Change this to match the actual offset in X
		var offset_z = border_size/2
		border_start = -border_size + offset_x
		border_end = border_size + offset_z
	for x in range(border_start, border_end): # If not centered
		for z in range(border_start, border_end):
			#@warning_ignore("narrowing_conversion")
			#var self_position_i = Vector3i(self.position.x, self.position.y, self.position.z)
			var pos = Vector3i(x, 0, z)
			if dun_gen:
				if source_gridmap.get_cell_item(pos) == dun_gen.get_tile_index(dun_gen.TileType.BORDER):
					source_gridmap.set_cell_item(pos,-1)
				if source_gridmap.get_cell_item(pos) == -1: # if empty tile
					self.set_cell_item(pos, 0)
					positions.append(pos)
			else:
				if source_gridmap.get_cell_item(pos) == -1: # if empty tile
					self.set_cell_item(pos, 0)
					positions.append(pos)
	
	for y in range(fill_height):
		for t in positions:
			t.y = y
			if self.get_cell_item(t) == -1:
				self.set_cell_item(t,0)
				positions.append(t)
	
	self.position = Vector3i.ZERO
	print("Generated %s shadow boxes" % [positions.size()])
