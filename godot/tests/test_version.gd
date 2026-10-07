# Confronto di versioni per il banner "C'è una versione nuova" (ui.gd, E2)
extends RefCounted

var runner


func test_versione_piu_nuova() -> void:
	runner.check(UI.newer_version("0.3.0", "0.2.0"), "minore più alta")
	runner.check(UI.newer_version("0.2.10", "0.2.9"), "numeri, non lettere")
	runner.check(UI.newer_version("1.0", "0.9.9"), "maggiore più alta, meno parti")
	runner.check(not UI.newer_version("0.2.0", "0.2.0"), "uguale")
	runner.check(not UI.newer_version("0.1.5", "0.2.0"), "più vecchia")
	runner.check(not UI.newer_version("0.2", "0.2.0"), "zero finale")
