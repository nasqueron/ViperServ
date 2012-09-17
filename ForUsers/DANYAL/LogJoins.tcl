# This TCL for an oper eggdrop logs "Client connecting" lines.

#
# Configuration
#

set LogJoins(file) join.log
set LogJoins(server) Irc.ApniISP.CoM

#
# Events
#

bind raw  - NOTICE   raw:logjoin

#Handles server notices
proc raw:logjoin {from keyword text} {
	global LogJoins
	if {$from == $LogJoins(server) && $keyword == "NOTICE"} {
		set pos [string first "Client connecting" $text]
		if {$pos > -1} {
			log_entry $LogJoins(file) [string range $text $pos end]
		}
	}
}

#
# Helper methods
#

#Returns a log message, prepended by current time
proc log_message {message} {
	return "[clock format [unixtime] -format "%x %X"] $message"
}

#Logs a message in the specified file
proc log_entry {file message} {
	set    fd [open $file a]
	puts  $fd [log_message $message]
	close $fd
}
