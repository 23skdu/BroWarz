# scripts/autoload/network_manager.gd
extends Node

signal peer_connected(id)
signal peer_disconnected(id)
signal connected_to_server()
signal connection_failed()
signal server_disconnected()

var peer: ENetMultiplayerPeer

func host(port: int = 7777, max_clients: int = 8) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_clients)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	return OK

func join(address: String, port: int = 7777) -> Error:
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	return OK

func disconnect_peer() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func _on_peer_connected(id):
	peer_connected.emit(id)
func _on_peer_disconnected(id):
	peer_disconnected.emit(id)
func _on_connected():
	connected_to_server.emit()
func _on_failed():
	connection_failed.emit()
func _on_server_disconnected():
	server_disconnected.emit()

@rpc("any_peer", "call_local", "reliable")
func rpc_chat(sender: int, text: String) -> void:
	pass
