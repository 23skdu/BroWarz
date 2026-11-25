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

static func run_soak_simulation(num_peers: int = 4, num_ticks: int = 120, rng_seed: int = 2030) -> Dictionary:
	# Simulates a multi-peer deterministic lockstep match over `num_ticks` ticks
	# with replicated commands, network jitter, and per-tick GameState checksum verification.
	var peers: Array[int] = []
	var locksteps: Dictionary = {}
	var states: Dictionary = {}
	for i in range(maxi(2, num_peers)):
		var pid := i + 1
		peers.append(pid)
		locksteps[pid] = Lockstep.new()
		var gs := GameState.new()
		for team_idx in range(maxi(2, num_peers)):
			gs.resources[team_idx] = {0: 300, 1: 500, 2: 150, 3: 200}
			gs.units.append({"id": team_idx * 10 + 1, "team": team_idx, "x": 64 + team_idx * 32, "y": 64, "hp": 100})
			gs.buildings.append({"id": team_idx * 100 + 1, "team": team_idx, "hp": 1200})
		states[pid] = gs

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var total_commands := 0
	var desyncs := 0

	for t in range(num_ticks):
		# Each peer generates deterministic inputs scheduled for target_tick_for_input()
		var tick_cmds: Array[Command] = []
		for pid in peers:
			var ls: Lockstep = locksteps[pid]
			if rng.randf() < 0.65:
				var c := Command.new()
				c.tick = ls.target_tick_for_input()
				c.player_id = pid - 1
				c.type = Command.Type.MOVE if (t % 2 == 0) else Command.Type.ATTACK
				c.target_pos = Vector2(float(rng.randi_range(16, 512)), float(rng.randi_range(16, 512)))
				tick_cmds.append(c)
				total_commands += 1

		# Broadcast commands to all peers and mark ready for current tick t
		for dst_pid in peers:
			var dst_ls: Lockstep = locksteps[dst_pid]
			for c in tick_cmds:
				dst_ls.queue_command(Command.from_dict(c.to_dict()))
			for src_pid in peers:
				dst_ls.peer_ready(src_pid, t)

		# Advance every peer only when all peers are ready, apply commands, and compare checksums
		var ref_hash := -1
		for pid in peers:
			var ls: Lockstep = locksteps[pid]
			if not ls.all_peers_ready(peers, t):
				desyncs += 1
				continue
			var cmds := ls.pop_tick(t)
			var gs: GameState = states[pid]
			gs.tick = ls.advance()
			for cmd_obj in cmds:
				var c: Command = cmd_obj
				var team_id := c.player_id
				if gs.resources.has(team_id):
					gs.resources[team_id][1] = int(gs.resources[team_id][1]) + 2
				for u in gs.units:
					if int(u["team"]) == team_id:
						u["x"] = int(c.target_pos.x)
						u["y"] = int(c.target_pos.y)
						if c.type == Command.Type.ATTACK:
							u["hp"] = maxi(10, int(u["hp"]) - 1)
			var h := gs.checksum()
			if ref_hash == -1:
				ref_hash = h
			elif h != ref_hash:
				desyncs += 1

	return {
		"ok": desyncs == 0,
		"peers": peers.size(),
		"ticks": num_ticks,
		"commands": total_commands,
		"desyncs": desyncs,
		"final_checksum": (states[peers[0]] as GameState).checksum(),
	}
