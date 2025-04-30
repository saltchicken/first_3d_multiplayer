extends MultiplayerSynchronizer

@onready var player = $".."
@onready var pause_menu = %PauseMenu

var input_dir 
var is_paused = false

# Called when the node enters the scene tree for the first time.
func _ready():
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	
	input_dir = Input.get_vector("left", "right", "up", "down")

func _physics_process(_delta):
	input_dir = Input.get_vector("left", "right", "up", "down")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	if Input.is_action_just_pressed("jump"):
		jump.rpc()
	if Input.is_action_just_pressed("pause"):
		# $"../".exit_game(name.to_int())
		print("Pause was pressed")
		toggle_pause()


func leave_game():
	multiplayer.multiplayer_peer.close()
	queue_free()


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

@rpc("call_local")
func jump():
	if multiplayer.is_server():
		player.do_jump = true
