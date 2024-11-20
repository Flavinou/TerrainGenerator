extends RefCounted

class_name ThreadOperation

var callback: Callable
var arg: Variant

func _init(_callback: Callable, _arg: Variant = null):
	callback = _callback
	arg = _arg
