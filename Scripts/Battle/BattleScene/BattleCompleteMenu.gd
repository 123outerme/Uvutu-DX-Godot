extends Control
class_name BattleCompleteMenu

@export var battleUI: BattleUI
@export var itemDetailsPanel: ItemDetailsPanel

var playerWins: bool = true
var rewards: Array[Reward] = []

@onready var rewardsVBox: VBoxContainer = get_node("RewardsVBox")
@onready var battleWinLabel: RichTextLabel = get_node("BattleWinLabel")
@onready var battleRewardsLabel: RichTextLabel = get_node("BattleRewardsLabel")
@onready var battleLoseLabel: RichTextLabel = get_node("BattleLoseLabel")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func load_battle_over_menu():
	rewardsVBox.visible = playerWins
	battleWinLabel.visible = playerWins
	battleRewardsLabel.visible = playerWins
	battleLoseLabel.visible = not playerWins
	if playerWins:
		var rewardPanel = load("res://Prefabs/UI/RewardPanel.tscn")
		for reward in rewards:
			var instantiatedPanel: RewardPanel = rewardPanel.instantiate()
			instantiatedPanel.reward = reward
			rewardsVBox.add_child(instantiatedPanel)
			instantiatedPanel.load_reward_panel(itemDetailsPanel)

func _on_ok_button_pressed():
	PlayerResources.playerInfo.stats = battleUI.battleController.playerCombatant.combatant.stats.copy()
	PlayerResources.playerInfo.combatant = battleUI.battleController.playerCombatant.combatant.copy()
	# copy player changes to PlayerResources
	print(PlayerResources.playerInfo.combatant.currentHp)
	var levels: int = PlayerResources.accept_rewards(rewards)
	print(PlayerResources.playerInfo.stats.exp)
	# copy rewards changes back to battle combatant
	battleUI.battleController.playerCombatant.combatant = PlayerResources.playerInfo.combatant.copy()
	if levels > 0:
		battleUI.set_menu_state(BattleState.Menu.LEVEL_UP)
	else:
		if battleUI.battleController.playerCombatant.combatant.currentHp <= 0:
			battleUI.battleController.playerCombatant.combatant.currentHp = 1
		battleUI.end_battle()
