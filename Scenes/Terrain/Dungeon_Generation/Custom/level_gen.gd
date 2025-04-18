@tool
extends Node3D
class_name LevelGen

@export var tile_layout_grid_map : GridMap
@export var level : Node3D
@export var start : bool = false : set = set_start
@export var load_meshes : bool = false
@export var wallgrid_spawn : bool = false : set = set_wall_grid_spawn
@export var print_info : bool = false

@export_category("GridMap Parameters")
@export_range(0,1) var survival_chance : float = 0.25
@export var border_size : int = 20 : set = set_border_size
@export var mesh_customizer : GridMapMeshCustomizer
@export var wallgrid_spawner : WallGridSpawner

@export_category("Custom Room Edit")
@export var custom_rooms_grid_map : GridMap
@export var enable_room_alignment : bool = false

@export_category("Room Parameters")
@export var room_number : int = 4
@export var room_margin : int = 1

@export var room_recursion : int = 15
@export var min_room_size : int = 2
@export var max_room_size : int = 4
@export_category("Hallway Parameters")
@export var min_hallway_width : int = 4
@export var max_hallway_width : int = 8
@export_category("Seed")
@export_multiline var custom_seed : String = "" : set = set_seed

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

var center_x = 0 
var center_z = 0 
var hallway_graph : AStar2D

func set_seed(val:String)-> void:
		custom_seed = val
		seed(val.hash())

var room_tiles : Array[PackedVector3Array] = []
var hallway_tiles : Array[PackedVector3Array] = []
var room_positions : PackedVector3Array = []

func _enter_tree() -> void:
	if Engine.is_editor_hint():
		load_meshes = false
		randomize()

func set_start(val:bool)->void:
	start = val
	if Engine.is_editor_hint() and start and tile_layout_grid_map:
		if mesh_customizer: 
			mesh_customizer.start = false
		if !tile_layout_grid_map: 
			start = false
			printerr("No TileLayoutGridMap Assigned")
		
		generate()
		
		# Extras
		if mesh_customizer and load_meshes: # If enabled, load desired meshes over source gridmap
			mesh_customizer.start = true
		if wallgrid_spawner: # If enabled, generate walls
			if wallgrid_spawn:
				wallgrid_spawner.start = true
			else: wallgrid_spawner.clear_fill = true
		
		# Lastly, move player into first room
		if !room_positions.is_empty() and room_positions.size() > 1:
			var player_pos = Vector3(room_positions[0].x * 2,2,room_positions[0].z * 2)
			var npc_pos = Vector3(room_positions[1].x * 2,1,room_positions[1].z * 2)
			if level and level.is_in_group("Level"):
				for child in level.get_children():
					if child.is_in_group("Player"):
						child.position = player_pos
					if child.is_in_group("NPC"):
						child.position = npc_pos
						break
		
		start = false

func set_wall_grid_spawn(val : bool):
	wallgrid_spawn = val
	if !wallgrid_spawner: 
		wallgrid_spawn = false
		printerr("No WallgridSpawner Assigned")

func set_border_size(val : int) -> void:
	border_size = val
	if Engine.is_editor_hint():
		if tile_layout_grid_map:
			#visualize_room_edit_grid(2,2)
			visualize_border()
		if mesh_customizer: mesh_customizer.border_size = val
		if wallgrid_spawner: wallgrid_spawner.border_size = val# - 10

func visualize_border():
	if tile_layout_grid_map: tile_layout_grid_map.clear()
	for i in range(-1, border_size+1):
		tile_layout_grid_map.set_cell_item(Vector3i(i,0,-1),get_tile_index(TileType.BORDER))
		tile_layout_grid_map.set_cell_item(Vector3i(i,0,border_size),get_tile_index(TileType.BORDER))
		tile_layout_grid_map.set_cell_item(Vector3i(border_size,0,i),get_tile_index(TileType.BORDER))
		tile_layout_grid_map.set_cell_item(Vector3i(-1,0,i),get_tile_index(TileType.BORDER))


func visualize_border_centered():
	if tile_layout_grid_map: tile_layout_grid_map.clear()
	for i in range(-border_size, border_size + 1):
		tile_layout_grid_map.set_cell_item(Vector3i(center_x + i, 0, center_z - border_size), get_tile_index(TileType.BORDER))
		tile_layout_grid_map.set_cell_item(Vector3i(center_x + i, 0, center_z + border_size), get_tile_index(TileType.BORDER))
		tile_layout_grid_map.set_cell_item(Vector3i(center_x - border_size, 0, center_z + i), get_tile_index(TileType.BORDER))
		tile_layout_grid_map.set_cell_item(Vector3i(center_x + border_size, 0, center_z + i), get_tile_index(TileType.BORDER))


