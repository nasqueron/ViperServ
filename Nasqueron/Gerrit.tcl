# .tcl source scripts/Nasqueron/Gerrit.tcl

package require json

bind dcc - gerrit dcc:gerrit

# Gerrit eventss are at the bottom of the file

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
		if {[string first ssh-agent [get_processname $env(SSH_AGENT_PID)]] == -1} {
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

	proc get_processname {pid} {
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
			set type [dict get $event type]
			#todo: handle here multiservers
			callevent wmreview $type $event
		} {
			append buffers($idx) $text
		}
		return 0		
	}

	# Registers a new event
	#
	proc event {type callback} {
		dict lappend gerrit::events $type $callback
	}

	# Calls an event proc
	# 
	# @param $type the Gerrit type
	# @param $message a dict representation of the JSON message sent by Gerrit
	proc callevent {server type message} {
		if [dict exists $gerrit::events all] {
			foreach procname [dict get $gerrit::events all] {
				$procname $server $type $message
			}
		}

		if [dict exists $gerrit::events $type] {
			# Determines the proc arguments from the Gerrit message type
			switch $type {
				"patchset-created" { set params "change patchSet uploader" }
				"change-abandoned" { set params "change patchSet abandoner" }
				"change-restored" { set params "change patchSet restorer" }
				"change-merged" { set params "change patchSet submitter" }
				"comment-added" { set params "change patchSet author approvals comment" }
				"ref-updated" { set params "submitter refUpdate" }

				default {
					putdebug "Unknown Gerrit type in gerrit::callevent: $type"
					return
				}
			}

			# Gets the values of the proc arguments
			set args $server
			foreach param $params {
				if [dict exists $message $param] {
					lappend args [dict get $message $param]
				} {
					lappend args ""
				}
			}

			# Calls callbacks procs
			foreach procname [dict get $gerrit::events $type] {
				$procname {*}$args
			}
		}
	}

	# The events callback methods
	set events {}

	# # # # # # # # # # # # # # #

	# Handles statistics
	proc stats {server type message} {
		registry incr gerrit.stats.type.$type
	}

	# Announces a call
	proc debug {server type message} {
		putdebug "$server -> $type +1"
	}

	proc onNewPatchset {server change patchset uploader} {
		# Gets relevant variables from change, patchset & uploader
		set who [dict get $uploader name]
		foreach var "project branch topic subject url" {
			if [dict exists $change $var] {
				set $var [dict get $change $var]
			} {
				set $var ""
			}
		}
		set patchsetNumber [dict get $patchset number]

		#IRC notification
		if {$server == "wmreview" && $who != "L10n-bot"} {
			set message "\[$project] $who uploaded a [numeric2ordinal $patchsetNumber] patchset to change '$subject'"
			if {$branch != "master"} { append message " in branch $branch" }
			append message " - $url"
		}
		#if {[string range $project 0 9] == "mediawiki/"} {
		#	puthelp "PRIVMSG #mediawiki :$message"
		#}
	}

	proc onCommentAdded {server change patchset author approvals comment} {
		# Gets relevant variables from change, patchset & uploader
		set who [dict get $author name]
		foreach var "project branch topic subject url" {
			if [dict exists $change $var] {
				set $var [dict get $change $var]
			} {
				set $var ""
			}
		}

		#IRC notification
		if {$server == "wmreview" && $who != "jenkins-bot"} {
			set verbs {
				"\0034puts a veto on\003"
				"\0034suggests improvement on\003"
				"comments"
				"\0033approves\003"
				"\0033definitely approves\003"
			}
			set CR 0
			if {$approvals != ""} {
				foreach approval $approvals {
					if {[dict get $approval type] == "CRVW"} {
						set CR [dict get $approval value]
						break
					}
				}
			}
			set verb [lindex $verbs [expr $CR + 2]]
			set message "\[$project] $who $verb change '$subject'"
			if {$comment != ""} {
				if {[strlen $message] > 160} {
					append message ": '[string range $comment 0 158]...'"
				} {
					append message ": '$comment'"
				}
			}
			append message " - $url"
			if {[string range $project 0 9] == "mediawiki/" && ($comment != "" || $CR < 0)} {
				#putdebug "OK -> $message"
				puthelp "PRIVMSG #mediawiki :$message"
			} {
				putdebug "Not on IRC -> $message"
			}
		}
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

gerrit::event all gerrit::stats
gerrit::event all gerrit::debug
gerrit::event patchset-created gerrit::onNewPatchset
gerrit::event comment-added gerrit::onCommentAdded
