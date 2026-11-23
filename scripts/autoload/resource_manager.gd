# scripts/autoload/resource_manager.gd
extends Node

# player_id -> wallet dict (uses Economy.Res keys)
var wallets: Dictionary = {}
var rates: Dictionary = {}
var populations: Dictionary = {}
var caps: Dictionary = {}

func init_player(pid: int, starting: Dictionary = {}) -> void:
	var w = Economy.empty_wallet()
	for k in starting.keys():
		w[k] = starting[k]
	wallets[pid] = w
	rates[pid] = Economy.empty_wallet()
	populations[pid] = 0
	caps[pid] = 10

func get_wallet(pid: int) -> Dictionary:
	if not wallets.has(pid):
		init_player(pid)
	return wallets[pid]

func tick(delta: float) -> void:
	for pid in wallets.keys():
		Economy.apply_income(wallets[pid], rates.get(pid, {}), delta)

func set_rate(pid: int, res: int, rate: int) -> void:
	if not rates.has(pid):
		rates[pid] = Economy.empty_wallet()
	rates[pid][res] = rate
