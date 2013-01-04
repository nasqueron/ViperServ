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
# Dictionaries
#

# Gets recursively a value in a dictionary
#
# @param $dict the dictionary (without any dots in keys)
# @param $key the value's key; if dict are nested, succesive keys are separated by dots (e.g. change.owner.name)
# @return the dictionary value at the specified key
proc dg {dict key} {
	set keys [split $key .]
	if {[llength $keys] > 1} {
		# Recursive call
		# dg $dict a.b = dict get [dict get $dict a] b
		dg [dict get $dict [lindex $keys 0]] [join [lrange $keys 1 end] .]
	} {
		dict get $dict $key
	}
}

#
# Strings
#

#Completes $text by spaces or $char so the returned text length is $len
proc completestring {text len {char " "}} {
	set curlen [string length $text]
	if {$curlen >= $len} {
		return $text
	}
	if {[string length $char] < 2} {
		append text [string repeat $char [expr $len - $curlen]]
	} {
		while {[string length $text] < $len} {
			append text $char
		}
		string range $text 0 $len+1
	}
}

proc completestringright {text len {char " "}} {
	set curlen [string length $text]
	if {$curlen >= $len} {
		return $text
	}
	set completedtext [string range [completestring $text $len $char] $curlen end]
	append completedtext $text
}

## Prepends 0s to a number
##
## @param $number The number to zerofill
## @param $digits The number length
## @return The zerofilled number
proc zerofill {number digits} {
	format "%0${digits}d" $number
}

#
# SQL
#

#Reconnects to the sql & sql2 server
proc sqlrehash {} {
	global sql
	catch {
		sql  disconnect
		sql2 disconnect
	}
	sql  connect  $sql(host) $sql(user) $sql(pass)
	sql2 connect  $sql(host) $sql(user) $sql(pass)
	sql  selectdb $sql(database)
	sql2 selectdb $sql(database)
}

#Escape a string to use as sql query parameter
proc sqlescape {data} {
	#\ -> \\
	#' -> \'
	string map {"\\" "\\\\" "'" "\\'"} $data
	
}

#Gets the first item of the first row of a sql query (scalar results)
proc sqlscalar {sql} {
	lindex [lindex [sql $sql] 0] 0 
}

#Adds specified data to specified SQL table
proc sqladd {table {data1 ""} {data2 ""}} {
	if {$data1 == ""} {
		set fields ""
		#Prints field to fill
		foreach row [sql "SHOW COLUMNS FROM $table"] {
			lappend fields [lindex $row 0]
		}
		return $fields
	}

	if {$data2 == ""} {
		set sql "INSERT INTO $table VALUES ("
		set data $data1
	} {
		set sql "INSERT INTO $table (`[join $data1 "`, `"]`) VALUES ("
		set data $data2
	}
	set first 1
	foreach value $data {
		if {$first == 1} {set first 0} {append sql ", "}
		append sql "'[sqlescape $value]'"
	}
	append sql ")"
	sql $sql
}

# Gets the value of the AUTOINCREMENT column for the last INSERT
#
# @return the last value of the primary key
proc sqllastinsertid {} {
	sql "SELECT LAST_INSERT_ID()"
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
			set current [registry get $key]
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

#Gets user_id from a username, idx or user_id
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

#
# Text parsing
#

proc geturls {text} {
	#Finds the first url position
	set pos -1
	foreach needle "http:// https:// www. youtu.be" {
		set pos1 [string first $needle $text]
		if {$pos1 != -1 && ($pos == -1 || $pos1 < $pos)} {
			set pos $pos1
		}
	}

	#No URL found
	if {$pos == -1} {return}

	#URL found
	set pos2 [string first " " $text $pos]
	if {$pos2 == -1} {
		#Last URL to be found
		string range $text $pos end
	} {
		#Recursive call to get other URLs
		concat [string range $text $pos $pos2-1] [geturls [string range $text $pos2+1 end]]
	}
}

#Reads specified URL and returns content
proc geturltext {url {trim 1}} {
	package require http
	if {[string range [string tolower $url] 0 5] == "https:"} {
		package require tls
		http::register https 443 tls::socket
	}
	
	set fd [http::geturl $url]
	set text [http::data $fd]
	http::cleanup $fd
	if $trim {
		string trim $text
	} {
		return $text
	}
}

proc numeric2ordinal {n} {
	switch $n {
		 1 { return first }
		 2 { return second }
		 3 { return third }
		 5 { return fifth }
		 8 { return eight }
		 9 { return ninth }
		#todo: ve -> f / y -> ie
		12 { return twelfth }
		default {
			set ordinal "[numeric2en $n]th"
			set m [expr $n % 10]
			if {$m == 0} {
				return [string map "yth ieth" $ordinal]
			}
			if {$n < 20} { return $ordinal }
			if {$n > 100} { return "${n}th" }
			return "[numeric2en [expr $n - $m]]-[numeric2ordinal $m]"
		}
	}
}

proc numeric2en {n {optional 0}} {
    #---------------- English spelling for integer numbers
    if {[catch {set n [expr $n]}]}  {return $n}
    if {$optional && $n==0} {return ""}
    array set dic {
        0 zero 1 one 2 two 3 three 4 four 5 five 6 six 7 seven 
        8 eight 9 nine 10 ten 11 eleven 12 twelve
    }
    if [info exists dic($n)] {return $dic($n)}
    foreach {value word} {1000000 million 1000 thousand 100 hundred} {
        if {$n>=$value} {
            return "[numeric2en $n/$value] $word [numeric2en $n%$value 1]"
        }
    } ;#--------------- composing between 13 and 99...
    if $n>=20 {
        set res $dic([expr $n/10])ty
        if  $n%10 {append res -$dic([expr $n%10])}
    } else {
        set res $dic([expr $n-10])teen
    } ;#----------- fix over-regular compositions
    regsub "twoty" $res "twenty" res
    regsub "threet" $res "thirt" res
    regsub "fourty"  $res  "forty"  res
    regsub "fivet"  $res  "fift"  res
    regsub  "eightt"   $res  "eight" res
    set res
} ;#RS