class_name NetworkSession
extends Node
## Small ENet session wrapper used by the prototype menu.

signal status_changed(message: String)
signal mode_ready(mode: String, peer_id: int)
signal connected_to_host
signal connection_failed
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
signal server_left
signal roster_changed

@export var port: int = 7000
@export var max_players: int = 5

var mode := "single"
var is_host := false
var local_peer_id := 1

func start_single() -> void:
	mode = "single"
	is_host = true
	local_peer_id = 1
	status_changed.emit("Одиночная игра")
	mode_ready.emit(mode, local_peer_id)

func create_host() -> bool:
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, max_players - 1)
	if error != OK:
		status_changed.emit("Не удалось создать игру: %s" % error_string(error))
		return false
	multiplayer.multiplayer_peer = peer
	mode = "host"
	is_host = true
	local_peer_id = multiplayer.get_unique_id()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	status_changed.emit("Игра создана. Ожидание второго игрока...")
	mode_ready.emit(mode, local_peer_id)
	roster_changed.emit()
	return true

func join_host(address: String) -> bool:
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		status_changed.emit("Введите IP-адрес хоста")
		return false
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(clean_address, port)
	if error != OK:
		status_changed.emit("Не удалось подключиться: %s" % error_string(error))
		return false
	multiplayer.multiplayer_peer = peer
	mode = "client"
	is_host = false
	local_peer_id = multiplayer.get_unique_id()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	status_changed.emit("Подключение к %s:%d..." % [clean_address, port])
	return true

func _on_connected_to_server() -> void:
	local_peer_id = multiplayer.get_unique_id()
	status_changed.emit("Подключено к хосту")
	connected_to_host.emit()
	roster_changed.emit()

func _on_connection_failed() -> void:
	status_changed.emit("Подключение отклонено или не удалось")
	connection_failed.emit()
	multiplayer.multiplayer_peer = null

func _on_server_disconnected() -> void:
	status_changed.emit("Хост завершил игру")
	server_left.emit()
	multiplayer.multiplayer_peer = null

func _on_peer_connected(peer_id: int) -> void:
	status_changed.emit("Игрок %d подключился" % peer_id)
	peer_joined.emit(peer_id)
	roster_changed.emit()

func _on_peer_disconnected(peer_id: int) -> void:
	status_changed.emit("Игрок %d отключился" % peer_id)
	peer_left.emit(peer_id)
	roster_changed.emit()
