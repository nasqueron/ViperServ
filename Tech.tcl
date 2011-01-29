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
proc putdebug {message} {
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

#.tcl with tech.log logging
proc dcc:tcl {handle idx arg} {
	catch {log tech $handle $arg}
	*dcc:tcl $handle $idx $arg
}

#
# SQL
#

#TODO: move to Core.tcl
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

proc sqlescape {data} {
	#\ -> \\
	#' -> \'
	string map {"\\" "\\\\" "'" "\\'"} $data
	
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
