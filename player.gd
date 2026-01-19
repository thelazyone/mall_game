extends Node3D

# Reference to the geometry node
# Option 1: Use unique name (requires Geometry node to be marked with % in scene tree)
# @onready var geometry = %Geometry
# Option 2: Use get_node with path from root
# @onready var geometry = get_node("/root/Geometry")
# Option 3: Find it at runtime (most flexible)
var geometry

# Player's position along the path
var path_position

# Movement speed (units per second along the path)
@export var movement_speed: float = 12.0

# Rotation offsets
@export var rotation_offset: float = 0.0

# Jump physics parameters
@export var jump_impulse: float = 6.0  # Initial upward velocity when jumping
@export var jump_charge_max_time: float = 2.0  # Maximum time the jump button can be held
@export var jump_charge_multiplier: float = 2.0

@export var gravity: float = 30.0  # Downward acceleration
@export var ground_level: float = 0.0  # Y position of the ground

# Jump state
var vertical_velocity: float = 0.0
var is_on_ground: bool = true
var jump_press_time: float = 0.0  # Timestamp when jump button was pressed
var is_charging_jump: bool = false

# Facing direction: 1 for forward along path, -1 for backward
var facing_direction: float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Player ready!")
	
	# Try to find the Geometry node in different ways
	if not geometry:
		# Try searching in parent's children first
		if get_parent():
			geometry = get_parent().find_child("Geometry", true, false)
		
		# Try unique name if that didn't work
		if not geometry and has_node("%Geometry"):
			geometry = get_node("%Geometry")
		
		if geometry:
			print("Found Geometry node")
		else:
			print("WARNING: Could not find Geometry node in _ready()")

# Initialize the player's position - called by mall.gd after geometry is ready
func initialize_position() -> void:
	if not geometry:
		push_error("Cannot initialize position: geometry not found")
		return
	
	if not geometry.is_path_defined:
		push_error("Cannot initialize position: path not defined")
		return
	
	path_position = geometry.create_position(0.0)
	
	# Initialize facing direction
	facing_direction = 1.0
	
	update_player_transform()
	
	# Initialize vertical position and jump state
	position.y = ground_level
	vertical_velocity = 0.0
	is_on_ground = true
	is_charging_jump = false
	
	print("Player position initialized at distance: ", path_position.distance)
	print("Player world position: ", position)


func _process(delta: float) -> void:
	# Handle horizontal movement along the path
	var movement_input = 0.0	
	
	# Checking if the move_left and move_right buttons are pressed right now.
	if Input.is_action_pressed("move_left"):
		movement_input -= 1.0
	if Input.is_action_pressed("move_right"):
		movement_input += 1.0

	if movement_input != 0.0:
		# Update facing direction based on movement
		if movement_input > 0:
			facing_direction = 1.0  # Moving forward along path (left)
		else:
			facing_direction = -1.0  # Moving backward along path (right)
		
		var distance_delta = movement_input * movement_speed * delta
		geometry.translate(path_position, distance_delta)
		update_player_transform()
	
	# Handle jump charging
	if is_on_ground:
		if Input.is_action_just_pressed("jump"):
			# Start charging the jump - record the timestamp
			is_charging_jump = true
			jump_press_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds
		
		if is_charging_jump and Input.is_action_just_released("jump"):
			# Calculate the charge time
			var jump_release_time = Time.get_ticks_msec() / 1000.0
			var charge_time = jump_release_time - jump_press_time
			
			# Calculate jump impulse based on charge time
			# impulse = base_impulse * (1 + min(time/max_time, 1) * multiplier)
			var charge_ratio = min(charge_time / jump_charge_max_time, 1.0)	
			var calculated_impulse = jump_impulse * (1.0 + charge_ratio * (jump_charge_multiplier - 1))
			
			print("Jump charged for ", charge_time, "s, impulse: ", calculated_impulse)
			
			vertical_velocity = calculated_impulse
			is_on_ground = false
			is_charging_jump = false
	
	# Apply gravity and update vertical position
	if not is_on_ground:
		vertical_velocity -= gravity * delta
		position.y += vertical_velocity * delta
		
		# Check if we've landed
		if position.y <= ground_level:
			position.y = ground_level
			vertical_velocity = 0.0
			is_on_ground = true
			is_charging_jump = false


# Update the player's 3D position and rotation based on path position
func update_player_transform() -> void:
	# Get 2D position from geometry
	var pos_2d = geometry.get_position(path_position)
	var facing_2d = geometry.get_facing(path_position)
	
	# Update 3D position in XZ plane (preserve Y for jump physics)
	position.x = pos_2d.x
	position.z = pos_2d.y  # Map 2D y to 3D z
	# Note: position.y is NOT updated here - it's controlled by jump physics
	
	# Update rotation to face the tangent direction of the path
	if facing_2d.length() > 0:
		# Calculate angle from the path tangent direction
		# atan2(x, z) gives us the Y rotation in 3D space
		var angle = atan2(facing_2d.x, facing_2d.y)
		
		# Apply facing direction (flip 180° if moving backward)
		if facing_direction < 0:
			angle += PI
		
		rotation.y = angle + rotation_offset
