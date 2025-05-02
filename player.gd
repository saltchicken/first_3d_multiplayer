extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 5.0

const PUSH_FORCE = 10.0
const PUSH_RADIUS = 2.0
var push_cooldown = 0.0

var last_direction = "down"

# var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var _is_on_floor = true
var alive = true

@onready var animated_sprite = $"AnimatedSprite3D"
@onready var player_name_label = %PlayerNameLabel

func _enter_tree():
	%InputSynchronizer.set_multiplayer_authority(name.to_int())

func _ready():
	add_to_group("players")
	GameManager.game_state_changed.connect(_on_game_state_changed)
	# if multiplayer.get_unique_id() == player_id:
	#	$Camera2D.make_current()
	# else:
	#	$Camera2D.enabled = false
	#
func _on_game_state_changed(key, _value):
	print("Game state changed")
	if key == "players":
		if GameManager.game_state.players.has(name):
			player_name_label.text = GameManager.game_state.players[name].name
		else:
			player_name_label.text = "Player " + name

var push_animation_timer = 0.0

func _apply_animations(_delta):
	var input_dir = %InputSynchronizer.input_dir
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if push_animation_timer > 0:
		push_animation_timer -= _delta
		animated_sprite.play("push_" + last_direction)
		return

	# TODO: Fix the snchronization of applying push on server and animation on client
	if %InputSynchronizer.input_push:
		push_animation_timer = 0.25
		animated_sprite.play("push_" + last_direction)
		return

	if direction.length() > 0.1:
		# Player is moving - update last_direction only if needed
		if abs(direction.x) > 0.1:
			# Horizontal movement detected
			last_direction = "right" if direction.x > 0 else "left"
		elif abs(direction.z) > 0.1:
			# Vertical movement detected
			last_direction = "down" if direction.z > 0 else "up"
		
		# Play the walk animation for the current direction
		animated_sprite.play("walk_" + last_direction)
	else:
		# Player is idle - play appropriate idle animation
		animated_sprite.play("idle_" + last_direction)

func _apply_movement_from_input(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if %InputSynchronizer.input_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY

	if %InputSynchronizer.input_push and push_cooldown <= 0:
		print("push")
		perform_push_attack()
		push_cooldown = 0.25

	if push_cooldown > 0:
		push_cooldown -= delta

	# Apply movement
	var input_dir = %InputSynchronizer.input_dir
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply friction first to prevent excessive speed buildup
	var friction = 0.05
	velocity.x *= (1.0 - friction)
	velocity.z *= (1.0 - friction)
	
	# Add to velocity instead of setting it directly
	if direction:
		velocity.x += direction.x * SPEED * delta * 10.0
		velocity.z += direction.z * SPEED * delta * 10.0
	
	# Cap maximum horizontal speed
	var max_speed = SPEED * 1.2
	var horizontal_velocity = Vector2(velocity.x, velocity.z)
	if horizontal_velocity.length() > max_speed:
		horizontal_velocity = horizontal_velocity.normalized() * max_speed
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.y

	move_and_slide()

func perform_push_attack():
	if not multiplayer.is_server():
		return
	
	# Get player's forward direction based on input direction instead of transform
	var input_dir = %InputSynchronizer.input_dir
	var forward_direction
	
	if input_dir.length() > 0.1:
		# Use input direction if player is moving
		forward_direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		# Use character's facing direction if not moving
		forward_direction = -transform.basis.z.normalized()
	
	# Find all players in radius
	var players = get_tree().get_nodes_in_group("players")
	print("Push attack: found " + str(players.size()) + " players")
	
	for other_player in players:
		if other_player == self:
			continue
		
		# Calculate vector to other player (ignoring Y for better horizontal detection)
		var to_other = other_player.global_position - global_position
		var to_other_flat = Vector3(to_other.x, 0, to_other.z)
		var distance = to_other_flat.length()
		
		# Check if player is within push radius
		if distance < PUSH_RADIUS:
			# Normalize the direction vector (for the flat version)
			var push_dir_flat = to_other_flat.normalized()
			
			# Check if player is roughly in front using flat vectors (ignoring Y)
			var angle = forward_direction.dot(push_dir_flat)
			print("Player " + other_player.name + " at angle: " + str(angle))
			
			print("Pushing player: " + other_player.name)
			
			# Calculate push direction (away from pusher, preserving Y difference)
			var push_dir = to_other.normalized()
			var final_push_dir = push_dir * PUSH_FORCE * 50.0
			
			# Add upward component
			final_push_dir.y = 0
			
			# Apply push directly on server
			other_player.velocity += final_push_dir
			# Also send RPC to ensure client sees the push
			apply_push.rpc_id(int(other_player.name), final_push_dir)

@rpc("authority")
func apply_push(push_vector):
	# Direct application of push force
	print("Push received: " + str(push_vector))
	velocity += push_vector
	# Ensure the push is visible by adding extra upward force
	# velocity.y += 0.2


func _physics_process(delta):
	if multiplayer.is_server():
		_is_on_floor = is_on_floor()
		_apply_movement_from_input(delta)

	if not multiplayer.is_server():
		_apply_animations(delta)
