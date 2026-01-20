extends Node

# Stair data structure
class StairData:
	var segment_index: int  # Which segment (0 to num_segments-1)
	var position_on_segment: float  # Position along segment
	var arrival_segment: int  # Arrival segment index
	var arrival_position: float  # Arrival position on segment
	var arrival_floor: int  # Which floor it connects to
	var going_up: bool  # True if going up, False if going down
	
	func _init(seg: int, pos: float, arr_seg: int, arr_pos: float, arr_floor: int, up: bool):
		segment_index = seg
		position_on_segment = pos
		arrival_segment = arr_seg
		arrival_position = arr_pos
		arrival_floor = arr_floor
		going_up = up

# Position class to represent a point along the path
class PathPosition:
	var distance: float = 0.0  # Distance along the path (1D position)
	var floor: int = 0  # Which floor (0-4, with 2 being the starting floor)
	var on_stairs: bool = false  # Whether currently on stairs
	var stair_progress: float = 0.0  # Progress on stairs (0.0 to 1.0)
	var stair_arrival_floor: int = 0  # Which floor the current stair goes to
	var stair_going_up: bool = true  # Direction of current stair
	
	func _init(dist: float = 0.0, flr: int = 2):
		distance = dist
		floor = flr
		stair_arrival_floor = flr

# Path data structure
var path_nodes: Array = []  # Array of Vector2 positions
var segment_lengths: Array = []  # Length of each segment
var total_path_length: float = 0.0
var is_path_defined: bool = false

# Floor data (array of arrays of StairData)
var floors: Array = []  # floors[floor_idx] = [StairData, StairData, ...]
var num_floors: int = 5
var floor_height: float = 4.0

# Stair interaction parameters
@export var stair_entrance_tolerance: float = 1.2  # How close you need to be to enter stairs
@export var debug_stair_switching: bool = true  # Enable debug prints for stair switching

# Visual smoothing parameter
@export var curve_radius: float = 0.5  # Radius for visual corner smoothing

# Called when the node enters the scene tree
func _ready() -> void:
	print("Geometry node ready!")
	# Path will be defined dynamically by mall.gd during procedural generation

# Define the path from a series of xy nodes
func define_path(nodes: Array) -> void:
	if nodes.size() < 2:
		push_error("Path needs at least 2 nodes")
		return
	
	path_nodes = nodes.duplicate()
	segment_lengths.clear()
	total_path_length = 0.0
	
	# Calculate segment lengths (simple linear segments)
	for i in range(nodes.size()):
		var current_node = nodes[i]
		var next_node = nodes[(i + 1) % nodes.size()]  # Wraps back to first node
		var segment_length = current_node.distance_to(next_node)
		segment_lengths.append(segment_length)
		total_path_length += segment_length
	
	is_path_defined = true
	print("Path defined with %d nodes, total length: %.2f" % [nodes.size(), total_path_length])

# Define floors and their stair connections
func define_floors(floor_count: int, stair_data: Array) -> void:
	"""
	Define floor structure with stairs
	stair_data is array of dictionaries with: floor, segment_index, position_on_segment, 
	arrival_segment, arrival_position, arrival_floor, going_up
	"""
	num_floors = floor_count
	floors.clear()
	
	# Initialize empty floors
	for i in range(num_floors):
		floors.append([])
	
	# Add stairs to floors
	for stair_dict in stair_data:
		var stair = StairData.new(
			stair_dict["segment_index"],
			stair_dict["position_on_segment"],
			stair_dict["arrival_segment"],
			stair_dict["arrival_position"],
			stair_dict["arrival_floor"],
			stair_dict["going_up"]
		)
		floors[stair_dict["floor"]].append(stair)
	
	print("Floors defined: %d floors with %d total stair connections" % [num_floors, stair_data.size()])

# Create a new position object at a specific distance and floor
func create_position(distance: float = 0.0, floor_idx: int = 2) -> PathPosition:
	var pos = PathPosition.new(distance, floor_idx)
	if is_path_defined:
		pos.distance = fmod(distance, total_path_length)
		if pos.distance < 0:
			pos.distance += total_path_length
	return pos

# Translate a position along the path by a given distance
func translate(position: PathPosition, delta_distance: float) -> PathPosition:
	if not is_path_defined:
		push_error("Path not defined")
		return position
	
	position.distance += delta_distance
	
	# Handle wrapping (periodic path)
	position.distance = fmod(position.distance, total_path_length)
	if position.distance < 0:
		position.distance += total_path_length
	
	return position