func get_tile_index(tile_type: TileType) -> int:
	return tile_index_map[tile_type]

# Heavily modified code from Procedural Dungeons in Godot 4 - https://youtu.be/h64U6j_sFgs
# Modifications - Added variable hallway widths, added wall tiles that generate around rooms and hallways, 
# Added highlight tile for testing, integrated with GridMapMeshCustomizer and WallGridSpawner
func generate():
	room_tiles.clear()
	hallway_tiles.clear()
	room_positions.clear()
	if custom_seed : set_seed(custom_seed)
	visualize_border()
	for i in room_number:
		if custom_rooms_grid_map: spawn_custom_rooms(room_recursion)
		else: make_room(room_recursion)
	#return # Fix custom rooms first
	
	var rpv2 : PackedVector2Array = []
	var del_graph : AStar2D = AStar2D.new()
	var mst_graph : AStar2D = AStar2D.new()
	for p in room_positions: # For each generated room, create node point
		rpv2.append(Vector2(p.x,p.z))
		del_graph.add_point(del_graph.get_available_point_id(),Vector2(p.x,p.z))
		mst_graph.add_point(mst_graph.get_available_point_id(),Vector2(p.x,p.z))
	
	var delaunay : Array = Array(Geometry2D.triangulate_delaunay(rpv2))
	
	if room_positions.size() <= 2: # Breaks if two or less rooms (idk)
		print("Room count too small to create MST!")
		place_border_around_tiles(room_tiles,hallway_tiles,get_tile_index(TileType.WALL))
		return null
	for i in float(delaunay.size())/3.0: # Scan for triangles -> Create delauney graph connections
		var p1 : int = delaunay.pop_front()
		var p2 : int = delaunay.pop_front()
		var p3 : int = delaunay.pop_front()
		del_graph.connect_points(p1,p2)
		del_graph.connect_points(p2,p3)
		del_graph.connect_points(p1,p3)
	
	# Testing
	# For each room node in delauney graph, print its position and connections to other rooms
	if print_info:
		for id in del_graph.get_point_ids():
			print("Point ID: ", id, " Position: ", del_graph.get_point_position(id), " Connections: ", \
			del_graph.get_point_connections(id))
			
			# Testing
			var test_pos_x = del_graph.get_point_position(id).x * tile_layout_grid_map.cell_size.x
			var test_pos_z = del_graph.get_point_position(id).y * tile_layout_grid_map.cell_size.z
			var _test_pos = Vector3(test_pos_x,0,test_pos_z)
			#$Marker3D.position = test_pos
	
	var visited_points : PackedInt32Array = []
	visited_points.append(randi()% room_positions.size())
	
	# Not quite sure what's going on here
	while visited_points.size() != mst_graph.get_point_count():
		var possible_connections : Array[PackedInt32Array] = []
		for vp in visited_points:
			for c in del_graph.get_point_connections(vp):
				if !visited_points.has(c):
					var con : PackedInt32Array = [vp,c]
					possible_connections.append(con)
		
		var connection = possible_connections.pick_random()
		for pc in possible_connections:
			if rpv2[pc[0]].distance_squared_to(rpv2[pc[1]]) <\
			rpv2[connection[0]].distance_squared_to(rpv2[connection[1]]):
				connection = pc
		
		visited_points.append(connection[1])
		mst_graph.connect_points(connection[0],connection[1])
		del_graph.disconnect_points(connection[0], connection[1])
	
	hallway_graph = mst_graph
	
	# Iterate through all points and their connections in delauney graph 
	# For each connection, Randomly decide whether to connect the points in MST based on survival_chance
	for p in del_graph.get_point_ids():
		for c in del_graph.get_point_connections(p):
			if c>p:
				var kill : float = randf()
				if survival_chance > kill:
					hallway_graph.connect_points(p,c)
	
	var _path = hallway_graph.get_point_path(0, hallway_graph.get_point_count()-1)
	
	create_hallways(hallway_graph)
	print("Generating....")
	place_border_around_tiles(room_tiles,hallway_tiles,get_tile_index(TileType.WALL))
	print("Dungeon Generated")

