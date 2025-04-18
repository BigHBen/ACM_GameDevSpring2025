@tool
extends GridMap
class_name CustomRooms

@export var start : bool = false : set = set_start
@export var refresh : bool = false : set = refresh_ranges
@export_category("Custom Room Edit")
@export var room_edit_border_size : int = 20 : set = set_room_edit_border
@export var room_edit_grid_map : GridMap
@export var create_room_area : GridMap
@export_range(1,10) var room_edit_grid_rows : int = 1 : set = set_room_edit_rows
@export_range(1,10) var room_edit_grid_cols : int = 1 : set = set_room_edit_cols

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
	5,  # BORDER
	1,  # HIGHLIGHT
	4,  # WALL
]

var room_tiles : Array[PackedVector3Array] = []
var room_positions : PackedVector3Array = []

var room_ranges: Array[Dictionary] = []
func get_room_ranges() -> Array:
	return room_ranges

func set_start(val:bool)->void:
	start = val
	if Engine.is_editor_hint() and start and room_edit_grid_map:
		if !room_ranges.is_empty(): 
			for i in range(0,room_ranges.size()):
				print("Room Space %s Positions: %s" % [i,get_room_space_tiles(i,false)])
		start = false
		#if mesh_customizer: 
			#mesh_customizer.start = false
		#generate()
		#print("Dungeon Generated")
		#start = false
		#if mesh_customizer and load_meshes: # If enabled, load desired meshes over source gridmap
			#mesh_customizer.start = true
		#if wallgrid_spawner: # If enabled, generate walls
			#if wallgrid_spawn:
				#wallgrid_spawner.start = true
			#else: wallgrid_spawner.clear_fill = true
		#
		## Lastly, move player into first room
		#var player_pos = Vector3(room_positions[0].x * 2,2,room_positions[0].z * 2)
		#var npc_pos = Vector3(room_positions[1].x * 2,1,room_positions[1].z * 2)
		#if level.is_in_group("Level"):
			#for child in level.get_children():
				#if child.is_in_group("Player"):
					#child.position = player_pos
				#if child.is_in_group("NPC"):
					#child.position = npc_pos
					#break

func refresh_ranges(val:bool):
	refresh = val
	set_room_edit_border(room_edit_border_size)
	refresh = false

# Change row parameter to refresh gridmap
func set_room_edit_rows(val:int):
	room_edit_grid_rows = val
	set_room_edit_border(room_edit_border_size)

# Change col parameter to refresh gridmap
func set_room_edit_cols(val:int):
	room_edit_grid_cols = val
	set_room_edit_border(room_edit_border_size)

func set_room_edit_border(val: int) -> void:
	room_ranges.clear()
	room_edit_border_size = val
	if Engine.is_editor_hint():
		if room_edit_grid_map:
			if room_edit_grid_rows > 0 and room_edit_grid_cols > 0:
				visualize_room_edit_grid(room_edit_grid_rows,room_edit_grid_cols)
				if room_ranges and !room_ranges.is_empty(): # TESTING
					scale_placeholder_mesh()
					print_room_ranges()
					#$PointTest.position = Vector3(room_ranges.back()["end"]) * 2
					#highlight_room_spaces()

func visualize_room_edit_grid(rows: int, cols: int):
	if room_edit_grid_map: room_edit_grid_map.clear()
	var offset_x : int = 0
	var offset_z : int = 0
	var start_pos : Vector3i
	for c in range(0, cols):
		for r in range(0, rows):
			for i in range(-1, room_edit_border_size + 1):
				room_edit_grid_map.set_cell_item(Vector3i(i + offset_x, 0, -1 + offset_z), get_tile_index(TileType.BORDER))      
				room_edit_grid_map.set_cell_item(Vector3i(i + offset_x, 0, room_edit_border_size + offset_z), get_tile_index(TileType.BORDER))
				room_edit_grid_map.set_cell_item(Vector3i(room_edit_border_size + offset_x, 0, i + offset_z), get_tile_index(TileType.BORDER))
				room_edit_grid_map.set_cell_item(Vector3i(-1 + offset_x, 0, i + offset_z), get_tile_index(TileType.BORDER))
			
			var start = Vector3i(offset_x,0,offset_z)
			var end = Vector3i(offset_x+room_edit_border_size,0,room_edit_border_size + offset_z)
			room_ranges.append({"start": start,"end": end})
			
			offset_x += room_edit_border_size + 1
		offset_x = 0
		offset_z += room_edit_border_size + 1

func get_tile_index(tile_type: TileType) -> int:
	return tile_index_map[tile_type]

