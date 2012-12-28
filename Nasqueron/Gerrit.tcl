# .tcl source scripts/Nasqueron/Gerrit.tcl

bind dcc - gerrit dcc:gerrit

#
# Gerrit helper methods
#

namespace eval ::ssh:: {
	proc set_agent {{tryToStartAgent 1}} {
		global env
		set file $env(HOME)/bin/ssh-agent-session
		
		if {![file exists $file]} {
			putcmdlog "Can't find SSH agent information - $file doesn't exist."
		}

		#TCSH rules -> set through env array
		set fp [open $file]
		fconfigure $fp -buffering line
		gets $fp line
		while {$line != ""} {
			foreach "command variable value" [split $line] {}
			if {$command == "setenv"} {
				set env($variable) [string range $value 0 end-1]
			}
			gets $fp line
		}
		close $fp

		#Checks if agent exists
		if {[string first ssh-agent [get_pid $env(SSH_AGENT_PID)]] == -1} {
			putcmdlog "SSH agent isn't running"
			if {$tryToStartAgent} {
				putdebug "Trying to launch SSH agent..."
				exec -- ssh-agent -c | grep -v echo > $env(HOME)/bin/ssh-agent-session
				if {![add_key]} {
					# TODO: send a note to relevant people key should manually added
					# something like sendNoteToGroup $username T "Key sould be manually added"
				}
				set_agent 0
			}
		}
	}

	proc add_key {{key ""}} {
		if {$key == ""} { set key [registry get ssh.key] }
		if {$key != ""} {
			catch { exec -- ssh-add $key } result
			putdebug "Adding SSH key: $result"
			expr [string first "Identity added" $result] > -1
		} {
			return 0
		}

	}

	proc get_pid {pid} {
		set processes [exec ps xw]
		foreach process [split $processes \n] {
			set current_pid [lindex $process 0]
			set command [lrange $process 4 end]
			if {$pid == $current_pid} { return $command }
		}
	}

	# Gets appropriate connection parameter
	#
	# @param $server The server to connect
	# @return The server domain name, prepent by SSH options
	proc get_connection_parameter {server} {
		#TODO: return -p 29418 username@review.anothersite.com when appropriate instead to create SSH config alias
		return $server
	}
}

namespace eval ::gerrit:: {
	## Queries a Gerrit server
	##
	## @param $query The query to send
	## @seealso http://gerrit-documentation.googlecode.com/svn/Documentation/2.5/cmd-query.html
	proc query {server query} {
		exec -- ssh [ssh::get_connection_parameter $server] gerrit query $query
	}

	## Launches a socket to monitor Gerrit events in real time and initializes events.
	## This uses a node gateway.
	##
	## @seealso http://gerrit-documentation.googlecode.com/svn/Documentation/2.5/cmd-stream-events.html
	proc setup_stream_events {server} {
		control [connect [registry get gerrit.$server.streamevents.host] [registry get gerrit.$server.streamevents.port]] gerrit::listen:stream_event
	}

	proc listen:stream_event {idx text} {
		global buffers

		if {$text == ""} {
			putdebug "Connection to Gerrit stream-events gateway closed."
			if [info exists buffers($idx)] { unset buffers($idx) }
		} elseif {$text == "--"} {
			# Process gerrit event
			set event [json::json2dict $buffers($idx)]
			set buffers($idx) ""
			registry incr gerrit.stats.type.[dict get $event type]
		} {
			append buffers($idx) $text
		}
		return 0		
	}
}

#
# Gerrit binds
# 

proc dcc:gerrit {handle idx arg} {
	switch $arg {
		"" {
			putdcc $idx "Usage: .gerrit <query>"
			putdcc $idx "Cmds:  .gerrit stats"
			return 0
		}

		"stats" {
			foreach row [sql "SELECT SUBSTRING(data, 19), value FROM registry WHERE LEFT(data, 18) = 'gerrit.stats.type.'"] {
				putdcc $idx $row
			}
			return 1
		}

		default {
			# TODO: support several Gerrit servers
			set server [registry get gerrit.defaultserver]
			putdcc $idx [gerrit::query $server $arg]
			putcmdlog "#$handle# gerrit ..."
			return 0
		}
	}
}

#
# Initialization code
#

ssh::set_agent