func create_hallways(h_graph:AStar2D):
	var hallways : Array = []
	var hall_widths = {}
	for p in h_graph.get_point_ids():
		for c in h_graph.get_point_connections(p):
			if c>p: # Directed MST Graph -> run once per edge
				# MST Graph - Print Room Nodes and edges
				if print_info: print("ID: ",p," Connection: ", c, " | [%s->%s]" % [p,c])
				var room_from : PackedVector3Array= room_tiles[p]
				var room_to : PackedVector3Array= room_tiles[c]
				
				# Old - Calculate shortest tile (1 tile hallway width)
				#var tile_from : Vector3 = room_from[0]
				#var tile_to : Vector3 = room_to[0]
				
				# New - Calculate shortest set of tiles (variable hallway width)
				var tiles_from : PackedVector3Array = []
				var tiles_to : PackedVector3Array = []
				
				# Calculate minimum room size between two rooms
				# Set limits for random hallway width
				var min_room_edge_length = min(min(get_room_dimensions(room_from).x, get_room_dimensions(room_from).y),
					min(get_room_dimensions(room_to).x, get_room_dimensions(room_to).y))
				
				var adjusted_width = min(max_hallway_width, min_room_edge_length)
				if print_info: print("Min hallway width: ", min_room_edge_length)
				
				var random_width = randi_range(min_hallway_width, adjusted_width)
				# Select four tiles for each room
				tiles_from = select_shortest_tiles(room_from, room_positions[c], random_width)
				tiles_to = select_shortest_tiles(room_to, room_positions[p], random_width)
				
				# Print set of tiles (shortest distance)
				if print_info:
					print("Shortest Tiles from: ", tiles_from)
					print("Shortest Tiles to: ", tiles_to)
				for tile in tiles_from:
					# Place door tiles connecting to room_to
					tile_layout_grid_map.set_cell_item(Vector3i(tile), get_tile_index(TileType.DOOR))
				for tile in tiles_to:
					# Place door tiles connecting from room_from
					tile_layout_grid_map.set_cell_item(Vector3i(tile), get_tile_index(TileType.DOOR))
				
				var hallway = [tiles_from, tiles_to]
				hall_widths[str(tiles_from,tiles_to)] = random_width
				hallways.append(hallway) # Set of hallway tiles stored for later
	# After 
	create_wide_hallways(hallways,hall_widths)

func create_wide_hallways(hallways : Array, widths: Dictionary):
	var hall_widths = widths
	if print_info: print("Creating AStarGrid2D...")
	var astar : AStarGrid2D = AStarGrid2D.new()
	astar.size = Vector2i.ONE * border_size
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	#astar.cell_shape = AStarGrid2D.CELL_SHAPE_MAX
	astar.update()
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	
	if print_info: print("Setting point solid..")
	for t in tile_layout_grid_map.get_used_cells_by_item(0):
		astar.set_point_solid(Vector2i(t.x,t.z))
	
	if print_info: print("Iterating through hallways")
	var h_tiles : PackedVector3Array = []
	for h in hallways:
		
		var tiles_from = h[0]  # List of tiles from
		var tiles_to = h[1]    # List of tiles to
		
		var hallway_width = hall_widths[str(tiles_from,tiles_to)]
		if print_info: 
			print("Hallway width: ",hallway_width)
			print("Hallway: \n    Tiles from: %s\n    Tiles to: %s" % [tiles_from, tiles_to])
		for i in range(min(tiles_from.size(), tiles_to.size())):
			var pos_from : Vector2i = Vector2i(int(tiles_from[i].x), int(tiles_from[i].z))
			var pos_to : Vector2i = Vector2i(int(tiles_to[i].x), int(tiles_to[i].z))
			#print("(",pos_from, ", ", pos_to,")")
			var hall : PackedVector2Array = astar.get_point_path(pos_from, pos_to)
			for t in hall:
				var pos : Vector3i = Vector3i(int(t.x), 0, int(t.y))
				if tile_layout_grid_map.get_cell_item(pos) < 0:
					tile_layout_grid_map.set_cell_item(pos, get_tile_index(TileType.HALLWAY))
					#var hallway = [tiles_from, tiles_to]
					h_tiles.append(pos)
		hallway_tiles.append(h_tiles)

