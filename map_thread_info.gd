extends RefCounted

class_name MapThreadInfo

var callback: Callable
var arg: Variant

func _init(_callback: Callable, _arg: Variant):
	callback = _callback
	arg = _arg
