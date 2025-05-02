extends Node

const SERVER_PORT = 30980
# const SERVER_IP = "ec2-18-144-165-78.us-west-1.compute.amazonaws.com"
const SERVER_IP = "main"

var player_scene = preload("res://player.tscn")
var _players_spawn_node

signal game_state_changed(key, value)

var game_state = {"players": {}}

var ping_start_time = 0
var current_ping = 0
signal ping_updated(ping_value)

var _ping_timer = null

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

func update_game_state(key, value):
	if multiplayer.is_server():
		if key.is_empty():
			game_state = value
		else:
			game_state[key] = value
		notify_game_state_changed.rpc(key, value)
		# game_state_changed.emit(key, value)

@rpc("authority")
func notify_game_state_changed(key, value):
	if key.is_empty():
		game_state = value
	else:
		game_state[key] = value
	game_state_changed.emit(key, value)

func _ready():
	var synchronizer = MultiplayerSynchronizer.new()
	synchronizer.replication_interval = 0.25
	add_child(synchronizer)

	var replication_config = SceneReplicationConfig.new()
	replication_config.add_property(".:game_state")
	synchronizer.replication_config = replication_config

	synchronizer.set_multiplayer_authority(1)
	
	if OS.has_feature("dedicated_server"):
		print("Starting dedicated server...")
		self.become_host()

func become_host():
	print("Game Manager host started")
	
	
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	
	multiplayer.multiplayer_peer = server_peer
	
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)

	self.load_world()

func load_world():
	var scene = preload("res://Game.tscn").instantiate()
	get_tree().root.add_child.call_deferred(scene)

var _connection_callback = null

func player_join(player_name):
	if OS.has_feature("dedicated_server"):
		return
	print("Joining game")

	if _ping_timer != null:
		_ping_timer.queue_free()

	_ping_timer = Timer.new()
	_ping_timer.wait_time = 2.0  # Calculate ping every 2 seconds
	_ping_timer.timeout.connect(calculate_ping)
	add_child(_ping_timer)
	_ping_timer.start()

	if _connection_callback != null:
		if multiplayer.connected_to_server.is_connected(_connection_callback):
			multiplayer.connected_to_server.disconnect(_connection_callback)
		_connection_callback = null

	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, SERVER_PORT)

	multiplayer.multiplayer_peer = client_peer

	# Store the callback for later disconnection
	_connection_callback = func():
		var client_id = multiplayer.get_unique_id()
		print("Connected as client with ID: ", client_id)
		register_player.rpc(client_id, player_name)
	
	multiplayer.connected_to_server.connect(_connection_callback)

@rpc("any_peer")
func register_player(client_id, player_name):
	if not multiplayer.is_server():
		return
	if client_id != multiplayer.get_remote_sender_id():
		print("Security warning: Client tried to register with incorrect ID")
		return
	var players = game_state.players.duplicate()
	players[str(client_id)] = {
		"name": player_name,
		"joined_at": Time.get_unix_time_from_system()
	}
	update_game_state("players", players)
	print("Player registered: ", client_id, " as ", player_name)

func _peer_connected(id: int):
	_players_spawn_node = get_tree().root.get_node("Game").get_node("Players")
	print("Player %s joining" % id)
	var player_to_add = player_scene.instantiate()
	player_to_add.name = str(id)
	player_to_add.position = Vector3(0, 3, 0)
	_players_spawn_node.add_child(player_to_add, true)
	print("Player %s joined" % id)

func _peer_disconnected(id: int):
	print("Player %s left the game" % id)
	
	# Remove player from game state
	if multiplayer.is_server() and game_state.players.has(str(id)):
		var players = game_state.players.duplicate()
		players.erase(str(id))
		update_game_state("players", players)
	
	# Remove player node
	if _players_spawn_node and _players_spawn_node.has_node(str(id)):
		_players_spawn_node.get_node(str(id)).queue_free()

func StartGame():
	var scene = preload("res://Game.tscn").instantiate()
	get_tree().root.add_child(scene)
	# var scene = preload("res://Game.tscn")
	# print(get_tree().get_current_scene().name)
	# get_tree().change_scene_to_packed(scene)
	#
func LeaveGame():
	get_tree().root.get_node("Game").queue_free()
	get_tree().root.get_node("MainMenu").show()
	if _connection_callback != null:
		if multiplayer.connected_to_server.is_connected(_connection_callback):
			multiplayer.connected_to_server.disconnect(_connection_callback)
		_connection_callback = null
	
	multiplayer.multiplayer_peer.close()
	print("Left game")