# Places highlight blocks inside of each border outline space
# Mainly for testing; goal is to use it for custom room editing
# Goal - Create custom room layouts -> Use dungeon generator script to place and connect randomly
# You’ll place blocks in each border defined space -> It can be scanned later for dungeon procedural generation.
func highlight_room_spaces():
	for space in room_ranges:
		var start = space["start"]
		var end = space["end"]
		for x in range(start.x, end.x):  # Start from x+1 to avoid filling the borders
			for z in range(start.z, end.z):  # Start from z+1 to avoid filling the borders
				# Set the fill tile inside the room
				room_edit_grid_map.set_cell_item(Vector3(x, 0, z), get_tile_index(TileType.HIGHLIGHT))

func get_room_space_area(space_idx):
	var all_tile_positions: Array = []
	var start = room_ranges[space_idx]["start"]
	var end = room_ranges[space_idx]["end"]
	
	for x in range(start.x, end.x):  # Start from x+1 to avoid filling the borders
		for z in range(start.z, end.z):  # Start from z+1 to avoid filling the borders
			all_tile_positions.append(Vector3(x, 0, z))
	return all_tile_positions

func get_room_space_tiles(space_idx,vector2):
	if !create_room_area:
		printerr(self, ": No CreateRoom Gridmap Assigned")
		return
	
	var tiles = get_room_space_area(space_idx)
	var room_tiles : Array = []
	var tile_index
	var tile_count = 0
	if !tiles: return
	var detected_tiles = []
	$Test.clear()  # TESTING
	for i in range(0, tiles.size()):
		tile_index = create_room_area.get_cell_item(tiles[i]) 
		if tile_index != -1:
			detected_tiles.append(tiles[i])
			#if vector2: room_tiles.append(Vector2(rel_position.x,rel_position.z)) # OLD
			#else: room_tiles.append(rel_position)
			tile_count += 1
	
	for tile in detected_tiles: # After scanning for tiles in room space, shift to top-left corner (origin)
		var new_pos = shift_tiles_to_origin(tile,detected_tiles) 
		$Test.set_cell_item(Vector3i(new_pos+Vector3i(tiles[0])),get_tile_index(TileType.HIGHLIGHT))  # TESTING
		if vector2: room_tiles.append(Vector2(new_pos.x,new_pos.z)) # OLD
		else: room_tiles.append(new_pos)
	return room_tiles


func rotated_room_space_tiles(tile_positions: Array, steps: int):
	var grid_center = get_center(tile_positions)
	
	var rotated_positions = []
	for pos in tile_positions:
		var local_pos = Vector3(pos) - grid_center
		var rotated_local = Vector3(-local_pos.z, local_pos.y, local_pos.x)
		match steps:
			1: rotated_local = Vector3(-local_pos.z, local_pos.y, local_pos.x) # 90
			2: rotated_local = Vector3(-local_pos.x, local_pos.y, -local_pos.z) # 180
			3: rotated_local = Vector3(local_pos.z, local_pos.y, -local_pos.x) # 270°
		rotated_positions.append((rotated_local + grid_center).round())
	return rotated_positions


func get_center(positions: Array) -> Vector3:
	var pos_count = Vector3.ZERO
	for pos in positions: 
		pos_count += Vector3(pos)
	return (pos_count / positions.size())

func shift_tiles_to_origin(tile_position: Vector3,room_space_positions: Array):
	if room_space_positions.is_empty(): return tile_position
	var min_x = INF
	var min_z = INF
	for tile in room_space_positions:
		min_x = min(min_x, tile.x)
		min_z = min(min_z, tile.z)
	var offset = Vector3i(min_x,0,min_z)
	return Vector3i(tile_position) - offset

func scale_placeholder_mesh():
	var tile_positions = get_room_space_area(0)
	var plane_instance = $Placeholder
	var plane_mesh = plane_instance.mesh as PlaneMesh
	var min_pos = tile_positions[0]
	var max_pos = tile_positions[0]
	for pos in tile_positions:
		min_pos = min_length_vector(min_pos, pos)
		max_pos = max_length_vector(max_pos, pos)
	var area_size = max_pos - min_pos
	plane_mesh.size = Vector2((area_size.x + 1)* 2, (area_size.z+1) * 2)
	plane_instance.position = max_pos + Vector3(1,0,1)

func print_room_ranges():
	for i in room_ranges.size():
		var area = room_ranges[i]
		var start = area["start"]
		var end = area["end"]
		print("Room Space ", i, ": Start(", start.x, ", ", start.y, ", ", start.z, ") -> End(", end.x, ", ", end.y, ", ", end.z, ")")

static func min_length_vector(vecA:Vector3, vecB:Vector3) -> Vector3:
	var magA = vecA.length()
	var magB = vecB.length()
	
	return vecB if magA > magB else vecA

static func max_length_vector(vecA:Vector3, vecB:Vector3) -> Vector3:
	var magA = vecA.length()
	var magB = vecB.length()
	
	return vecB if magA < magB else vecA
