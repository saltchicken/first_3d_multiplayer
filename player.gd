extends CharacterBody3D


const SPEED = 2.5
const RUN_SPEED_MULTIPLIER = 1.8
const JUMP_VELOCITY = 2.5

const PUSH_FORCE = 200.0
const PUSH_RADIUS = 2.0
var push_cooldown = 0.0
var push_animation_timer = 0.0
const PUSH_COOLDOWN_DURATION = 0.1

#TODO: Should not need animation timer and cooldown. Animation timer is working on client. Cooldown is working on server with physics

const JUMP_ANIMATION_DURATION = 0.5
var jump_animation_timer = 0.0
const JUMP_COOLDOWN = 0.7
var jump_cooldown_timer = 0.0

const FRICTION = 0.1

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
	PingManager.ping_updated.connect(_on_ping_updated)

	if multiplayer.is_server():
		# Find all lava areas in the scene
		var lava_areas = get_tree().get_nodes_in_group("lava")
		for lava in lava_areas:
			lava.body_entered.connect(_on_lava_entered)

func _on_lava_entered(body):
	if not multiplayer.is_server():
		return
	print("Lava entered")
	if body == self:
		alive = false
		player_died.rpc()
		await get_tree().create_timer(3.0).timeout
		global_position = Vector3(0, 3, 0)	# Respawn position
		alive = true
		player_respawned.rpc()

@rpc("authority")
func player_died():
	alive = false
	animated_sprite.play("death")

	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color(0, 0, 0, 1), 2.0)

	if multiplayer.get_unique_id() == name.to_int():
		%InputSynchronizer.set_process(false)
		%InputSynchronizer.set_physics_process(false)

@rpc("authority")
func player_respawned():
	alive = true
	animated_sprite.modulate = Color(1, 1, 1, 1)
	animated_sprite.play("idle_down")
	if multiplayer.get_unique_id() == name.to_int():
		%InputSynchronizer.set_process(true)
		%InputSynchronizer.set_physics_process(true)

func _on_ping_updated(ping_value):
	if multiplayer.get_unique_id() == name.to_int():
		# Only update ping for the local player
		%PingLabel.text = "Ping: " + str(ping_value) + "ms"
	#
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


func _apply_animations(_delta):
	if alive == false:
		return
	
	var input_dir = %InputSynchronizer.input_dir
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Update timers
	if push_animation_timer > 0:
		push_animation_timer -= _delta
	if jump_animation_timer > 0:
		jump_animation_timer -= _delta
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= _delta
	
	# Handle push animation
	if push_animation_timer > 0:
		animated_sprite.play("push_" + last_direction)
		return

	# Handle push input
	if %InputSynchronizer.input_push and push_animation_timer <= 0:
		push_animation_timer = PUSH_COOLDOWN_DURATION
		animated_sprite.play("push_" + last_direction)
		return
	
	# Handle jump animation with cooldown
	if jump_animation_timer > 0:
		animated_sprite.play("jump_" + last_direction)
		return
	
	# Start jump animation when button is pressed and cooldown is over
	if %InputSynchronizer.input_jump and jump_cooldown_timer <= 0:
		jump_animation_timer = JUMP_ANIMATION_DURATION
		jump_cooldown_timer = JUMP_COOLDOWN
		animated_sprite.play("jump_" + last_direction)
		return
	
	# Handle ground movement animations
	if direction.length() > 0.1:
		# Update last_direction based on movement
		if abs(direction.x) > 0.1:
			last_direction = "right" if direction.x > 0 else "left"
		elif abs(direction.z) > 0.1:
			last_direction = "down" if direction.z > 0 else "up"
		
		# Handle running vs walking
		if %InputSynchronizer.input_run:
			animated_sprite.play("run_" + last_direction)  # Using run animation if available
			# Or use walk animation with increased speed if run animations don't exist
			# animated_sprite.play("walk_" + last_direction)
			# animated_sprite.speed_scale = 1.5
		else:
			animated_sprite.play("walk_" + last_direction)
			animated_sprite.speed_scale = 1.0
	else:
		# Player is idle
		animated_sprite.play("idle_" + last_direction)
		animated_sprite.speed_scale = 1.0

func _apply_movement_from_input(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump with cooldown
	if %InputSynchronizer.input_jump and is_on_floor() and jump_cooldown_timer <= 0:
		velocity.y = JUMP_VELOCITY
		jump_animation_timer = JUMP_ANIMATION_DURATION
		jump_cooldown_timer = JUMP_COOLDOWN
	
	# Update jump cooldown timer
	if jump_cooldown_timer > 0:
		jump_cooldown_timer -= delta

	# Handle push with cooldown
	if %InputSynchronizer.input_push and push_cooldown <= 0:
		print("push")
		perform_push_attack()
		push_cooldown = PUSH_COOLDOWN_DURATION
		push_animation_timer = PUSH_COOLDOWN_DURATION

	if push_cooldown > 0:
		push_cooldown -= delta

	# Apply movement
	var input_dir = %InputSynchronizer.input_dir
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Apply friction first to prevent excessive speed buildup
	var friction = FRICTION
	velocity.x *= (1.0 - friction)
	velocity.z *= (1.0 - friction)

	# Determine speed based on run input
	var current_speed = SPEED
	if %InputSynchronizer.input_run:
		current_speed *= RUN_SPEED_MULTIPLIER
	
	# Add to velocity instead of setting it directly
	if direction:
		velocity.x += direction.x * current_speed * delta * 10.0
		velocity.z += direction.z * current_speed * delta * 10.0
	
	# Cap maximum horizontal speed
	var max_speed = current_speed * 1.2
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
			var final_push_dir = push_dir * PUSH_FORCE
			
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
		if alive:
			_apply_movement_from_input(delta)

	if not multiplayer.is_server():
		_apply_animations(delta)
