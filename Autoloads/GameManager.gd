extends Node

const SERVER_PORT = 30980
# const SERVER_IP = "ec2-18-144-165-78.us-west-1.compute.amazonaws.com"
const SERVER_IP = "main"

var player_scene = preload("res://player.tscn")
var _players_spawn_node

func _ready():
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

func player_join():
	print("Joining game")

	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, SERVER_PORT)

	multiplayer.multiplayer_peer = client_peer

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
	if not _players_spawn_node.has_node(str(id)):
		return
	_players_spawn_node.get_node(str(id)).queue_free()

func StartGame():
	var scene = preload("res://Game.tscn").instantiate()
	get_tree().root.add_child(scene)
	# var scene = preload("res://Game.tscn")
	# print(get_tree().get_current_scene().name)
	# get_tree().change_scene_to_packed(scene)