func select_shortest_tiles(room: PackedVector3Array, room_position: Vector3,width: int) -> Array:
	var tiles_with_distance = []
	for tile in room:
		if tile.x == room_position.x or tile.y == room_position.y or tile.z == room_position.z:
			var distance = tile.distance_to(room_position)
			tiles_with_distance.append({"tile": tile, "distance": distance})
	
	tiles_with_distance.sort_custom(func(a, b):
		return a["distance"] < b["distance"]
	)
	
	var selected_tiles = []
	if tiles_with_distance.size() >= 2:
		var first_door = tiles_with_distance[0]["tile"]
		var second_door = tiles_with_distance[1]["tile"]
		var delta = second_door - first_door
		selected_tiles.append(first_door)
		selected_tiles.append(second_door)
		
		if print_info:
			print("Initial Door Tiles: (%s->%s)" % [first_door * 2, second_door * 2], \
				  " : Direction:", format_dir_vector(delta.normalized()))
		for i in range(min(width, tiles_with_distance.size())):
			var tile = tiles_with_distance[i]["tile"]
			var offset = tile - first_door
			#print("Initial Door Tiles: (%s->%s)" % [tile * 2, first_door * 2], \
			  #" : Direction:", format_dir_vector(offset.normalized()))
			if offset.normalized() == delta.normalized(): # Force all tiles align with same direction
				selected_tiles.append(tiles_with_distance[i]["tile"])
			selected_tiles.append(tiles_with_distance[i]["tile"])
	return selected_tiles

func manhattan_distance(v1: Vector3, v2: Vector3) -> int:
	return abs(v1.x - v2.x) + abs(v1.z - v2.z)

func get_room_dimensions(room: PackedVector3Array) -> Vector2:
	var min_x = INF
	var max_x = -INF
	var min_z = INF
	var max_z = -INF

	for tile in room:
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_z = min(min_z, tile.z)
		max_z = max(max_z, tile.z)

	var width = max_x - min_x + 1
	var height = max_z - min_z + 1

	return Vector2(width, height)

func format_dir_vector(vec: Vector3) -> String:
	match vec:
		Vector3(1, 0, 0): return "x+"
		Vector3(-1, 0, 0): return "x-"
		Vector3(0, 1, 0): return "y+"
		Vector3(0, -1, 0): return "y-"
		Vector3(0, 0, 1): return "z+"
		Vector3(0, 0, -1): return "z-"
		_: return str(vec) + "?"

func get_mesh_from_index(index: int) -> Mesh:
	var mesh_library = tile_layout_grid_map.mesh_library
	if mesh_library.has_item(index):
		return mesh_library.get_item_mesh(index)
	else:
		print("Index not found in MeshLibrary")
		return null

func place_border_around_tiles(rooms: Array, hallways: Array, wall_item_id: int):
	var all_tiles = []  # Store all room and hallway tiles
	if print_info:
		print("Rooms Count: ", rooms.size())
		print("Hallway Count: ", hallways.size())
		print("Total tiles: ", tile_layout_grid_map.get_used_cells().size())
	all_tiles += rooms
	all_tiles += hallways
	
	for tiles in all_tiles:
		for tile in tiles:
			var x = tile.x
			var z = tile.z
			# Check all 8 surrounding tiles (left, right, up, down, and diagonals)
			for dx in range(-1, 2):
				for dz in range(-1, 2):
					if dx == 0 and dz == 0:
						continue
					
					var neighbor_pos = Vector3i(x + dx, 0, z + dz)
					
					if tile_layout_grid_map.get_cell_item(neighbor_pos) < 0:  # Check if it's an empty space
						tile_layout_grid_map.set_cell_item(neighbor_pos, wall_item_id)

func spawn_custom_rooms(rec: int):
	if rec<0: return
	var room_ranges = custom_rooms_grid_map.get_room_ranges()
	if room_ranges.is_empty(): 
		printerr(self,": No Room Spaces Stored, refresh CustomRooms")
		return
	var random_room_idx = randi() % room_ranges.size()
	var tiles = custom_rooms_grid_map.get_room_space_tiles(random_room_idx,false)
	var rotated_tiles = custom_rooms_grid_map.rotated_room_space_tiles(tiles,randi_range(0,4))
	
	if rotated_tiles and !rotated_tiles.is_empty(): 
		var size = get_tile_area_size(rotated_tiles)
		var width : int = size.x
		var height : int = size.y
		var start_pos : Vector3i
		#print("Custom Room ",random_room_idx,": Size: ",size)
		
		if enable_room_alignment and room_tiles and !room_tiles.is_empty():
			var last_checked_room = room_tiles.back()
			var room_bounds = get_tile_are_bounds(last_checked_room)
			var room_grid_pos = get_next_room_grid(last_checked_room,size)
			start_pos.x = room_grid_pos.x
			start_pos.z = room_grid_pos.z
		else:
			start_pos.x = randi() % (border_size - width + 1)
			start_pos.z = randi() % (border_size - width + 1)
		
		#$Marker3D.position = Vector3(start_pos.x*2,0,start_pos.z*2)
		for r in range(-room_margin,height+room_margin): # Check if space is occupied
			for c in range(-room_margin,width+room_margin):
				var new_pos : Vector3i = start_pos + Vector3i(c,0,r)
				if tile_layout_grid_map.get_cell_item(new_pos) == 0: # 0 if occupied/-1 if empty
					spawn_custom_rooms(rec-1)
					return
		
		var room : PackedVector3Array = []
		for i in rotated_tiles.size(): # Spawn Rooms
			var final_pos = start_pos + Vector3i(rotated_tiles[i])
			tile_layout_grid_map.set_cell_item(final_pos, 0)
			room.append(final_pos)
		room_tiles.append(room)
		
		var center : Vector3 = custom_rooms_grid_map.get_center(rotated_tiles)
		var avg_x : float = start_pos.x + center.x
		var avg_z : float = start_pos.z + center.z
		var pos : Vector3 = Vector3(avg_x,0,avg_z)
		room_positions.append(pos)
		$Marker3D.position = pos * 2


