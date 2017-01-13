# Procs to mock
proc bind {type flags cmdOrMask {procName ""}} {}
proc unbind {type flags cmdOrMask procname} {}

# Tests config
set dir [info script]
if {$dir == ""} {
	set dir [pwd]
	append dir "/scripts"
} {
	set dir [file dirname [file dirname [file normalize $dir]]]
}

# Standard procedures
source $dir/Core.tcl

# Eggdrop procedures
proc strlen {text} {
	string length $text
}
