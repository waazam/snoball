extends CanvasLayer

signal start_pressed

# A random one-liner shown on the main menu each launch, just for fun -
# not tied to gameplay in any way.
const EASTER_EGGS := [
	"hey big brown!",
	"you smokin the reefer chiefer?",
	"better watch out",
	"better not cry",
	"how'd he see me?",
	"i'm ron burgundy?",
	"it's..... the stay puft marshmellow man...",
	"did you touch my drumset?",
	"DID YOU TOUCH IT?",
	"let's boo boo",
	"Yarp",
	"Narp",
	"A Bottle!?",
	"YOU'RE AN INANIMATE FUCKING OBJECT!",
	"Thats going overboard mate!!",
	"You honeydickin?",
	"no more rhymes i mean it",
	"anybody got a peanut?",
	"i thought hurricane season was over",
	"Stop! You've Violated the Law!",
	"I used to use this little gun when I was a prostitute",
	"i'm in danger",
	"I WAS IN THE POOL!",
	"he always smokes two smokes",
	"I ate 9 cans of ravioli",
	"Lim Jahey Express",
	"There Wolf........There Castle",
	"Take a look at what I'm wearing, people",
	"You're trash, Brock.",
	"I feel quite hungry",
	"Are you yanking my pizzle?",
	"He's Jersey, he skis in his jeans.",
	"Joyce?",
	"Where's the Tylenol?",
	"It's a beaut, Clark, it's a beaut",
	"Shitters Full!",
	"Grace?     She passed away 30 years ago",
]

func _ready() -> void:
	$Root/StartButton.pressed.connect(func(): emit_signal("start_pressed"))
	$Root/SnowballsButton.pressed.connect(func(): $SnowballMenu.open())
	$Root/QuitButton.pressed.connect(func(): get_tree().quit())
	$Root/EasterEgg.text = EASTER_EGGS[randi() % EASTER_EGGS.size()]
