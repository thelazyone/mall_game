extends Node

# Position class to represent a point along the path
class PathPosition:
	var distance: float = 0.0  # Distance along the path (1D position)
	
	func _init(dist: float = 0.0):
		distance = dist

# Path data structure
var path_nodes: Array = []  # Array of Vector2 positions
var segment_lengths: Array = []  # Length of each segment
var total_path_length: float = 0.0
var is_path_defined: bool = false

# Visual smoothing parameter
@export var curve_radius: float = 0.5  # Radius for visual corner smomoothing

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

# Create a new position object at a specific distance
func create_position(distance: float = 0.0) -> PathPosition:
	var pos = PathPosition.new(distance)
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

# Get the 2D position from a PathPosition object (with visual smoothing)
func get_position(position: PathPosition) -> Vector2:
	if not is_path_defined:
		push_error("Path not defined")
		return Vector2.ZERO
	
	var current_distance = position.distance
	var accumulated_length = 0.0
	
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
			return start_node.lerp(end_node, segment_progress)
		
		accumulated_length += segment_length
	
	# Should never reach here, but return last node as fallback
	return path_nodes[-1]

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
