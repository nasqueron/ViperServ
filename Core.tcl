#
# TCL helpers
#

#Determines if $proc exists
proc proc_exists {proc} {
	expr {[info procs $proc] == $proc}
}

#
# Trivial procs
#

#Determines if $v is a number
proc isnumber {v} {
    return [expr {! [catch {expr {int($v)}}]}]
}

#
# MySQL
#
#Gets the value of the key $key from the registry 
proc registry_get {key} {
	sql "SELECT value FROM registry WHERE `key` = '$key'" 
}

#Sets the key $key to $value in the registry
proc registry_set {key value} {
}

#
# Users information
#
proc getuserid {data} {
	if {$data == ""} {
		return
	} elseif {![isnumber $data]} {
		#username -> user_id
		sql "SELECT user_id FROM users WHERE username = '[sqlescape $data]'"
	} elseif {$data < 1000} {
		#idx -> user_id
		getuserid [idx2hand $data]
	} else {
		#user_id -> user_id (or "" if not existing)
		sql "SELECT user_id FROM users WHERE user_id = $data"
	}
}
