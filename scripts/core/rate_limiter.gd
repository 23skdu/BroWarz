# scripts/core/rate_limiter.gd
class_name RateLimiter
extends RefCounted

# Token-bucket rate limiter keyed by peer id, with violation strikes that
# escalate to a session ban. Used to stop RPC flooding from a single peer.

var rate: float = 10.0  # tokens per second (steady state)
var burst: float = 20.0  # bucket capacity
var max_strikes: int = 5  # violations before ban
var _tokens: Dictionary = {}
var _last_ms: Dictionary = {}
var _strikes: Dictionary = {}
var _banned: Dictionary = {}

func _init(p_rate: float = 10.0, p_burst: float = 20.0, p_max_strikes: int = 5) -> void:
	rate = maxf(0.1, p_rate)
	burst = maxf(1.0, p_burst)
	max_strikes = maxi(1, p_max_strikes)

## Consume one token for peer `id` at `now_ms`. Returns false when the peer
## is banned or has exhausted its burst allowance.
func try_request(id: int, now_ms: float) -> bool:
	if is_banned(id):
		return false
	_refill(id, now_ms)
	var tokens := float(_tokens.get(id, burst))
	if tokens < 1.0:
		return false
	_tokens[id] = tokens - 1.0
	return true

## Record a protocol violation (malformed payload, replayed seq, bad role).
## Returns true when the peer has exceeded the strike limit and must be
## disconnected by the caller.
func record_violation(id: int) -> bool:
	var n := int(_strikes.get(id, 0)) + 1
	_strikes[id] = n
	if n >= max_strikes:
		_banned[id] = true
		return true
	return false

func is_banned(id: int) -> bool:
	return _banned.get(id, false)

func violations(id: int) -> int:
	return int(_strikes.get(id, 0))

func reset(id: int) -> void:
	_tokens.erase(id)
	_last_ms.erase(id)
	_strikes.erase(id)
	_banned.erase(id)

func clear() -> void:
	_tokens.clear()
	_last_ms.clear()
	_strikes.clear()
	_banned.clear()

func _refill(id: int, now_ms: float) -> void:
	var last := float(_last_ms.get(id, now_ms))
	var elapsed_ms := maxf(0.0, now_ms - last)
	_last_ms[id] = now_ms
	var tokens := float(_tokens.get(id, burst)) + elapsed_ms * 0.001 * rate
	_tokens[id] = minf(burst, tokens)
