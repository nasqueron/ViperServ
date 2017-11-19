unbind dcc  n rehash		*dcc:rehash
  bind dcc  T rehash		 dcc:rehash
  bind dcc  T s                  dcc:source
unbind dcc  n tcl		*dcc:tcl
  bind dcc  T tcl		 dcc:tcl

  bind dcc  T sql		dcc:sql
  bind dcc  T sql?		dcc:sql?
  bind dcc  T sql!		dcc:sql!
  bind dcc  T sql1		dcc:sql1
  bind dcc  T sql1?		dcc:sql1?
  bind dcc  T sql1!		dcc:sql1!
  bind dcc  T sqlrehash		dcc:sqlrehash

  bind dcc  T tcldoc            dcc:tcldoc

  bind dcc  T env       dcc:env

#
# Helpers methods
#

#Logs a timestamped message to the specified file
proc log {logfile handle message} {
	global username
	set fd [open "logs/$username/$logfile.log" a]
	puts $fd "\[[unixtime]\] <$handle> $message"
	close $fd
}

#Prints a message to all the techs
proc putdebug {{message d41d8cd98f00b204e98}} {
	if {$message == "d41d8cd98f00b204e98"} {
		global errorInfo
		set message $errorInfo
	}
	foreach conn [dcclist CHAT] {
		foreach "idx handle uhost type flags idle" $conn {}
		#dccputchan 0 "(debug) $conn"
		if [matchattr $handle T] {
			putdcc $idx "\[DEBUG\] $message"
		}
	}
}

#
# Tech commands
#

#Disconnect SQL, then rehash (to prevent sql connect fatal errors)
proc dcc:rehash {handle idx arg} {
	catch {
		sql disconnect
		sql2 disconnect
	}
	*dcc:rehash $handle $idx $arg
}

#Loads a script
proc dcc:source {handle idx arg} {
	if {$arg == ""} {
		putdcc $idx "Usage: .s <script> [script2 ...]"
		return
	}
	foreach file $arg {
		if ![sourcetry $file] {
			putdcc $idx "Can't find script $file"
		}
	}
}

#Tries to load a script
proc sourcetry {file} {
	global username
	set scriptlist "$file $file.tcl scripts/$file scripts/$file.tcl scripts/$username/$file scripts/$username/$file.tcl"
	foreach script $scriptlist {
		if [file exists $script] {
			source $script
			return 1
		}
	}
	return 0
}

proc should_log_tcl_command {arg} {
	set noLogMatches {
		"*sql*connect*"
		"genpass *"
	}
	foreach noLogMatch $noLogMatches {
		if {[string match $noLogMatch $arg]} {
			return 0
		}
	}

	return 1
}

#.tcl with tech.log logging
proc dcc:tcl {handle idx arg} {
	#Logs every .tcl commands, except sql connect
	#You should add here any line with password.
	catch {
		if [should_log_tcl_command $arg] {
			log tech $handle $arg
		}
	}
	*dcc:tcl $handle $idx $arg
}

#
# SQL
#

#Reconnects to the MySQL main server (sql and sql2)
proc dcc:sqlrehash {handle idx arg} {
	sqlrehash
	return 1
}

#
# dcc:sql1 dcc:sql1? and dcc:sql1! are the main procedures
# They will be cloned for the 9 other connections command
#

#Executes a query
proc dcc:sql1 {handle idx arg} {
	if {$arg == ""} {
		putdcc $idx "Usage: .sql1 <query>"
		return
	}

	#Executes the query and prints the query one row per line
	set t1 [clock milliseconds]
	if [catch {
		foreach row [sql1 $arg] {
			putdcc $idx $row
		}
	} err] {
		putdcc $idx $err
	}

	#Warns after a long query
	set delta_t [expr [clock milliseconds] - $t1]
	if {$delta_t > 1999} {
		putcmdlog "Fin de la requête SQL ($delta_t ms)."
	}

	#Logs the query
	log sql $handle "sql1\t$arg"
}

#Dumps (SELECT * FROM <table>) a table
proc dcc:sql1! {handle idx arg} {
	if {$arg == ""} {
		putdcc $idx "Usage: .sql1! <table>"
		return
	}
	dcc:sql1 $handle $idx "SELECT * FROM $arg"
}

#Without parameters, list the tables (SHOW TABLES)
#With a parameter, dump tables info (SHOW CREATE TABLE)
proc dcc:sql1? {handle idx arg} {
	if {$arg == ""} {
		dcc:sql1 $handle $idx "SHOW TABLES"
	}
	foreach table $arg {
		dcc:sql1 $handle $idx "SHOW CREATE TABLE $table"
	}
}

#Clones .sql1, .sql1? and .sql1! commands into .sql, .sql? and .sql!
proc dcc:sql  {handle idx arg} [string map "sql1 sql" [info body dcc:sql1]]
proc dcc:sql? {handle idx arg} [string map "sql1 sql" [info body dcc:sql1?]]
proc dcc:sql! {handle idx arg} [string map "sql1 sql" [info body dcc:sql1!]]

proc sqlreplace {table {data1 ""} {data2 ""}} [string map {"INSERT INTO" "REPLACE INTO"} [info body sqladd]]

#Clones .sql1, .sql1? and .sql1! commands into .sql2, .sql3, ..., .sql10.
for {set i 2} {$i < 11} {incr i} {
	bind dcc T sql$i dcc:sql$i
	bind dcc T sql$i? dcc:sql$i?
	bind dcc T sql$i! dcc:sql$i!
	proc dcc:sql$i {handle idx arg} [string map "sql1 sql$i" [info body dcc:sql1]]
	proc dcc:sql$i! {handle idx arg} [string map "sql1 sql$i" [info body dcc:sql1!]]
	proc dcc:sql$i? {handle idx arg} [string map "sql1 sql$i" [info body dcc:sql1?]]
}

#
# Reference documentation
#

proc dcc:tcldoc {handle idx arg} {
	putdcc $idx [exec -- grep $arg doc/tcl-commands.doc]
	return 1
}

#
# UNIX environment
#

proc dcc:env {handle idx arg} {
    global env
    set environment [array get env]
    set keys [dict keys $environment]

    foreach "key value" $environment {
        putdcc $idx "[format %-[strlenmax $keys]s $key] $value"
    }
}
