extends Control
class_name QuestRewardPanel

signal ok_pressed

@export var reward: Reward = null
@export var itemDetailsPanel: ItemDetailsPanel

@onready var rewardPanel: RewardPanel = get_node("Panel/RewardPanel")
@onready var noRewardsLabel: RichTextLabel = get_node("Panel/NoRewardsLabel")
@onready var okButton: Button = get_node("Panel/OkButton")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func load_quest_reward_panel():
	rewardPanel.reward = reward
	rewardPanel.load_reward_panel()
	rewardPanel.show_item_details.connect(_on_show_item_details)
	noRewardsLabel.visible = reward == null
	visible = true
	okButton.grab_focus()

func _on_ok_button_pressed():
	visible = false
	ok_pressed.emit()

func _on_show_item_details(item):
	itemDetailsPanel.item = item
	itemDetailsPanel.count = 0
	itemDetailsPanel.load_item_details()
	itemDetailsPanel.visible = true
