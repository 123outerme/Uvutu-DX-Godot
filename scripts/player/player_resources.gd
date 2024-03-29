extends Node
signal story_requirements_updated

@export var playerInfo: PlayerInfo = PlayerInfo.new()
@export var inventory: Inventory = Inventory.new()
@export var questInventory: QuestInventory = QuestInventory.new()
@export var minions: PlayerMinions = PlayerMinions.new()
@export var loaded: bool = false

var player = null

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func accept_rewards(rewards: Array[Reward]) -> int:
	var gainedLevels: int = 0
	for reward in rewards:
		if reward == null:
			continue # skip this reward if it's null
		playerInfo.gold += reward.gold
		gainedLevels += playerInfo.combatant.stats.add_exp(reward.experience)
		inventory.add_item(reward.item)
		if reward.fullyAttuneCombatantSaveName != '':
			minions.fully_attune(reward.fullyAttuneCombatantSaveName)
	if gainedLevels > 0:
		playerInfo.combatant.currentHp = playerInfo.combatant.stats.maxHp
		minions.level_up_minions(playerInfo.combatant.stats.level) # level up all stored minions
	playerInfo.combatant.stats = playerInfo.combatant.stats.copy() # copy stats into combatant's copy
	return gainedLevels

func copy_combatant_to_info(combatant: Combatant):
	playerInfo.combatant.save_from_object(combatant.copy())
	playerInfo.combatant.stats.save_from_object(combatant.stats)

func get_cur_act_save_str() -> String:
	return 'act' + String.num_int64(questInventory.currentAct)

func set_cutscene_seen(saveName: String):
	playerInfo.set_cutscene_seen(saveName)
	questInventory.progress_quest(saveName, QuestStep.Type.CUTSCENE)
	questInventory.auto_turn_in_cutscene_steps(saveName)

func load_data(save_path):
	if playerInfo == null:
		playerInfo = PlayerInfo.new()
	var newPlayerInfo = playerInfo.load_data(save_path)
	if newPlayerInfo != null:
		playerInfo = newPlayerInfo
		playerInfo.combatant.stats = playerInfo.combatant.stats.copy() # copy stats to Combatant obj
		playerInfo.combatant.stats.movepool = playerInfo.combatant.stats.movepool.duplicate(false)
		if playerInfo.combatant.currentHp == -1: # if -1, set to maxHp
			playerInfo.combatant.currentHp = playerInfo.combatant.stats.maxHp
	player = PlayerFinder.player
	if player != null:
		player.position = playerInfo.position
		if playerInfo.spriteFrames != null:
			player.set_sprite_frames(playerInfo.spriteFrames)
		player.facingLeft = playerInfo.flipH
		player.restore_picked_up_item_text(playerInfo.pickedUpItem)
		player.running = playerInfo.running
	inventory = Inventory.new(true)
	var newInv = inventory.load_data(save_path)
	if newInv != null:
		inventory = newInv
	questInventory = QuestInventory.new()
	var newQuestInv = questInventory.load_data(save_path)
	if newQuestInv != null:
		questInventory = newQuestInv
	minions = PlayerMinions.new()
	var newMinions = minions.load_data(save_path)
	if newMinions != null:
		minions = newMinions
	minions.level_up_minions(playerInfo.combatant.stats.level)
	loaded = true

func save_data(save_path):
	if playerInfo != null:
		if player != null:
			playerInfo.position = player.position
			playerInfo.spriteFrames = player.sprite.sprite_frames
			playerInfo.flipH = player.sprite.flip_h
			playerInfo.pickedUpItem = player.pickedUpItem
			playerInfo.running = player.running
		playerInfo.combatant.stats = playerInfo.combatant.stats.copy()
		if playerInfo.combatant.currentHp == -1:
			playerInfo.combatant.currentHp = playerInfo.combatant.stats.maxHp
		playerInfo.save_data(save_path, playerInfo)
	if inventory != null:
		inventory.save_data(save_path, inventory)
	if questInventory != null:
		questInventory.save_data(save_path, questInventory)
	if minions != null:
		minions.save_data(save_path, minions)
	
func new_game(save_path):
	playerInfo = PlayerInfo.new()
	playerInfo.combatant.spriteFrames = load('res://graphics/animations/a_player.tres')
	inventory = Inventory.new(true)
	inventory.save_data(save_path, inventory)
	questInventory = QuestInventory.new()
	questInventory.save_data(save_path, questInventory)
	minions = PlayerMinions.new()
	minions.save_data(save_path, minions)
	loaded = true

func name_player(save_path, characterName: String):
	playerInfo.combatant.stats.displayName = characterName
	playerInfo.combatant.nickname = characterName
	playerInfo.combatant.stats.displayName = characterName
	playerInfo.save_data(save_path, playerInfo)
