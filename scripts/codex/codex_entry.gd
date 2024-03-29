extends Resource
class_name CodexEntry

@export var id: String = ''
@export var title: String = ''
@export var storyRequirements: Array[StoryRequirements] = []
@export_multiline var description: String = ''
@export var image: Texture2D = null
@export var childrenEntries: Array[CodexEntry] = []

func _init(
	i_id = '',
	i_title = '',
	i_storyRequirements: Array[StoryRequirements] = [],
	i_description = '',
	i_image: Texture2D = null,
	i_childrenEntries: Array[CodexEntry] = [],
):
	id = i_id
	title = i_title
	storyRequirements = i_storyRequirements
	description = i_description
	image = i_image
	childrenEntries = i_childrenEntries

func is_valid():
	var valid: bool = false
	
	for requirements in storyRequirements:
		valid = valid or requirements.is_valid()
	
	return valid or len(storyRequirements) == 0