# Get the 3D position from a PathPosition object (with visual smoothing and floor height)
func get_position(position: PathPosition) -> Vector3:
	if not is_path_defined:
		push_error("Path not defined")
		return Vector3.ZERO
	
	var current_distance = position.distance
	var accumulated_length = 0.0
	
	# Get 2D position
	var pos_2d = Vector2.ZERO
	
	# Find which segment the position is on
	for i in range(segment_lengths.size()):
		var segment_length = segment_lengths[i]
		
		if current_distance <= accumulated_length + segment_length:
			# Position is on this segment
			var local_distance = current_distance - accumulated_length
			var segment_progress = local_distance / segment_length
			
			var start_node = path_nodes[i]
			var end_node = path_nodes[(i + 1) % path_nodes.size()]
			
			# Simple linear interpolation - no visual curve for position
			# (curves only affect rotation for smoothness)
			pos_2d = start_node.lerp(end_node, segment_progress)
			break
		
		accumulated_length += segment_length
	
	if pos_2d == Vector2.ZERO:
		pos_2d = path_nodes[-1]
	
	# Calculate Y position (floor height)
	var y_pos: float
	if position.on_stairs:
		# Lerp between departure and arrival floor based on stair progress
		var departure_floor = position.floor if position.stair_going_up else position.stair_arrival_floor
		var arrival_floor = position.stair_arrival_floor if position.stair_going_up else position.floor
		var departure_y = (departure_floor - 2) * floor_height
		var arrival_y = (arrival_floor - 2) * floor_height
		y_pos = lerp(departure_y, arrival_y, position.stair_progress)
	else:
		# Normal floor height (floor 2 is at y=0)
		y_pos = (position.floor - 2) * floor_height
	
	return Vector3(pos_2d.x, y_pos, pos_2d.y)

# Get the facing direction (normalized vector) at a PathPosition (with visual smoothing)
func get_facing(position: PathPosition) -> Vector2:
	if not is_path_defined:
		push_error("Path not defined")
		return Vector2.RIGHT
	
	var current_distance = position.distance
	var accumulated_length = 0.0
	
	# Find which segment the position is on
	for i in range(segment_lengths.size()):
		var segment_length = segment_lengths[i]
		
		if current_distance <= accumulated_length + segment_length:
			# Position is on this segment
			var local_distance = current_distance - accumulated_length
			
			var prev_node = path_nodes[(i - 1 + path_nodes.size()) % path_nodes.size()]
			var start_node = path_nodes[i]
			var end_node = path_nodes[(i + 1) % path_nodes.size()]
			var next_node = path_nodes[(i + 2) % path_nodes.size()]
			
			# Get segment directions
			var dir_in = (start_node - prev_node).normalized()
			var dir_current = (end_node - start_node).normalized()
			var dir_out = (next_node - end_node).normalized()
			
			# Curve distance is simply curve_radius, clamped to half the segment length
			var curve_dist = min(curve_radius, segment_length / 2.0)
			
			# Calculate the middle angle at the start corner (between dir_in and dir_current)
			var angle_in = dir_in.angle()
			var angle_current = dir_current.angle()
			var angle_diff_start = angle_current - angle_in
			while angle_diff_start > PI:
				angle_diff_start -= TAU
			while angle_diff_start < -PI:
				angle_diff_start += TAU
			var mid_angle_start = angle_in + angle_diff_start * 0.5
			
			# Calculate the middle angle at the end corner (between dir_current and dir_out)
			var angle_out = dir_out.angle()
			var angle_diff_end = angle_out - angle_current
			while angle_diff_end > PI:
				angle_diff_end -= TAU
			while angle_diff_end < -PI:
				angle_diff_end += TAU
			var mid_angle_end = angle_current + angle_diff_end * 0.5
			
			# Check if we're in the start corner curve zone
			if local_distance < curve_dist:
				# Lerp from middle of previous corner to middle of this corner
				# t=0 at corner (mid_angle_start), t=1 at end of curve zone (dir_current)
				var t = local_distance / curve_dist
				var current_angle = lerp_angle(mid_angle_start, angle_current, t)
				return Vector2(cos(current_angle), sin(current_angle))
			
			# Check if we're in the end corner curve zone
			elif local_distance > segment_length - curve_dist:
				# Lerp from current segment direction to middle of next corner
				# t=0 at start of curve zone (dir_current), t=1 at corner (mid_angle_end)
				var t = (local_distance - (segment_length - curve_dist)) / curve_dist
				var current_angle = lerp_angle(angle_current, mid_angle_end, t)
				return Vector2(cos(current_angle), sin(current_angle))
			
			else:
				# In the straight section - just use current segment direction
				return dir_current
		
		accumulated_length += segment_length
	
	# Fallback: return direction of last segment
	var last_idx = path_nodes.size() - 1
	return (path_nodes[0] - path_nodes[last_idx]).normalized()

