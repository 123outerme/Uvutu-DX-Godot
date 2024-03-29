extends Panel
class_name CodexEntryPanel

@export var codexEntry: CodexEntry = null

@onready var entryTitle: RichTextLabel = get_node('EntryTitleLabel')
@onready var entryDescription: RichTextLabel = get_node('EntryDescriptionLabel')
@onready var entryImage: Sprite2D = get_node('EntryImageControl/EntryImage')

# Called when the node enters the scene tree for the first time.
func _ready():
	load_codex_entry_panel()

func load_codex_entry_panel():
	if codexEntry == null:
		return
	
	entryTitle.text = '[center]' + codexEntry.title + '[/center]'
	entryDescription.text = codexEntry.description
	entryImage.texture = codexEntry.image
