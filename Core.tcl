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

#Returns "s" if $count implies a plural
#TODO: keep this method for French (ie NOT adjusting values for English)
#      and grab the plural proc from wiki.tcl.tk for English.
proc s {count} {
	if {$count >= 2 || $count <= 2} {return "s"}
}

#
# Registry
#

#Gets, sets, deletes or increments a registry value 
proc registry {command key {value ""}} {
	switch -- $command {
		"add" {
			sqladd registry "data value" [list $key $value]
		}

		"get" {
			sqlscalar "SELECT value FROM registry WHERE `data` = '$key'" 
		}

		"set" {
			sqlreplace registry "data value" [list $key $value]
		}

		"del" {
			registry delete $key $value
		}

		"delete" {
			set sql "DELETE FROM registry WHERE `data` = '$key'"
			putdebug $sql
			sql $sql
		}

		"incr" {
			set current [registy get $key]
			if {$value == ""} {set term 1}
			if {$current == ""} {
				registry set $key $term
			} {
				registry set $key [incr current $term]
			}
		}

		default {
			error "unknown subcommand: must be add, get, set, incr or delete"
		}
	}
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
