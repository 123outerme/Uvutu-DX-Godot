extends Node2D

@export var playerInfo: PlayerInfo
@export var inventory: Inventory

var player = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func load_data(save_path):
	playerInfo = PlayerInfo.new()
	var newPlayerInfo = playerInfo.load_data(save_path)
	if newPlayerInfo != null:
		playerInfo = newPlayerInfo
	player = PlayerFinder.player
	if player != null:
		player.position = playerInfo.position
		player.disableMovement = playerInfo.disableMovement
	inventory = Inventory.new()
	var newInv = inventory.load_data(save_path)
	if newInv != null:
		inventory = newInv

func save_data(save_path):
	if player != null and playerInfo != null:
		playerInfo.position = player.position
		playerInfo.disableMovement = player.disableMovement
		playerInfo.save_data(save_path, playerInfo)
	if inventory != null:
		inventory.save_data(save_path, inventory)
	
func new_game(save_path):
	playerInfo = PlayerInfo.new()
	playerInfo.save_data(save_path, playerInfo)
	inventory = Inventory.new()
	inventory.save_data(save_path, inventory)
