# scripts/core/lockstep.gd
class_name Lockstep
extends RefCounted

# Manages a fixed-tick command buffer for deterministic lockstep.

var tick: int = 0
var input_delay: int = 3
var command_buffer: Dictionary = {}  # tick -> Array of Command
var received_ticks: Dictionary = {}  # peer_id -> last tick

func queue_command(cmd: Command) -> void:
	var t = cmd.tick
	if not command_buffer.has(t):
		command_buffer[t] = []
	command_buffer[t].append(cmd)

func commands_for_tick(t: int) -> Array:
	return command_buffer.get(t, [])

func advance() -> int:
	tick += 1
	return tick

func target_tick_for_input() -> int:
	return tick + input_delay

func has_commands(t: int) -> bool:
	return command_buffer.has(t) and not command_buffer[t].is_empty()

func pop_tick(t: int) -> Array:
	var cmds = command_buffer.get(t, [])
	command_buffer.erase(t)
	return cmds

func peer_ready(peer_id: int, peer_tick: int) -> void:
	received_ticks[peer_id] = peer_tick

func all_peers_ready(peers: Array, required_tick: int) -> bool:
	for pid in peers:
		if int(received_ticks.get(pid, -1)) < required_tick:
			return false
	return true
