# Power-up arcade (#427): i numeri del Tetris in game.json, l'oggetto e la vista dei pezzi
extends RefCounted

var runner

const ArcadeView := preload("res://scripts/arcade_view.gd")
const Predictor := preload("res://scripts/predictor.gd")


func test_tetris_nei_dati() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	runner.check(game.get("tetris") is Dictionary and float(game.tetris.cellPx) > 0.0, "i numeri del Tetris in game.json")
	runner.check(game.items.has("tetris") and game.items.tetris.consume.powerup == "tetris", "l'oggetto Tetris")
	runner.check("tetris" in game.droppableItems, "si può scegliere nelle regole della stanza")


func test_pacman_nei_dati() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	runner.check(game.get("pacman") is Dictionary and float(game.pacman.radiusPx) > 0.0, "i numeri di Pac-Man in game.json")
	runner.check(game.items.has("pacman") and "pacman" in game.droppableItems, "l'oggetto Pac-Man")


func test_palline_e_pacman() -> void:
	var stage := {"solids": [{"x": -100, "y": 560, "width": 500, "height": 100}], "platforms": [{"x": 600, "y": 400, "width": 160}]}
	var dots: Array = ArcadeView.pellets_for(stage, 1280.0)
	runner.check(dots.size() == 10 + 4, "una pallina ogni 40 pixel, dentro lo schermo")
	runner.check(dots.any(func(d): return d[1]), "e qualche pallina grande")
	var view: RefCounted = ArcadeView.new()
	var players := {"p0": {"id": "p0", "powerup": "pacman", "x": 100, "y": 300}, "p1": {"id": "p1", "powerup": null, "x": 500, "y": 560}}
	runner.check(view.pacmen(players).size() == 1, "chi è Pac-Man")


func test_pezzi_dallo_snapshot() -> void:
	var view: RefCounted = ArcadeView.new()
	view.on_snapshot({"tetris": {"pieces": [{"id": 1, "ownerId": "p0", "kind": "T", "cells": [[0, 0], [40, 0], [80, 0], [40, -40]]}], "blocks": [{"x": 0, "y": 560, "kind": "I", "ms": 3000}]}})
	runner.check(view.pieces.size() == 1 and view.blocks.size() == 1, "pezzi e blocchi letti")
	view.on_snapshot({})
	runner.check(view.pieces.is_empty() and view.blocks.is_empty(), "senza tetris niente")
	runner.check(ArcadeView.color_of("O") != ArcadeView.color_of("I"), "ogni forma il suo colore")


func test_vicino_ai_blocchi_decide_il_server() -> void:
	var blocks := [{"x": 600, "y": 520, "kind": "O", "ms": 5000}]
	runner.check(Predictor.near_blocks({"x": 620, "y": 520}, blocks), "sopra il blocco")
	runner.check(not Predictor.near_blocks({"x": 100, "y": 560}, blocks), "lontano")


# Chiama Bassanese: il telefono nei dati, il Bassanese letto dallo snapshot e la testa per il fumetto
func test_bassanese() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/game.json"))
	runner.check(game.items.has("bassanese") and game.items.bassanese.get("call", false), "il telefono di Chiama Bassanese")
	runner.check("bassanese" in game.droppableItems and game.get("bassanese") is Dictionary, "si sceglie nelle regole e ha i suoi numeri")
	var view: RefCounted = preload("res://scripts/bassanese_view.gd").new()
	runner.check(view.head() == null, "senza Bassanese niente fumetto")
	view.on_snapshot({"bassanese": [{"id": 1, "ownerId": "p0", "x": 300, "y": 560, "facing": 1, "phase": "walk"}]})
	runner.check(view.list.size() == 1 and view.head() is Vector2, "letto dallo snapshot, con la testa sopra i piedi")
	var said: Array = []
	view.say = func(text: String): said.append(text)
	view.on_snapshot({"bassanese": [{"id": 1, "ownerId": "p0", "x": 300, "y": 560, "facing": 1, "phase": "look"}]})
	runner.check(said.size() == 1, "si guarda in giro e dice qualcosa: cerca qualcosa")
	view.on_snapshot({})
	runner.check(view.list.is_empty(), "se ne va")
