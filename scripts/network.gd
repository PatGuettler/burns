class_name BurnsNetwork
extends Node
## JSON/WebSocket transport. Run the same project with -- --server for a room server.
## The server owns all decks; clients receive redacted views and submit intents.
signal changed(snapshot: Dictionary)
signal notice(message: String)

var tcp: TCPServer
var sockets: Dictionary = {}
var identities: Dictionary = {}
var rooms: Dictionary = {}
var client: WebSocketPeer
var credentials: Dictionary = {}
var current_url := ""
var connected := false
var server_mode := false
var next_id := 1
var store_path := "user://server-rooms.cfg"
var pending: Dictionary = {}
var last_cleanup := 0
const MAX_ROOMS := 100
const MAX_SOCKETS := 256

func serve(port: int = 9080, address := "127.0.0.1") -> Error:
	server_mode = true
	tcp = TCPServer.new()
	var err := tcp.listen(port, address)
	if err == OK:
		_restore_rooms()
		print("Burns room server listening on %s:%d" % [address, port])
	return err

func connect_room(url: String, name_value: String, code := "", resume := false) -> Error:
	if client: client.close()
	current_url = url
	client = WebSocketPeer.new()
	client.inbound_buffer_size = 131072
	pending = {"type": "hello", "name": name_value.left(24), "room": code.strip_edges().to_upper()}
	if resume and credentials.has("token"):
		pending = {"type": "hello", "token": credentials.token, "room": credentials.room}
	connected = false
	return client.connect_to_url(url)

func send_action(action: Dictionary, revision: int) -> void:
	_send(client, {"type": "action", "action": action, "revision": revision})

func start_room() -> void:
	_send(client, {"type": "start"})

func disconnect_room() -> void:
	if client: client.close()
	client = null
	connected = false

func _process(_delta: float) -> void:
	if server_mode:
		_server_tick()
	elif client:
		client.poll()
		if client.get_ready_state() == WebSocketPeer.STATE_OPEN:
			if not connected:
				connected = true
				_send(client, pending)
			while client.get_available_packet_count() > 0:
				var msg = JSON.parse_string(client.get_packet().get_string_from_utf8())
				if not msg is Dictionary: continue
				if msg.get("type") == "welcome":
					credentials = {"token": msg.token, "room": msg.room, "seat": int(msg.seat)}
				elif msg.get("type") == "state": changed.emit(msg)
				elif msg.get("type") == "error": notice.emit(str(msg.message))
		elif client.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			client = null
			connected = false
			notice.emit("Connection closed. Reconnect to return to your seat.")

func _send(socket: WebSocketPeer, message: Dictionary) -> void:
	if socket and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.send_text(JSON.stringify(message))

func _server_tick() -> void:
	if not tcp or not tcp.is_listening(): return
	while tcp.is_connection_available():
		var stream := tcp.take_connection()
		if sockets.size() >= MAX_SOCKETS:
			stream.disconnect_from_host()
			continue
		var socket := WebSocketPeer.new()
		socket.inbound_buffer_size = 8192
		socket.max_queued_packets = 32
		socket.accept_stream(stream)
		sockets[next_id] = {"socket": socket, "opened": Time.get_ticks_msec(), "window": 0, "count": 0}
		next_id += 1
	for id in sockets.keys():
		var entry: Dictionary = sockets[id]
		var socket: WebSocketPeer = entry.socket
		socket.poll()
		if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
			var budget := 16
			while socket.get_available_packet_count() > 0 and budget > 0:
				budget -= 1
				var bytes := socket.get_packet()
				var now := Time.get_ticks_msec()
				if now - entry.window > 1000: entry.window = now; entry.count = 0
				entry.count += 1
				if bytes.size() > 4096 or entry.count > 30:
					socket.close(1008, "Request limit exceeded")
					break
				var msg = JSON.parse_string(bytes.get_string_from_utf8())
				if msg is Dictionary: _receive(id, msg)
		if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED or (not identities.has(id) and Time.get_ticks_msec() - entry.opened > 15000):
			socket.close()
			sockets.erase(id)
			if identities.has(id):
				var identity: Dictionary = identities[id]
				identities.erase(id)
				if rooms.has(identity.room):
					rooms[identity.room].seats[identity.seat].peer = -1
					_broadcast(identity.room)
	if Time.get_ticks_msec() - last_cleanup > 60000:
		last_cleanup = Time.get_ticks_msec()
		var expired := false
		for code in rooms.keys():
			var room: Dictionary = rooms[code]
			if Time.get_unix_time_from_system() - room.updated > 86400:
				var occupied := false
				for seat in room.seats:
					if seat.peer != -1: occupied = true
				if not occupied:
					rooms.erase(code)
					expired = true
		if expired: _persist_rooms()

func _error(id: int, message: String) -> void:
	_send(sockets[id].socket, {"type": "error", "message": message})

