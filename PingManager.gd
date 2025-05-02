
extends Node

var ping_start_time = 0
var current_ping = 0
signal ping_updated(ping_value)

var _ping_timer = null

func _ready():
	if OS.has_feature("dedicated_server"):
		return
	
	# Create ping timer but don't start it yet
	_ping_timer = Timer.new()
	_ping_timer.wait_time = 2.0  # Calculate ping every 2 seconds
	_ping_timer.timeout.connect(calculate_ping)
	add_child(_ping_timer)

func start_ping_measurement():
	if not OS.has_feature("dedicated_server") and _ping_timer != null:
		_ping_timer.start()

func stop_ping_measurement():
	if _ping_timer != null:
		_ping_timer.stop()

func calculate_ping():
	if not multiplayer.is_server() and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		ping_start_time = Time.get_ticks_msec()
		request_ping_response.rpc_id(1)  # Send to server (ID 1)

@rpc("any_peer")
func request_ping_response():
	if multiplayer.is_server():
		# Server immediately responds to the sender
		respond_to_ping.rpc_id(multiplayer.get_remote_sender_id())

@rpc("authority")
func respond_to_ping():
	# Client receives response and calculates round-trip time
	var current_time = Time.get_ticks_msec()
	current_ping = current_time - ping_start_time
	ping_updated.emit(current_ping)
