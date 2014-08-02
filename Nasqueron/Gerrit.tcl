# .tcl source scripts/Nasqueron/Gerrit.tcl

package require json

bind dcc - gerrit dcc:gerrit

# Gerrit events are at the bottom of the file

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
	## @param $server The Gerrit server
	## @param $query The query to send
	## @seealso http://gerrit-documentation.googlecode.com/svn/Documentation/2.5/cmd-query.html
	proc query {server query} {
		exec -- ssh [ssh::get_connection_parameter $server] gerrit query $query
	}

	## Queries a Gerrit server, searching changes with an expression
	##
	## @param $server The Gerrit server
	## @param $project The project
	## @param $query The query
	proc search {server project query} {
		set query "message:$query"
		if {$project != "*" } {
			append query " project:$project"
		}
		set results ""
		putdebug $query
		foreach line [split [query $server "--format json $query"] "\n"] {
			set c [json::json2dict $line]
			if {![dict exists $c type]} {
				lappend results "\[[dg $c project]\] <[dg $c owner.name]> [dg $c subject] ([status [dg $c status]]) - [dg $c number]"
			}
		}
		return $results
	}

	# Gets the approvals for a specified change
	proc approvals {server change} {
		set change [query $server "--format JSON --all-approvals $change"]
		#We exploit here a bug: parsing stops after correct item closure, so \n new json message is ignored
		set change [json::json2dict $change]
		set lastPatchset [lindex [dg $change patchSets] end]
		dg $lastPatchset approvals
	}

	proc approvals2xml {approvals {indentLevel 0} {ignoreSubmit 1}} {
		set indent [string repeat "\t" $indentLevel]
		append xml "$indent<approvals>\n"
		foreach approval $approvals {
			set type [dg $approval type]
			if {$type == "SUBM" && $ignoreSubmit} { continue }
			append xml "$indent\t<approval type=\"$type\">
		$indent<user email=\"[dg $approval by.email]\">[dg $approval by.name]</user>
		$indent<date>[dg $approval grantedOn]</date>
		$indent<value>[numberSign [dg $approval value]]</value>
	$indent</approval>\n"
		}
		append xml "$indent</approvals>"
	}

	# Gets a string representation of the API status
	#
	# @param $status the API status string code
	# @return the textual representation of the status
	proc status {status} {
		switch $status {
			"NEW" { return "Review in progress" }
			default { return $status }
		}
	}

	## Launches a socket to monitor Gerrit events in real time and initializes events.
	## This uses a node gateway.
	##
	## @seealso http://gerrit-documentation.googlecode.com/svn/Documentation/2.5/cmd-stream-events.html
	proc setup_stream_events {server} {
		set idx [connect [registry get gerrit.$server.streamevents.host] [registry get gerrit.$server.streamevents.port]]
		control $idx gerrit::listen:stream_event
	}

	# Listens to a Gerrit stream event
	#
	# @param $idx The connection idx
	# @param $text The message received
	# @return 0 if we continue to control this connection; otherwise, 1
	proc listen:stream_event {idx text} {
		# To ensure  a better system stability, we don't directly handle
		# a processus  calling the 'ssh' command,  but use a lightweight
		# non blocking socket connection:
		# 
		# This  script <--socket--> Node  proxy <--SSH--> Gerrit  server
		# 
		# We receive line of texts from the proxy. There are chunks of a
		# JSON message (we convert it to a dictionary, to be used here).
		# 
		# As the json objects are rather long, it is generally truncated
		# in several lines. Immediately after, a line with "--" is sent:
		#
		#   1.  {"type":"comment-added","change":......................
		#   2.  ................,"comment":"Dark could be the night."}
		#   3.  --
		#   4.  {"type":"patchset-created",...........................}
		#   5.  --
		#   6.  ........
		#
		# Text is stored in a global array,  shared with others control
		# procs, called $buffers. The message is to add in the idx key.
		# It should be cleared after, as the idx could be reassigned.
		#
		# When a message is received, we sent the decoded json message
		# to gerrit::callevent, which has the job to fire events and
		# to call event callback procedures.
		
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
			if { [catch { callevent wmreview $type $event } err] } {
				global errorInfo
				putdebug "A general error occured during the Gerrit event processing."
				putdebug $errorInfo
			}
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
		# Gerrit events could be from two types:
		#
		#    (1) Generic events
		#    ------------------
		#        They are created with "gerrit::event all callbackproc".
		#        The callback procedure args are server, type & message.
		#
		#        Every Gerrit event is sent to them.
		#
		#    (2) Specific events
		#    -------------------
		#        Similar create way:  "gerrit::event type callbackproc".
		#
		#        Only Gerrit events of matching type are sent to them.
		#        The callback procedure arguments varie with the type.
		#
		#        patchset-created ... server change patchSet uploader
		#        change-abandoned ... server change patchSet abandoner reason 
		#        change-restored .... server change patchSet restorer
		#        change-merged ...... server change patchSet submitter
		#        comment-added ...... server change patchSet author approvals comment
		#        ref-updated ........ server submitter refUpdate
		#
		# The documentation of these structures can be found at this URL:
		# http://gerrit-documentation.googlecode.com/svn/Documentation/2.5.1/json.html
		#	
		# The callback procedures are all stored in the global ditionary
		# $gerrit::events.
		#
		# Generic events are fired before specific ones. They can't edit
		# the message. They can't say "no more processing".
		#

		if [dict exists $gerrit::events all] {
			foreach procname [dict get $gerrit::events all] {
				if [catch {$procname $server $type $message} err] {
					putdebug "An error occured in $procname (called by a $type event):"
					global errorInfo
					putdebug $errorInfo
					putdebug $message
				}
			}
		}

		if [dict exists $gerrit::events $type] {
			# Determines the proc arguments from the Gerrit message type
			switch $type {
				"patchset-created" { set params "change patchSet uploader" }
				"change-abandoned" { set params "change patchSet abandoner reason" }
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
				if [catch {$procname {*}$args} err] {
					global errorInfo
					putdebug "An error occured in $procname (called by a $type event):"
					putdebug $errorInfo
					putdebug $message
				}
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
		foreach var "project branch topic subject url topic id" {
			set $var [dg $change $var]
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

			# Activity feed
			set email [dict get $uploader email]
			set item "	<item type=\"patchset\">
		<date>[unixtime]</date>
		<user email=\"$email\">$who</user>
		<project>$project</project>
		<branch>$branch</branch>
		<topic>$topic</topic>
		<change id=\"$id\">[xmlescape $subject]</change>
	</item>"
			writeActivityFeeds $email $project $item
	}

	proc onChangeAbandoned {server change patchSet abandoner reason} {
                if {$server == "wmreview"} {
			foreach var "id project branch topic subject" { set $var [dg $change $var] }
			set itemBase "
		<date>[unixtime]</date>
		<user email=\"[dg $abandoner email]\">[dg $abandoner name]</user>
		<project>$project</project>
		<branch>$branch</branch>
		<topic>$topic</topic>
		<change id=\"$id\">[xmlescape $subject]</change>
		<message>$reason</message>"
			set item "\t<item type=\"abandon\">$itemBase\n\t</item>"
			set itemMerged "\t<item type=\"abandoned\">\n\t\t<owner email=\"[dg $change owner.email]\">[dg $change owner.name]</owner>$itemBase\n\t</item>"

			set dir [registry get gerrit.feeds.path]
			writeActivityFeed $dir/user/[guidmd5 [dg $abandoner email]].xml $item
			if {[dg $change owner.email] != [dg $abandoner email]} {
				writeActivityFeed $dir/user/[guidmd5 [dg $change owner.email]].xml $itemMerged
			}
			writeActivityFeed $dir/project/[string map {/ . - _} $project].xml $itemMerged
		}
	}

	proc onCommentAdded {server change patchset author approvals comment} {
		# Gets relevant variables from change, patchset & uploader
		set who [dict get $author name]
		foreach var "project branch topic subject url id status" {
			if [dict exists $change $var] {
				set $var [dict get $change $var]
			} {
				set $var ""
			}
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

		#Wikimedia: IRC notification, activity feed
		if {$server == "wmreview" && $who != "jenkins-bot"} {
			# English message
			set verbs {
				"\0034puts a veto on\003"
				"\0034suggests improvement on\003"
				"comments"
				"\0033approves\003"
				"\0033definitely approves\003"
			}
			set verb [lindex $verbs [expr $CR + 2]]
			regexp "\[a-z\\s\]+" $verb plainVerb
			set message "\[$project] $who $verb change '$subject'"
			if {$comment != ""} {
				if {[strlen $message] > 160} {
					append message ": '[string range $comment 0 158]...'"
				} {
					append message ": '$comment'"
				}
			}
			append message " - $url"

			# IRC notification
			if 0 {
				if {[string range $project 0 9] == "mediawiki/" && ($comment != "" || $CR < 0)} {
					puthelp "PRIVMSG #mediawiki :$message"
				} {
					putdebug "Not on IRC -> $message"
				}
			}

			# Activity feed
			set message [string map [list $verb $plainVerb] $message]
			set email [dict get $author email]
			set item "	<item type=\"comment\">
		<date>[unixtime]</date>
		<user email=\"$email\">$who</user>
		<project>$project</project>
		<change id=\"$id\">[xmlescape $subject]</change>
		<message cr=\"$CR\">[xmlescape $comment]</message>
	</item>"
			writeActivityFeeds $email $project $item
		}
	}

	# Called when a Gerrit change ismerged
	proc onChangeMerged {server change patchSet submitter} {
                if {$server == "wmreview" && [dg $submitter name] != "L10n-bot"} {
			foreach var "id project branch topic subject" { set $var [dg $change $var] }
			set itemBase "
		<date>[unixtime]</date>
		<user email=\"[dg $submitter email]\">[dg $submitter name]</user>
		<project>$project</project>
		<branch>$branch</branch>
		<topic>$topic</topic>
		<change id=\"$id\">[xmlescape $subject]</change>\n"
			set approvals [approvals $server $id]
			append itemBase [gerrit::approvals2xml $approvals 2 1]
			set item "\t<item type=\"merge\">$itemBase\n\t</item>"
			set itemMerged "\t<item type=\"merged\">\n\t\t<owner email=\"[dg $change owner.email]\">[dg $change owner.name]</owner>$itemBase\n\t</item>"

			set dir [registry get gerrit.feeds.path]
			writeActivityFeed $dir/user/[guidmd5 [dg $submitter email]].xml $item
			if {[dg $change owner.email] != [dg $submitter email]} {
				writeActivityFeed $dir/user/[guidmd5 [dg $change owner.email]].xml $itemMerged
			}
			writeActivityFeed $dir/project/[string map {/ . - _} $project].xml $itemMerged
			#TODO: OPW
		}
	}

	# Writes an activity feed item to the relevant feeds
	# 
	# @param $who The user e-mail
	# @param $project The project
	# @param $item The XML item
	proc writeActivityFeeds {who project item} {
		set dir [registry get gerrit.feeds.path]
		writeActivityFeed $dir/user/[guidmd5 $who].xml $item
		writeActivityFeed $dir/project/[string map {/ . - _} $project].xml $item
		#TODO: opw feed
	}

	# Writes an activity feed item to the specifief file
	# 
	# @param $file The output file
	# @param $item The XML item
	proc writeActivityFeed {file item} {
		if ![file exists $file] {
			set fd [open $file w]
			puts $fd "<items>"
			puts $fd $item
			puts $fd "</items>"
		} {
			set fd [open $file {RDWR CREAT}]
			set header [read $fd 4096]
			set startFound 0
			set pos [string first "<items" $header]
			if {$pos > -1} {
				set pos [string first ">" $header $pos]
				if {$pos > -1} {
					set startFound 1
					incr pos
				}
			}
			if $startFound {
				# Appends <item> block after <items>
				# Prepare our file in a temporary $fdtmp
				set fdtmp [file tempfile]
				seek $fd 0 start
				puts $fdtmp [read $fd $pos]
				puts -nonewline $fdtmp $item
				puts -nonewline $fdtmp [read $fd]
				flush $fdtmp
				seek $fdtmp 0 start
				seek $fd 0 start
				puts $fd [string trim [read $fdtmp]]
				close $fdtmp
			} {
				# Adds a comment at the end of the file
				seek $fd 0 end
				puts $fd "<!-- Can't find <items> / added at [unixtime]:"
				puts $fd $item
				puts $fd "-->"
			}
		}
		flush $fd
		close $fd

	}
}

#
# Gerrit binds
# 

# .gerrit query
# .gerrit stats
# .gerrit search <project> <query to searh in commit message>
proc dcc:gerrit {handle idx arg} {
	set server [registry get gerrit.defaultserver]

	switch [lindex $arg 0] {
		"" {
			putdcc $idx "Usage: .gerrit <query>"
			putdcc $idx "Cmds:  .gerrit stats"
			putdcc $idx "Cmds:  .gerrit search <project> <query to searh in commit message>"
			return 0
		}

		"stats" {
			foreach row [sql "SELECT SUBSTRING(data, 19), value FROM registry WHERE LEFT(data, 18) = 'gerrit.stats.type.'"] {
				putdcc $idx $row
			}
			return 1
		}

		"search" {
			set nbResults 0
			set project [lindex $arg 1]
			set query [lrange $arg 2 end]
			foreach result [gerrit::search $server $project $query] {
				putdcc $idx $result
				incr nbResults
			}
			if {$nbResults == 0} {
				putdcc $idx ":/"
			} {
				putcmdlog "#$handle# gerrit search ..."
			}
			return 0
		}

		default {
			# TODO: support several Gerrit servers
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
#gerrit::event all gerrit::debug
gerrit::event patchset-created gerrit::onNewPatchset
gerrit::event comment-added gerrit::onCommentAdded
gerrit::event change-merged gerrit::onChangeMerged
gerrit::event change-abandoned gerrit::onChangeAbandoned
