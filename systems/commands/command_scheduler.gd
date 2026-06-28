extends Node

## Maps Subsystem -> currently running Command that requires it
var _subsystem_commands: Dictionary = {}
## All currently running commands
var _running: Array[Command] = []
## Registered managers (one per robot)
var _managers: Array[SubsystemManager] = []

func register_manager(manager: SubsystemManager) -> void:
	_managers.append(manager)

func schedule(command: Command, robot: Node = null) -> void:
	command.robot = robot

	# Cancel any conflicting commands first
	for req in command.required:
		if _subsystem_commands.has(req):
			cancel(_subsystem_commands[req])

	command.on_start()
	_running.append(command)
	for req in command.required:
		_subsystem_commands[req] = command

func cancel(command: Command) -> void:
	if command in _running:
		command.on_end(true)
		_running.erase(command)
		for req in command.required:
			if _subsystem_commands.get(req) == command:
				_subsystem_commands.erase(req)

func _physics_process(delta: float) -> void:
	# Tick all robot subsystems
	for manager in _managers:
		manager.tick(delta)

	# Run commands
	var finished: Array[Command] = []
	for cmd in _running:
		cmd.on_update(delta)
		if cmd.is_finished():
			finished.append(cmd)

	for cmd in finished:
		cmd.on_end(false)
		_running.erase(cmd)
		for req in cmd.required:
			if _subsystem_commands.get(req) == cmd:
				_subsystem_commands.erase(req)
