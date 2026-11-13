extends Node

const PORT := 24680
const PROTOCOL := 2
const MAX_VISITORS := 3
const PROFILE := "user://profile.json"
const STATE_HZ := 15.0

enum Mode { OFFLINE, HOST, CLIENT }
var mode := Mode.OFFLINE
var my_name := ""
var me := {}
var players := {}
var states := {}
var world := {}
var upnp_note := ""

signal session_changed
signal player_joined(id: int)
signal player_left(id: int)
signal player_changed(id: int)
signal acted(id: int, kind: String, arg: String)
signal notice(text: String)

var _upnp: UPNP
var _upnp_thread: Thread
var _last_sent := {}
var _send_wait := 0.0

func _ready() -> void:
	_load_profile()
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_gone)
	_reset_offline()
	var n := Stage.arg("--name")
	if n != "":
		my_name = n
		me["name"] = n
	var j := Stage.arg("--join")
	if "--host" in OS.get_cmdline_user_args():
		host.call_deferred()
	elif j != "":
		join.call_deferred(j)
	if "--host" in OS.get_cmdline_user_args() or j != "":
		get_tree().change_scene_to_file.call_deferred("res://scenes/village.tscn")

func my_id() -> int:
	"""My peer id; 1 while offline, including the moments of knocking on a friend's gate before the welcome."""
	return multiplayer.get_unique_id() if online() else 1

func online() -> bool:
	return mode != Mode.OFFLINE

func owns_world() -> bool:
	"""True offline and for the host: only the world's owner changes it (felled trees, caught fish...)."""
	return multiplayer.is_server()

func host_name() -> String:
	return str(players.get(1, {}).get("name", ""))

func _load_profile() -> void:
	if FileAccess.file_exists(PROFILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(PROFILE))
		if d is Dictionary:
			my_name = str(d.get("name", ""))
	if my_name == "":
		my_name = Lang.t("NET_DEFAULT_NAME", {"n": "%02d" % (randi() % 100)})

func set_my_name(n: String) -> void:
	n = n.strip_edges().left(16)
	if n == "" or n == my_name:
		return
	my_name = n
	var f := FileAccess.open(PROFILE, FileAccess.WRITE)
	f.store_string(JSON.stringify({"name": my_name}, "\t"))
	_set_me({"name": my_name})

func set_look(look: Dictionary) -> void:
	"""The scene calls this with the saved look; the others rebuild my avatar only if it changed."""
	if me.get("look", {}) != look:
		_set_me({"look": look})

func _set_me(change: Dictionary) -> void:
	me.merge(change, true)
	if online():
		_update.rpc(me)
	player_changed.emit(my_id())

@rpc("any_peer", "call_remote", "reliable")
func _update(info: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		players[id] = _clean(info)
		player_changed.emit(id)

func host(port := PORT) -> bool:
	if online():
		leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_VISITORS + 1)
	if err != OK:
		notice.emit(Lang.t("NET_PORT_BUSY", {"port": port}))
		return false
	multiplayer.multiplayer_peer = peer
	players = {1: me}
	states.clear()
	mode = Mode.HOST
	upnp_note = tr("NET_UPNP_ASK")
	_upnp_thread = Thread.new()
	_upnp_thread.start(_open_router_port.bind(port))
	session_changed.emit()
	notice.emit(tr("NET_GATE_OPEN"))
	return true

func join(address: String, port := PORT) -> bool:
	if online():
		leave()
	address = address.strip_edges()
	if ":" in address:
		port = int(address.get_slice(":", 1))
		address = address.get_slice(":", 0)
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(address, port) != OK:
		notice.emit(Lang.t("NET_BAD_ADDRESS", {"addr": address}))
		return false
	multiplayer.multiplayer_peer = peer
	notice.emit(Lang.t("NET_GOING", {"addr": address}))
	return true

func leave() -> void:
	if mode == Mode.HOST:
		_gate_closed.rpc()
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).host.flush()
		_close_router_port()
	_reset_offline()
	session_changed.emit()

func _reset_offline() -> void:
	if me.is_empty():
		me = {"name": my_name, "look": Looks.load_saved()}
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players = {1: me}
	states.clear()
	world = {}
	mode = Mode.OFFLINE

func _on_connected() -> void:
	_hello.rpc_id(1, PROTOCOL, me)

@rpc("any_peer", "call_remote", "reliable")
func _hello(protocol: int, info: Dictionary) -> void:
	var id := multiplayer.get_remote_sender_id()
	if protocol != PROTOCOL:
		_turned_away.rpc_id(id, "NET_VERSION", {"a": protocol, "b": PROTOCOL})
		_kick_later(id)
		return
	if players.size() > MAX_VISITORS:
		_turned_away.rpc_id(id, "NET_FULL", {})
		_kick_later(id)
		return
	info = _clean(info)
	_welcome.rpc_id(id, players, world)
	for other in players:
		if other != 1:
			_arrived.rpc_id(other, id, info)
	players[id] = info
	player_joined.emit(id)
	notice.emit(Lang.t("NET_ARRIVED", {"name": info["name"]}))

func _kick_later(id: int) -> void:
	await get_tree().create_timer(0.5).timeout
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		multiplayer.multiplayer_peer.disconnect_peer(id)

