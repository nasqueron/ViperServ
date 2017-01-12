namespace eval broker {
	proc init {} {
		# Loads our librabbitmq wrapper extension
		if {![is_package_present rabbitmq]} {
			load ../rabbitmq.so
		}

		# Connects to the broker
		if {![mq connected]} {
			connect
		}

		# Starts timer
		if {![is_timer_started]} {
			start_timer
		}
	}

	proc connect {} {
		mq connect [registry get broker.host] [registry get broker.user] [registry get broker.password] [registry get broker.vhost]
	}

	proc is_timer_started {} {
		expr [string first ::broker::on_tick [utimers]] > -1
	}

	proc start_timer {} {
		utimer 4 [namespace current]::on_tick
	}

	# Determines if we're in a risk to receive a SIGCHLD while the broker intercepts signals
	#
	# @param time The specified unixtime, or the current one if omitted
	# @return 1 if the risk is there, 0 if it shouldn't be risky
	proc near_SIGCHLD_arrival {{time ""}} {
		if {$time == ""} {
			set time [clock seconds]
		}
		set timePosition [expr $time % 300]
		expr $timePosition == 0 || $timePosition == 299
	}

	proc on_tick {} {
		if {![near_SIGCHLD_arrival]} {
			# We generally want to get messages, but not
			# when the SIGCHLD signal is sent to the bot
			# which seems to be every five minutes.

			get_messages
		}
		utimer 1 [namespace current]::on_tick
	}

	proc get_messages {} {
		foreach queue [registry get broker.queues] {
			while 1 {
				if {[catch {set message [mq get $queue -noack]} brokerError]} {
					if {[recover_from_broker_error $brokerError]} {
						continue	
					} {
						error $brokerError
					}
				}
				if {$message == ""} {
					break
				} {
					on_message $queue $message
				}
			}
		}
	}

	# Tries to recover from broker error and determines if we could continue
	#
	# @param error The error message.
	# @return 1 if we can continue to process messages, 0 if we should throw an error
	proc recover_from_broker_error {error} {
		if {$error == "Child process signal received."} {
			putdebug "Ignoring SIGCHLD"
		} elseif {[string match "*server connection error 320*CONNECTION_FORCED*" $error]} {
			# If the session doesn't allow the bot to process
			# messages, we can ask the server to disconnect it.
			# Log the error message, as management plugin
			# allows to send a custom reason.
			putdebug "$error / Trying to reconnect..."
			connect
		} elseif {$error == "Not connected."} {
			connect
		} else {
			return 0
		}

		return 1
	}

	proc bind {queue callback} {
		global brokerbinds
		set entry [list $queue $callback]

		if {[info exists brokerbinds]} {
			foreach bind $brokerbinds {
				if {$bind == $entry} {
					# Bind is already here
					return
				}
			}
		}

		lappend brokerbinds $entry
	}

	proc binds {} {
		global brokerbinds

		if {[info exists brokerbinds]} {
			return $brokerbinds
		}

		return ""
	}

	# Triggered when a message comes to the broker to dispatch it to bound procs
	proc on_message {queue message} {
		set propagated 0
		foreach bind [binds] {
			foreach "bindQueue callback" $bind {}
			if {[string match $bindQueue $queue]} {
				$callback $queue $message
				incr propagated
			}
		}
		if {$propagated == 0} {
			putdebug "<$queue> [string range $message 0 32]..."
		}
	}
}
