extends MultiplayerSynchronizer

@onready var player = $".."
@onready var pause_menu = %PauseMenu

var input_dir
var input_jump
var input_push = false
var input_run = false

var is_paused = false

func _ready():
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	
	input_dir = Input.get_vector("left", "right", "up", "down")

func _physics_process(_delta):
	input_dir = Input.get_vector("left", "right", "up", "down")
	input_run = Input.is_action_pressed("run")
	input_jump = Input.get_action_strength("jump")
	input_push = Input.get_action_strength("push")
	if Input.is_action_just_pressed("pause"):
		toggle_pause()

func leave_game():
	multiplayer.multiplayer_peer.close()
	queue_free()
	GameManager.LeaveGame()

func toggle_pause():
	is_paused = !is_paused
	
	if is_paused:
		# Show pause menu
		pause_menu.visible = true
		# Optional: pause game for this player only
		# get_tree().paused = true
	else:
		pause_menu.visible = false
		# get_tree().paused = false
	
	print("Pause toggled: " + str(is_paused))
