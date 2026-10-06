# Lettura dei pacchetti Socket.IO (socket_io.gd), senza rete
extends RefCounted

var runner


func _events(packets: Array) -> Array:
	var s := SocketIO.new()
	var got := []
	s.event_received.connect(func(n: String, d: Variant): got.append([n, d]))
	for p in packets:
		s._handle_socket_io(p)
	return got


func test_evento_semplice() -> void:
	var got := _events(['2["welcome",{"id":"x","room":"r"}]'])
	runner.check(got.size() == 1 and got[0][0] == "welcome" and got[0][1].id == "x", str(got))


func test_evento_con_id_di_conferma() -> void:
	var got := _events(['212["snapshot",{"t":1}]'])
	runner.check(got.size() == 1 and got[0][0] == "snapshot" and got[0][1].t == 1, str(got))


func test_evento_senza_dati() -> void:
	var got := _events(['2["roomFull"]'])
	runner.check(got.size() == 1 and got[0][0] == "roomFull" and got[0][1] == null, str(got))


func test_pacchetti_rotti_ignorati() -> void:
	var got := _events(["", "2", "2{rotto", '2["a",', "9qualcosa"])
	runner.check(got.is_empty(), "niente eventi dai pacchetti rotti: %s" % [got])


func test_entrata_e_uscita_dal_namespace() -> void:
	var s := SocketIO.new()
	var log := []
	s.connected.connect(func(): log.append("dentro"))
	s.disconnected.connect(func(): log.append("fuori"))
	s._handle_socket_io("0")
	var joined := s.is_joined()
	s._handle_socket_io("1")
	runner.check(joined and not s.is_joined() and log == ["dentro", "fuori"], str(log))