@rpc("authority", "call_remote", "reliable")
func _welcome(roster: Dictionary, host_world: Dictionary) -> void:
	mode = Mode.CLIENT
	players = {}
	for id in roster:
		players[int(id)] = _clean(roster[id])
	players[my_id()] = me
	world = host_world
	states.clear()
	session_changed.emit()
	notice.emit(Lang.t("NET_WELCOME", {"host": host_name()}))

@rpc("authority", "call_remote", "reliable")
func _arrived(id: int, info: Dictionary) -> void:
	players[id] = _clean(info)
	player_joined.emit(id)
	notice.emit(Lang.t("NET_ALSO_ARRIVED", {"name": info["name"]}))

@rpc("authority", "call_remote", "reliable")
func _departed(id: int) -> void:
	_drop(id)

@rpc("authority", "call_remote", "reliable")
func _turned_away(key: String, args: Dictionary) -> void:

	_reset_offline()
	session_changed.emit()
	notice.emit(Lang.t(key, args) if key.begins_with("NET_") else key)

@rpc("authority", "call_remote", "reliable")
func _gate_closed() -> void:
	var who := host_name()
	_reset_offline()
	session_changed.emit()
	notice.emit(Lang.t("NET_HOST_CLOSED", {"name": who}))

func _on_peer_disconnected(id: int) -> void:
	if mode == Mode.HOST:
		_departed.rpc(id)
	_drop(id)

func _drop(id: int) -> void:
	if players.has(id) and id != my_id():
		var who: String = players[id]["name"]
		players.erase(id)
		states.erase(id)
		player_left.emit(id)
		notice.emit(Lang.t("NET_LEFT", {"name": who}))

func _on_failed() -> void:
	_reset_offline()
	session_changed.emit()
	notice.emit(tr("NET_CANT_REACH"))

func _on_server_gone() -> void:
	if mode == Mode.OFFLINE:
		return
	_reset_offline()
	session_changed.emit()
	notice.emit(tr("NET_LOST"))

static func _clean(info: Dictionary) -> Dictionary:
	"""Whatever comes off the wire: a short name and a look dictionary, nothing else."""
	var look = info.get("look", {})
	return {"name": str(info.get("name", "?")).left(16), "look": look if look is Dictionary else {}}

func send_state(pos: Vector3, yaw: float, clip: String, speed: float, delta: float) -> void:
	"""Called every physics frame by the local player; sends at STATE_HZ while anything changes."""
	if not online():
		return
	_send_wait -= delta
	var st := {"pos": pos, "yaw": yaw, "clip": clip, "speed": speed}
	var moving: bool = _last_sent.is_empty() or st["clip"] != _last_sent["clip"] \
		or pos.distance_to(_last_sent["pos"]) > 0.01 or absf(angle_difference(yaw, _last_sent["yaw"])) > 0.02
	if _send_wait > 0.0 or (not moving and _send_wait > -0.5):
		return
	_send_wait = 1.0 / STATE_HZ
	_last_sent = st
	_state.rpc(pos, yaw, clip, speed)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(pos: Vector3, yaw: float, clip: String, speed: float) -> void:
	var id := multiplayer.get_remote_sender_id()
	if players.has(id):
		states[id] = {"pos": pos, "yaw": yaw, "clip": clip.left(32), "speed": clampf(speed, 0.0, 3.0)}

func act(kind: String, arg := "") -> void:
	"""A one-shot action everyone plays (the sender too, at once): act("emote", "wave")."""
	_act.rpc(kind, arg)

@rpc("any_peer", "call_local", "reliable")
func _act(kind: String, arg: String) -> void:
	var id := multiplayer.get_remote_sender_id()
	if id == 0 or id == multiplayer.get_unique_id():
		id = my_id()
	if players.has(id):
		acted.emit(id, kind.left(16), arg.left(32))

func lan_addresses() -> Array:
	"""This machine's addresses friends on the same Wi-Fi can type."""
	var out := []
	for a in IP.get_local_addresses():

		if a.count(".") == 3 and ["192.168.", "10.", "172.", "26.", "100."].any(func(pre): return a.begins_with(pre)):
			out.append(a)
	return out

func _open_router_port(port: int) -> void:
	"""Thread: ask the router (UPnP) to forward the port, so friends outside the house can come too."""
	var u := UPNP.new()
	var note := ["NET_NO_UPNP", ""]
	if u.discover(2000, 2) == UPNP.UPNP_RESULT_SUCCESS and u.get_gateway() and u.get_gateway().is_valid_gateway():
		if u.add_port_mapping(port, port, "mcgame", "UDP") == UPNP.UPNP_RESULT_SUCCESS:
			note = ["NET_FAR", u.query_external_address()]
			_upnp = u
	_set_upnp_note.call_deferred(note[0], note[1])

func _set_upnp_note(key: String, addr: String) -> void:
	upnp_note = Lang.t(key, {"addr": addr})

func _close_router_port() -> void:
	if _upnp_thread:
		_upnp_thread.wait_to_finish()
		_upnp_thread = null
	if _upnp:
		_upnp.delete_port_mapping(PORT, "UDP")
		_upnp = null
	upnp_note = ""

func _exit_tree() -> void:
	if mode == Mode.HOST:
		_close_router_port()
