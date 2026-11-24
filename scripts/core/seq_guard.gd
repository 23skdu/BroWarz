# scripts/core/seq_guard.gd
class_name SeqGuard
extends RefCounted

# Per-peer monotonic sequence tracker. Each sender increments its own seq
# for every command; the receiver accepts only non-decreasing values, which
# drops replayed and reordered command packets (anti-replay protection).

var _next: Dictionary = {}  # peer_id -> int (next acceptable seq)

## Returns true when `seq` is acceptable for `peer_id` and advances state.
func accept(peer_id: int, seq: int) -> bool:
	if seq < 0:
		return false
	var expected := int(_next.get(peer_id, 0))
	if seq < expected:
		return false
	_next[peer_id] = seq + 1
	return true

## Next sequence number a local sender should use for `peer_id` (self = 0).
func next_seq(peer_id: int) -> int:
	return int(_next.get(peer_id, 0))

## Reserve/advance the local counter without validation (sender side).
func advance(peer_id: int) -> int:
	var n := int(_next.get(peer_id, 0))
	_next[peer_id] = n + 1
	return n

func expected(peer_id: int) -> int:
	return int(_next.get(peer_id, 0))

func forget(peer_id: int) -> void:
	_next.erase(peer_id)

func clear() -> void:
	_next.clear()