func get_next_room_grid(last_pos,room_size):
	var next_dir = randi_range(0,1)
	var new_pos : Vector3i
	new_pos.x = randi() % (border_size - int(room_size.x) + 1)
	new_pos.z = randi() % (border_size - int(room_size.x) + 1)
	match next_dir:
		0:
			new_pos.x = last_pos[0].x
		1:
			new_pos.z = last_pos[0].z
	return new_pos


func make_room(rec : int):
	if rec<0: return
	@warning_ignore("integer_division")
	var width : int = max((randi() % (max_room_size - min_room_size) + min_room_size) / 4 * 4, 4)
	var height : int = max(randi() % (max_room_size - min_room_size) + min_room_size, 4)
	
	var start_pos : Vector3i
	#start_pos.x = randi() % (border_size - width + 1) - (border_size / 2) # If centered
	#start_pos.z = randi() % (border_size - width + 1) - (border_size / 2)
	start_pos.x = randi() % (border_size - width + 1)
	start_pos.z = randi() % (border_size - width + 1)
	
	for r in range(-room_margin,height+room_margin):
		for c in range(-room_margin,width+room_margin):
			var new_pos : Vector3i = start_pos + Vector3i(c,0,r)
			if tile_layout_grid_map.get_cell_item(new_pos) == 0: # 0 if occupied/-1 if empty
				make_room(rec-1)
				return
	
	var room : PackedVector3Array = []
	for r in height:
		for c in width:
			var other_pos : Vector3i = start_pos + Vector3i(c,0,r)
			tile_layout_grid_map.set_cell_item(other_pos,0)
			room.append(other_pos)
	room_tiles.append(room)
	
	var avg_x : float = start_pos.x + (float(width)/2)
	var avg_z : float = start_pos.z + (float(height)/2)
	var pos : Vector3 = Vector3(avg_x,0,avg_z)
	room_positions.append(pos)

func get_random_room_orientation(tile_positions: Array, center: Vector3, rotation_steps: int):
	var rotated_positions: Array[Vector3i] = []
	var angle_rad := deg_to_rad(rotation_steps * 90)
	for pos in tile_positions:
		var world_pos := Vector3(pos)
		var relative := world_pos - center
		var rotated_relative := relative.rotated(Vector3.UP, angle_rad)
		var final_pos := rotated_relative + center
		rotated_positions.append(Vector3i(round(final_pos.x), 0, round(final_pos.z)))
	return rotated_positions


func get_tile_area_size(tile_positions: Array) -> Vector2:
	if tile_positions.is_empty():
		return Vector2(0, 0)
	var min_x = tile_positions[0].x
	var max_x = tile_positions[0].x
	var min_z = tile_positions[0].z
	var max_z = tile_positions[0].z
	for tile in tile_positions:
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_z = min(min_z, tile.z)
		max_z = max(max_z, tile.z)
	var width = int(max_x - min_x) + 1
	var height = int(max_z - min_z) + 1
	return Vector2(width, height)

func get_tile_are_bounds(tile_positions: Array) -> Array:
	if tile_positions.is_empty():
		return []
	var min_x = tile_positions[0].x
	var max_x = tile_positions[0].x
	var min_z = tile_positions[0].z
	var max_z = tile_positions[0].z
	for tile in tile_positions:
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_z = min(min_z, tile.z)
		max_z = max(max_z, tile.z)
	return [min_x,max_x,min_z,max_z]
