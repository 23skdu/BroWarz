# scripts/autoload/resource_manager.gd
extends Node

# player_id -> wallet dict (uses Economy.Res keys)
var wallets: Dictionary = {}
# Unmodified production rates; power efficiency is applied to these, never
# back into them (otherwise a brownout compounds on every economy tick).
var base_rates: Dictionary = {}
# Effective rates used for income and HUD display.
var rates: Dictionary = {}
var caps: Dictionary = {}
# team -> last efficiency applied by the power grid (0.0..1.0, 1.0 = powered)
var power_efficiency: Dictionary = {}

## Clear all per-team economy state so saved/multiplayer teams do not leak
## into the next match.
func reset() -> void:
	wallets.clear()
	base_rates.clear()
	rates.clear()
	caps.clear()
	power_efficiency.clear()

func init_player(pid: int, starting: Dictionary = {}) -> void:
	var w = Economy.empty_wallet()
	for k in starting.keys():
		w[k] = starting[k]
	wallets[pid] = w
	base_rates[pid] = Economy.empty_wallet()
	rates[pid] = Economy.empty_wallet()
	caps[pid] = 10
	power_efficiency[pid] = 1.0

func get_wallet(pid: int) -> Dictionary:
	if not wallets.has(pid):
		init_player(pid)
	return wallets[pid]

func tick(delta: float) -> void:
	for pid in wallets.keys():
		Economy.apply_income(wallets[pid], rates.get(pid, {}), delta)

func get_base_rate(pid: int, res: int) -> int:
	var team_rates: Dictionary = base_rates.get(pid, {})
	return int(team_rates.get(res, 0))

func effective_rate(pid: int, res: int) -> int:
	var eff := float(power_efficiency.get(pid, 1.0))
	return int(round(float(get_base_rate(pid, res)) * clampf(eff, 0.0, 1.0)))

func set_rate(pid: int, res: int, rate: int) -> void:
	if not base_rates.has(pid):
		base_rates[pid] = Economy.empty_wallet()
	if not rates.has(pid):
		rates[pid] = Economy.empty_wallet()
	(base_rates[pid] as Dictionary)[res] = rate
	(rates[pid] as Dictionary)[res] = effective_rate(pid, res)

func set_power_efficiency(pid: int, eff: float) -> void:
	power_efficiency[pid] = clampf(eff, 0.0, 1.0)
	refresh_rates(pid)

func refresh_rates(pid: int) -> void:
	if not rates.has(pid):
		rates[pid] = Economy.empty_wallet()
	for res in [Economy.Res.OIL, Economy.Res.IRON, Economy.Res.GEOTHERMAL, Economy.Res.FOOD]:
		(rates[pid] as Dictionary)[res] = effective_rate(pid, res)
