class_name LogUtils

static var debug:bool:
	get:
		return OS.is_debug_build()

static var verbose:bool:
	get:
		return OS.is_debug_build() and OS.is_stdout_verbose()
