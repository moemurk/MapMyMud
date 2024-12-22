extends Node3D
@export var PORT: int = 2368

func _ready():
	if OS.has_feature("dedicated_server"):
		print("dedicated_server")
		var peer = ENetMultiplayerPeer.new()
		multiplayer.peer_connected.connect(_on_player_connected)
		multiplayer.peer_disconnected.connect(_on_player_disconnected)
		var err = peer.create_server(PORT, MAX_PLAYER)
		if err:
			print("server create failed:", err)
		else:
			print("server waiting")
		multiplayer.multiplayer_peer = peer

#*************************************#
#Client#
#*************************************#
@export var player_name: String = "default player"
@export var play_roll: Client.PlayRoll = Client.PlayRoll.Driver
@export var team_mate_id: int

func connect_to_server():
	var peer = ENetMultiplayerPeer.new()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_disconnected_to_server)
	var err = peer.create_client("127.0.0.1", PORT)
	if err:
		print("join server failed:", err)
		return
	else:
		print("join_server succeed!")
	multiplayer.multiplayer_peer = peer

func _on_connected_to_server():
	register_clinet.rpc_id(1, player_name, play_roll)

func _on_disconnected_to_server():
	print("loss connection to server")

#*************************************#
#Server#
#*************************************#
@export var MAX_PLAYER: int = 2

var clients: Array[Client] = []
var game_state: GameState = GameState.Waiting
var teams: Array = []
var cars: Array[VehicleBody3D] = []

enum GameState {
	Waiting,
	Running,
	End,
}

func _on_player_connected(id: int):
	print("client connect %d" % id)
	pass

func _on_player_disconnected(id: int):
	print("client disconnect %d" % id)
	pass	

func server_regist_client(client_id: int, player_name: String, roll: Client.PlayRoll):
	clients.append(Client.create(client_id, player_name, roll))
	print("client register %d %s" % [client_id, player_name])
	if clients.size() == MAX_PLAYER:
		# we should seperate the players into different teams here
		teams = make_teams()
		game_state = GameState.Running
		var teams_str = []
		for team in teams:
			teams_str.append(var_to_str(team))
		load_map.rpc(teams_str)

func make_teams() -> Array:
	var drivers = []
	var observers = []
	var teams = []
	for c in clients:
		match c._roll:
			Client.PlayRoll.Driver:
				drivers.append(c)
			Client.PlayRoll.Observer:
				observers.append(c)
	for i in range(mini(drivers.size(), observers.size())):
		teams.append([drivers[i], observers[i]])
	return teams

#*************************************#
#rpc func#
#*************************************#
@rpc("any_peer", "reliable")
func register_clinet(player_name: String, roll: Client.PlayRoll):
	print("call register_clinet %s" % player_name)
	if multiplayer.is_server():
		print("server: register_clinet")
		server_regist_client(multiplayer.get_remote_sender_id(), player_name, roll)

@rpc("reliable")
func load_map(team_strs: Array):
	print("load_map", teams)
	var teams = []
	for team_str in team_strs:
		var team = str_to_var(team_str)
		if team[0]._network_id == multiplayer.get_unique_id():
			self.team_mate_id = team[1]._network_id
		if team[1]._network_id == multiplayer.get_unique_id():
			self.team_mate_id = team[0]._network_id
		teams.append(team)
	self.teams = teams
	if self.play_roll == Client.PlayRoll.Driver:
		SceneManager.change_scene("map1")
	else:
		SceneManager.change_scene("codriver")

@rpc("any_peer", "reliable")
func ready():
	pass

@rpc("reliable")
func game_start():
	pass

@rpc("any_peer", "reliable")
func direct(to_send_pacenote: String):
	print("I'm the %s my name is %s and I recv_direct" % [self.play_roll, self.player_name])
	print(to_send_pacenote)
	var to_send_pacenote_object:CodriverMessage = str_to_var(to_send_pacenote)
	to_send_pacenote_object.direction # visulize here
	#get world node, then call the funcion in network.gd
	print(to_send_pacenote_object)

@rpc("any_peer", "unreliable")
func car_move(position: Vector3, rotation: Vector3):
	var remote_id = multiplayer.get_remote_sender_id()
	for car in cars:
		if car.name == str(remote_id):
			car.position = position
			car.rotation = rotation
	if self.play_roll == Client.PlayRoll.Observer:
		if self.team_mate_id == remote_id:
			# 3d pos & rotation to 2d pos & rotation, then visulize
			pass