func _receive(id: int, msg: Dictionary) -> void:
	if msg.get("type") == "hello":
		if identities.has(id): return
		var code := str(msg.get("room", "")).left(12)
		var token := str(msg.get("token", "")).left(128)
		if code.is_empty():
			if not token.is_empty(): _error(id, "Room required to reconnect."); return
			if rooms.size() >= MAX_ROOMS: _error(id, "Server is full."); return
			code = Crypto.new().generate_random_bytes(4).hex_encode().to_upper()
			while rooms.has(code): code = Crypto.new().generate_random_bytes(4).hex_encode().to_upper()
			rooms[code] = {"seats": [], "game": null, "updated": Time.get_unix_time_from_system()}
		if not rooms.has(code): _error(id, "Room not found."); return
		var room: Dictionary = rooms[code]
		var seat_index := -1
		if not token.is_empty():
			for i in range(room.seats.size()):
				if room.seats[i].token == token and room.seats[i].peer == -1: seat_index = i
			if seat_index == -1: _error(id, "This seat is unavailable or the reconnect key is invalid."); return
		else:
			if room.game != null or room.seats.size() >= 8: _error(id, "This table has started or is full."); return
			seat_index = room.seats.size()
			token = Crypto.new().generate_random_bytes(32).hex_encode()
			var player_name := str(msg.get("name", "Player")).strip_edges().left(24)
			if player_name.is_empty(): player_name = "Player %d" % (seat_index + 1)
			room.seats.append({"name": player_name, "peer": id, "token": token})
		room.seats[seat_index].peer = id
		identities[id] = {"room": code, "seat": seat_index}
		_send(sockets[id].socket, {"type": "welcome", "room": code, "seat": seat_index, "token": token})
		_broadcast(code)
		return
	if not identities.has(id): _error(id, "Join a room first."); return
	var identity: Dictionary = identities[id]
	var room: Dictionary = rooms[identity.room]
	if msg.get("type") == "start":
		if identity.seat != 0 or room.game != null or room.seats.size() < 2:
			_error(id, "Only the host can start a table with at least two players."); return
		for seat in room.seats:
			if seat.peer == -1: _error(id, "Wait for everyone to reconnect."); return
		room.game = BurnsGame.new()
		room.game.start(room.seats.map(func(p: Dictionary): return p.name), randi())
	elif msg.get("type") == "action":
		if room.game == null or not msg.get("action") is Dictionary: return
		if msg.get("revision", -1) != room.game.s.revision:
			_error(id, "The table changed. Please try again."); _send_state(id, identity.room, identity.seat); return
		for seat in room.seats:
			if seat.peer == -1: _error(id, "Play is paused while a player reconnects."); return
		var error: String = room.game.act(identity.seat, msg.action)
		if not error.is_empty(): _error(id, error); return
	else: return
	_broadcast(identity.room)

func _broadcast(code: String) -> void:
	var room: Dictionary = rooms[code]
	room.updated = Time.get_unix_time_from_system()
	_persist_rooms()
	for i in range(room.seats.size()):
		var peer: int = room.seats[i].peer
		if sockets.has(peer): _send_state(peer, code, i)

func _send_state(peer: int, code: String, seat: int) -> void:
	var room: Dictionary = rooms[code]
	var seats: Array = room.seats.map(func(p: Dictionary): return {"name": p.name, "connected": p.peer != -1})
	_send(sockets[peer].socket, {"type": "state", "room": code, "seat": seat, "seats": seats,
		"game": room.game.view() if room.game != null else {}})

func _persist_rooms() -> void:
	var file := ConfigFile.new()
	var data: Dictionary = {}
	for code in rooms:
		var room: Dictionary = rooms[code]
		var seats: Array = room.seats.map(func(p: Dictionary): return {"name": p.name, "peer": -1, "token": p.token})
		data[code] = {"seats": seats, "updated": room.updated, "game": room.game.s if room.game != null else {}}
	file.set_value("server", "rooms", data)
	var error := file.save(store_path + ".tmp")
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(store_path + ".tmp"), ProjectSettings.globalize_path(store_path))
	if error != OK: push_error("Room persistence failed: " + error_string(error))

func _restore_rooms() -> void:
	var file := ConfigFile.new()
	if file.load(store_path) != OK: return
	var data = file.get_value("server", "rooms", {})
	if not data is Dictionary: return
	var expired := false
	for code in data:
		var saved = data[code]
		if not saved is Dictionary or not saved.has_all(["seats", "updated", "game"]): continue
		if not saved.seats is Array or saved.seats.size() > 8: continue
		if typeof(saved.updated) not in [TYPE_INT, TYPE_FLOAT]: continue
		if Time.get_unix_time_from_system() - saved.updated > 86400:
			expired = true
			continue
		var valid := true
		for seat in saved.seats:
			if not seat is Dictionary or not seat.has_all(["name", "token"]): valid = false; break
			if not seat.name is String or not seat.token is String: valid = false; break
			seat.peer = -1
		if not valid: continue
		var restored: BurnsGame = null
		if not saved.game is Dictionary: continue
		if not saved.game.is_empty():
			restored = BurnsGame.new()
			if not restored.restore(saved.game) or restored.s.players.size() != saved.seats.size(): continue
		rooms[code] = {"seats": saved.seats, "updated": saved.updated, "game": restored}
	if expired: _persist_rooms()
