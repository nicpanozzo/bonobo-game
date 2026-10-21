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
