extends RefCounted

# Simple queue implementation wrapper around Godot "Array" class
class_name Queue

var queue: Array[Variant]
var capacity: int
var size: int

var front: int
var back: int

func _init(_cap: int):
	queue = []
	queue.resize(_cap)
	
	capacity = _cap
	size = 0
	front = 0
	back = capacity - 1
	
func enqueue(item: Variant) -> void:
	if is_full():
		push_error('Cannot push an element to a full queue.')
		return
	
	back = (back + 1) % capacity
	queue[back] = item
	size += 1
	print("Pushed item to the queue !")

func dequeue() -> Variant:
	if is_empty():
		push_error('Cannot pop an element from an empty queue')
		return
	
	print("Popping item from the queue.")
	var item: Variant = queue[front]
	front = (front + 1) % capacity
	size -= 1
	return item
	
func last() -> Variant:
	return queue[back]

func first() -> Variant:
	return queue[front]
	
func is_full() -> bool:
	return size == capacity
	
func is_empty() -> bool:
	return size == 0