# Get the total length of the path
func get_total_length() -> float:
	return total_path_length

# Try to enter stairs mode (S key)
func try_stairs(position: PathPosition) -> bool:
	"""Check if player is at a stair entrance and switch to stair mode"""
	if debug_stair_switching:
		print("[try_stairs] Called - Current floor: ", position.floor, " | On stairs: ", position.on_stairs)
	
	if position.on_stairs:
		if debug_stair_switching:
			print("[try_stairs] Already on stairs - cannot enter")
		return false  # Already on stairs
	
	if position.floor < 0 or position.floor >= floors.size():
		if debug_stair_switching:
			print("[try_stairs] Invalid floor: ", position.floor)
		return false  # Invalid floor
	
	# Check if we're near any stair entrance on this floor
	var current_segment = get_segment_at_distance(position.distance)
	var segment_local_pos = get_local_position_on_segment(position.distance)
	
	if debug_stair_switching:
		var side_name = ["Bottom", "Right", "Top", "Left"][current_segment] if current_segment < 4 else "Invalid"
		print("[try_stairs] Player distance: ", position.distance)
		print("[try_stairs] Current segment: ", current_segment, " (", side_name, ")")
		print("[try_stairs] Local pos on segment: ", segment_local_pos, " (distance from corner)")
		print("[try_stairs] Checking ", floors[position.floor].size(), " stairs on floor ", position.floor)
	
	for i in range(floors[position.floor].size()):
		var stair = floors[position.floor][i]
		
		if debug_stair_switching:
			var stair_side_name = ["Bottom", "Right", "Top", "Left"][stair.segment_index] if stair.segment_index < 4 else "Invalid"
			var direction = "UP" if stair.going_up else "DOWN"
			print("[try_stairs] Stair ", i, " - Direction: ", direction, " | Side: ", stair.segment_index, " (", stair_side_name, ")")
			print("[try_stairs]   Entrance pos on segment: ", stair.position_on_segment, " | To floor: ", stair.arrival_floor)
			print("[try_stairs]   Current segment: ", current_segment, " | Match: ", current_segment == stair.segment_index)
		
		# Check if we're on the same segment (side) as this stair
		if current_segment == stair.segment_index:
			var stair_entrance = stair.position_on_segment
			var distance_to_entrance = abs(segment_local_pos - stair_entrance)
			
			if debug_stair_switching:
				print("[try_stairs]   ✓ Same side! Checking distance...")
				print("[try_stairs]   Player pos: ", segment_local_pos, " | Stair pos: ", stair_entrance)
				print("[try_stairs]   Distance: ", distance_to_entrance, " | Tolerance: ", stair_entrance_tolerance)
			
			if distance_to_entrance < stair_entrance_tolerance:
				# Enter stairs!
				position.on_stairs = true
				position.stair_progress = 0.0
				position.stair_arrival_floor = stair.arrival_floor
				position.stair_going_up = stair.going_up
				if debug_stair_switching:
					var dir = "UP" if stair.going_up else "DOWN"
					print("[try_stairs]   ✓✓ ENTERED STAIRS (", dir, ") from floor ", position.floor, " to floor ", stair.arrival_floor)
				return true
			elif debug_stair_switching:
				print("[try_stairs]   ✗ Too far from entrance")
		elif debug_stair_switching:
			print("[try_stairs]   ✗ Different side")
	
	if debug_stair_switching:
		print("[try_stairs] No stair entrance found within tolerance")
	return false

# Note: try_floor() removed - stair exit is now automatic when progress reaches 1.0
# W key is reserved for future elevator functionality

# Helper: Get which segment index a distance is on
func get_segment_at_distance(distance: float) -> int:
	var accumulated = 0.0
	for i in range(segment_lengths.size()):
		if distance <= accumulated + segment_lengths[i]:
			return i
		accumulated += segment_lengths[i]
	return segment_lengths.size() - 1

# Helper: Get local position within current segment (from start of segment, excluding corner)
func get_local_position_on_segment(distance: float) -> float:
	var accumulated = 0.0
	for i in range(segment_lengths.size()):
		if distance <= accumulated + segment_lengths[i]:
			var local_dist = distance - accumulated
			# Subtract 4 for the corner at the start of each segment
			# This gives us distance from the start of the "segment area" (after corner)
			return max(0.0, local_dist - 4.0)
		accumulated += segment_lengths[i]
	return 0.0
