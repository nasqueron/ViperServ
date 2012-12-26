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
}

namespace eval ::gerrit:: {
	## Queries a Gerrit server
	proc query {query} {
		exec ssh wmreview gerrit query $query
	}
}

#
# Gerrit binds
# 

proc dcc:gerrit {handle idx arg} {
	if {$arg == ""} {
		putdcc $idx "Usage: .gerrit <query>"
		return 0
	}

	# TODO: support several Gerrit servers
	putdcc $idx [gerrit::query $arg]
	return 1
}

#
# Initialization code
#

ssh::set_agent