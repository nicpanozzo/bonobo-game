# Coda dell'annunciatore (E13 passo 4): decide quale frase dire e quando, senza suonare niente.
# L'annunciatore non parla mai sopra se stesso: una frase arrivata mentre parla aspetta il suo turno,
# prima la più importante; una frase da `interrupt` in su ("GAME!") zittisce tutto e parla subito.
extends RefCounted

var priorities: Dictionary # frase -> priorità (AUDIO.announcerPriority)
var interrupt := 3
var max_wait_ms := 1500
var speaking := "" # la frase che si sente adesso ("" = zitto)
var _queue: Array[Dictionary] = [] # { phrase, priority, at }


func _init(prio: Dictionary, interrupt_from: int, max_wait: int) -> void:
	priorities = prio
	interrupt = interrupt_from
	max_wait_ms = max_wait


# Una frase da dire: true se va detta subito (e allora è già speaking), false se aspetta o si scarta
func push(phrase: String, now: int) -> bool:
	var priority: int = priorities.get(phrase, 1)
	if speaking == "" or priority >= interrupt:
		if priority >= interrupt:
			_queue.clear()
		speaking = phrase
		return true
	if priorities.get(speaking, 1) >= interrupt:
		return false # dopo "GAME!" non si dice più niente
	if phrase == speaking or _queue.any(func(q: Dictionary): return q.phrase == phrase):
		return false # la stessa frase due volte di fila non serve
	_queue.append({"phrase": phrase, "priority": priority, "at": now})
	return false


# La frase in corso è finita: la prossima da dire ("" se non c'è), saltando quelle ormai fuori tempo
func finished(now: int) -> String:
	speaking = ""
	_queue.assign(_queue.filter(func(q: Dictionary): return now - int(q.at) <= max_wait_ms))
	if _queue.is_empty():
		return ""
	var best := 0
	for i in _queue.size():
		if _queue[i].priority > _queue[best].priority:
			best = i # a parità vince chi è arrivato prima
	speaking = _queue[best].phrase
	_queue.remove_at(best)
	return speaking


func clear() -> void:
	speaking = ""
	_queue.clear()


func waiting() -> int:
	return _queue.size()
