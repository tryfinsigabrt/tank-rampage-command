class_name CircularBuffer

var _data: Array	
var _current_index:int
		
var capacity:int:
	get:
		return capacity
		
var _wrapped:bool

func _init(in_capacity:int) -> void:
	_current_index = -1
	capacity = in_capacity
	_data.resize(capacity)

func contains(value:Variant) -> bool:
	if _wrapped:
		return value in _data
	
	for i in _current_index + 1:
		if _data[i] == value:
			return true
	return false
	
func add(value:Variant) -> void:
	var prev := _current_index
	_current_index = _get_next_index()
	if _current_index < prev:
		_wrapped = true
		
	_data[_current_index] = value	

func clear() -> void:
	_current_index = -1
	_wrapped = false

func for_each(receiver:Callable) -> void:
	if _current_index < 0:
		return
	# If we haven't wrapped or special case where first and last are the whole array in sequence
	if not _wrapped or _current_index == capacity - 1:
		for i in _current_index + 1:
			receiver.call(_data[i])
	else:
		var last_index:int = _current_index
		var first_index:int = _get_next_index()
		
		for i in range(first_index, capacity):
			receiver.call(_data[i])
		for i in range(0, last_index + 1):
			receiver.call(_data[i])

func _get_next_index() -> int:
	return wrapi(_current_index + 1, 0, capacity)

func is_empty() -> bool:
	return _current_index < 0
	
func first() -> Variant:
	var first_index:int = _get_next_index()
	return _data[first_index]
	
func last() -> Variant:
	return _data[_current_index]
