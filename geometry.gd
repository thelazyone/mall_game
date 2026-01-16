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

# Called when the node enters the scene tree
func _ready() -> void:
	print("Geometry node ready!")
	
	# Define a test path - replace this with your actual path!
	# This creates a square path for testing
	var mall_size = 3
	define_path([
		Vector2(-mall_size, -mall_size),
		Vector2(mall_size, -mall_size),
		Vector2(mall_size, mall_size),
		Vector2(-mall_size, mall_size)
	])

# Define the path from a series of xy nodes
func define_path(nodes: Array) -> void:
	if nodes.size() < 2:
		push_error("Path needs at least 2 nodes")
		return
	
	path_nodes = nodes.duplicate()
	segment_lengths.clear()
	total_path_length = 0.0
	
	# Calculate segment lengths
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

# Get the 2D position from a PathPosition object
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
			var segment_progress = (current_distance - accumulated_length) / segment_length
			var start_node = path_nodes[i]
			var end_node = path_nodes[(i + 1) % path_nodes.size()]
			
			# Linear interpolation between nodes
			return start_node.lerp(end_node, segment_progress)
		
		accumulated_length += segment_length
	
	# Should never reach here, but return last node as fallback
	return path_nodes[-1]

# Get the facing direction (normalized vector) at a PathPosition
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
			var start_node = path_nodes[i]
			var end_node = path_nodes[(i + 1) % path_nodes.size()]
			
			# Direction is from start to end of segment
			return (end_node - start_node).normalized()
		
		accumulated_length += segment_length
	
	# Fallback: return direction of last segment
	var last_idx = path_nodes.size() - 1
	return (path_nodes[0] - path_nodes[last_idx]).normalized()

# Get the total length of the path
func get_total_length() -> float:
	return total_path_length
