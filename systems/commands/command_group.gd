class_name CommandGroup
extends Command

enum Mode { SEQUENTIAL, PARALLEL }

@export var mode: Mode = Mode.SEQUENTIAL

var _commands: Array[Command] = []
var _current_index: int = 0
var _active_commands: Array[Command] = []  # used in parallel mode

func add(command: Command) -> CommandGroup:
	_commands.append(command)
	# Inherit requirements from children
	for req in command.required:
		if req not in required:
			required.append(req)
	return self

func on_start() -> void:
	_current_index = 0
	_active_commands = []
	if mode == Mode.SEQUENTIAL:
		if _commands.size() > 0:
			_commands[0].robot = robot
			_commands[0].on_start()
	else:
		for cmd in _commands:
			cmd.robot = robot
			cmd.on_start()
			_active_commands.append(cmd)

func on_update(delta: float) -> void:
	if mode == Mode.SEQUENTIAL:
		if _current_index >= _commands.size():
			return
		var current = _commands[_current_index]
		current.on_update(delta)
		if current.is_finished():
			current.on_end(false)
			_current_index += 1
			if _current_index < _commands.size():
				_commands[_current_index].robot = robot
				_commands[_current_index].on_start()
	else:
		for cmd in _active_commands:
			cmd.on_update(delta)
		_active_commands = _active_commands.filter(func(cmd):
			if cmd.is_finished():
				cmd.on_end(false)
				return false
			return true
		)

func is_finished() -> bool:
	if mode == Mode.SEQUENTIAL:
		return _current_index >= _commands.size()
	else:
		return _active_commands.is_empty()
