extends Panel
class_name ItemConfirmPanel

signal confirm_option(yes: bool)

@export var title: String = ''
@export var description: String = ''

@onready var titleLabel: RichTextLabel = get_node('TitleLabel')
@onready var descriptionLabel: RichTextLabel = get_node('DescriptionLabel')
@onready var noButton: Button = get_node('HBoxContainer/NoButton')

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.
	
func load_item_confirm_panel():
	titleLabel.text = '[center]' + title + '[/center]'
	descriptionLabel.text = '[center]' + description + '[/center]'
	visible = true
	noButton.grab_focus()

func _on_yes_button_pressed():
	confirm_option.emit(true)
	visible = false


func _on_no_button_pressed():
	confirm_option.emit(false)
	visible = false