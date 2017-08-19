extends Node

const WorldPath = "res://levels/World.tscn"
const LevelLoaderGd = preload("res://levels/LevelLoader.gd")

const DEFAULT_PORT = 10567
const MAX_PEERS = 12

var m_playerName = "Player"  setget deleted
# Names for remote players, including host, in id:name format
var m_players = {}           setget deleted, deleted
#var get_node("LevelLoader") = LevelLoaderGd.new() setget deleted, deleted

# Signals to let lobby GUI know what's going on
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)
signal sendVariable(name, value)
signal networkPeerChanged()


func deleted():
	assert(false)
	
func _ready():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self,"_player_disconnected")
	get_tree().connect("connected_to_server", self, "_connected_ok")
	get_tree().connect("connection_failed", self, "_connected_fail")
	get_tree().connect("server_disconnected", self, "_server_disconnected")

	var levelLoaderNode = Node.new()
	levelLoaderNode.set_name("LevelLoader")
	levelLoaderNode.set_script( LevelLoaderGd )
	add_child(levelLoaderNode)


# Callback from SceneTree
func _player_connected(id):
	if (not get_tree().is_network_server() and not isGameInProgress()):
		return
		
	get_node("LevelLoader").sendLevelToPlayer(id)


# Callback from SceneTree
func _player_disconnected(id):
	unregister_player(id)
	for p_id in m_players:
		if p_id != get_tree().get_network_unique_id():
			rpc_id(p_id, "unregister_player", id)


func _connected_ok():
	assert(not get_tree().is_network_server())
	# Registration of a client beings here, tell everyone that we are here
	rpc("register_player", get_tree().get_network_unique_id(), m_playerName)
	register_player(get_tree().get_network_unique_id(), m_playerName)
	emit_signal("connection_succeeded")


func _server_disconnected():
	assert(not get_tree().is_network_server())
	emit_signal("game_error", "Server disconnected")
	end_game()


func _connected_fail():
	assert(not get_tree().is_network_server())
	get_tree().set_network_peer(null) # Remove peer
	emit_signal("connection_failed")

# Lobby management functions

remote func register_player(id, name):
	if (get_tree().is_network_server()):
		for p_id in m_players: # Then, for each remote player
			rpc_id(id, "register_player", p_id, m_players[p_id]) # Send player to new dude
			rpc_id(p_id, "register_player", id, name) # Send new dude to player

	m_players[id] = name
	emit_signal("player_list_changed")

remote func unregister_player(id):
	m_players.erase(id)
	emit_signal("player_list_changed")


var players_ready = []

remote func ready_to_start(id):
	assert(get_tree().is_network_server())

	if (not id in players_ready):
		players_ready.append(id)

	if (players_ready.size() == m_players.size()):
		for p in m_players:
			rpc_id(p, "post_start_game")
		post_start_game()


func host_game(name):
	m_playerName = name
	var host = NetworkedMultiplayerENet.new()
	host.create_server(DEFAULT_PORT, MAX_PEERS)
	setNetworkPeer(host)


func join_game(ip, name):
	m_playerName = name
	if (get_tree().is_network_server()):
		register_player(get_tree().get_network_unique_id(), m_playerName)
		return

	var host = NetworkedMultiplayerENet.new()
	host.create_client(ip, DEFAULT_PORT)
	setNetworkPeer(host)

func get_player_list():
	return m_players

func get_player_name():
	return m_playerName

	
func begin_game():
	assert(get_tree().is_network_server())
	rpc("pre_start_game", m_players)


sync func pre_start_game(playersOnServer):
	get_node("LevelLoader").loadLevel(WorldPath)
	get_node("LevelLoader").insertPlayers(playersOnServer)

	if (not get_tree().is_network_server()):
		# Tell server we are ready to start
		rpc_id(1, "ready_to_start", get_tree().get_network_unique_id())
	elif m_players.size() == 0:
		post_start_game()


remote func post_start_game():
	get_tree().set_pause(false) # Unpause and unleash the game!


func end_game():
	if (isGameInProgress()):
		get_node("LevelLoader").unloadLevel()

	emit_signal("game_ended")
	m_players.clear()
	emit_signal("player_list_changed")
	setNetworkPeer(null)


func isGameInProgress():
	return get_node("LevelLoader").m_loadedLevel != null
	
	
func setNetworkPeer(host):
	get_tree().set_network_peer(host)
	
	var peerId = str(host.get_instance_ID()) if get_tree().has_network_peer() else null
	if peerId != null and get_tree().is_network_server():
		peerId += " (server)" 
	emit_signal("sendVariable", "network_host_ID", peerId )
	emit_signal("networkPeerChanged")