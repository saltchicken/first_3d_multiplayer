extends CharacterBody3D


const SPEED = 5.0
const JUMP_VELOCITY = 5.0

# var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var _is_on_floor = true
var alive = true

func _enter_tree():
	%InputSynchronizer.set_multiplayer_authority(name.to_int())

# func _ready():
# 	if multiplayer.get_unique_id() == player_id:
# 		$Camera2D.make_current()
# 	else:
# 		$Camera2D.enabled = false
#
#
func _apply_animations(_delta):
	print("Apply animation")
	# # Flip the Sprite
	# if direction > 0:
	# 	animated_sprite.flip_h = false
	# elif direction < 0:
	# 	animated_sprite.flip_h = true
	#
	# # Play animations
	# if _is_on_floor:
	# 	if direction == 0:
	# 		animated_sprite.play("idle")
	# 	else:
	# 		animated_sprite.play("run")
	# else:
	# 	animated_sprite.play("jump")

func _apply_movement_from_input(delta):
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if %InputSynchronizer.input_jump and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Apply movement
	var input_dir = %InputSynchronizer.input_dir
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()



func _physics_process(delta):
	if multiplayer.is_server():
		_is_on_floor = is_on_floor()
		_apply_movement_from_input(delta)

	if not multiplayer.is_server():
		_apply_animations(delta)
	# Add the gravity.
		# Handle jump.
		# if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		# 	velocity.y = JUMP_VELOCITY
		#
		# if Input.is_action_just_pressed("ui_cancel"):
		# 	#$"../".exit_game(name.to_int())
		# 	get_tree().quit()

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		# var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
