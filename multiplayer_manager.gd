extends Node

const SERVER_PORT = 30980
# const SERVER_IP = "ec2-18-144-165-78.us-west-1.compute.amazonaws.com"
const SERVER_IP = "127.0.0.1"

var player_scene = preload("res://player.tscn")

var _players_spawn_node

func become_host():
	print("Starting host")
	
	_players_spawn_node = get_tree().get_current_scene().get_node("Players")
	
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(SERVER_PORT)
	
	multiplayer.multiplayer_peer = server_peer
	
	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_del_player)
	
func player_join():
	print("Joining game")
	
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, SERVER_PORT)
	
	multiplayer.multiplayer_peer = client_peer
	
func _add_player_to_game(id: int):
	print("Player %s joined the game" % id)
	var player_to_add = player_scene.instantiate()
	player_to_add.player_id = id
	player_to_add.name = str(id)
	player_to_add.position = Vector3(0, 10, 0)
	_players_spawn_node.add_child(player_to_add, true)
	
func _del_player(id: int):
	print("Player %s left the game" % id)
	if not _players_spawn_node.has_node(str(id)):
		return
	_players_spawn_node.get_node(str(id)).queue_free()
	
