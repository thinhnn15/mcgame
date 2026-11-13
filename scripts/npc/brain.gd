class_name NpcBrain
extends Node

const NEEDS := ["energy", "social", "fun", "thirst"]

var npc: Npc
var place
var traits := {}
var needs := {"energy": 1.0, "social": 1.0, "fun": 1.0, "thirst": 1.0}
var doing := ""
var engaged := false
var cooldown := {}
var _pending: Callable
var _pending_prio := 0
var _prio := 0
var _alive := true

func setup(p_npc: Npc, p_place, p_traits: Dictionary) -> void:
	npc = p_npc
	place = p_place
	traits = p_traits
	for k in NEEDS:
		needs[k] = randf_range(0.45, 1.0)
	_life.call_deferred()

func trait_of(name: String, default := 0.5) -> float:
	return float(traits.get(name, default))

func need(k: String) -> float:
	return needs[k]

func fill(k: String, amount: float) -> void:
	needs[k] = clampf(needs[k] + amount, 0.0, 1.0)

func now() -> float:
	return Npc.clock

func ready_for(activity: String) -> bool:
	return now() >= float(cooldown.get(activity, 0.0))

func rest(activity: String, secs: float) -> void:
	"""Not again for secs (of life time: --life-speed makes it all come round faster)."""
	cooldown[activity] = now() + secs / place.life_speed

func _process(delta: float) -> void:
	var k: float = place.life_speed * delta / 60.0
	var working := doing == "work"
	needs["energy"] = clampf(needs["energy"] - k * (0.10 if working else 0.04) * (0.6 + trait_of("sleepy")), 0, 1)
	needs["social"] = clampf(needs["social"] - k * 0.12 * (0.5 + trait_of("social")), 0, 1)
	needs["fun"] = clampf(needs["fun"] - k * (0.14 if working else 0.05) * (0.6 + trait_of("restless")), 0, 1)
	needs["thirst"] = clampf(needs["thirst"] - k * 0.10 * (0.6 + trait_of("coffee")), 0, 1)

func react(what: Callable, prio := 5, name := "react") -> bool:
	"""Cut in with something that matters more than what it is doing now. False if it is busy with
	something at least as important."""
	if prio <= _prio or prio <= _pending_prio:
		return false
	_pending = what
	_pending_prio = prio
	set_meta("pending_name", name)
	npc.interrupt()
	return true

func busy_with_priority() -> int:
	return _prio

func _life() -> void:
	await get_tree().create_timer(randf_range(0.5, 3.0)).timeout
	while _alive and is_instance_valid(npc):
		if _pending.is_valid():
			var r := _pending
			_prio = _pending_prio
			doing = str(get_meta("pending_name", "react"))
			_pending = Callable()
			_pending_prio = 0
			await r.call()
			_prio = 0
			engaged = false
			place.release(self)
			continue
		if not await place.home(self):
			await get_tree().process_frame
			continue
		doing = "work"
		if not await npc.wait(randf_range(7.0, 16.0) / place.life_speed):
			continue
		var pick := _choose()
		if pick.is_empty():
			continue
		doing = pick["name"]
		_prio = 1
		await pick["run"].call()
		_prio = 0
		engaged = false
		place.release(self)

func _choose() -> Dictionary:
	"""The activity worth most right now (needs x personality x a little chance), or none (keep working)."""
	var best := {}
	var best_score := 0.42
	for a in place.activities_for(self):
		if not ready_for(a["name"]):
			continue
		var s: float = a["score"] * randf_range(0.8, 1.2)
		if s > best_score:
			best = a
			best_score = s
	return best

func _exit_tree() -> void:
	_alive = false
