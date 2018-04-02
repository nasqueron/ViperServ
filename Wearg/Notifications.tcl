package require json

bind time - "30 *" ::notifications::channel_notify_periodics

namespace eval notifications {
	proc init {} {
		::broker::bind [registry get broker.queue.notifications] ::notifications::on_broker_message

		bind * * * * ::notifications::channel_notify
		bind "DockerHub" * * * ::notifications::docker_build_summary
	}

	proc bind {service project group type callback} {
		global notificationsbinds
		set entry [list $service $project $group $type $callback]

		if {[info exists notificationsbinds]} {
			foreach bind $notificationsbinds {
				if {$bind == $entry} {
					# Bind is already here
					return
				}
			}
		}

		lappend notificationsbinds $entry
	}

	proc binds {} {
		global notificationsbinds

		if {[info exists notificationsbinds]} {
			return $notificationsbinds
		}

		return ""
	}

	proc is_matching_notification_bind {bind notification} {
		set bindFields "service project group type callback"

		# We want to ensure the first four bind fields match the values of the notification dictionary
		foreach $bindFields $bind {}
		set fields [lrange $bindFields 0 end-1]
		foreach field $fields {
			if {![string match [set $field] [dict get $notification $field]]} {
				return 0
			}
		}

		return 1
	}

	proc on_broker_message {queue message} {
		set notification [json::json2dict $message]
		set message [dict get $notification text]

		foreach field "service project group rawContent type text link" {
			lappend params [dict get $notification $field]
		}

		set matchingBinds 0
		foreach bind [binds] {
			if {[is_matching_notification_bind $bind $notification]} {
				set callback [lindex $bind 4]
				$callback {*}$params
				incr matchingBinds
			}
		}
		if {$matchingBinds == 0} {
			putdebug "No bind for queue $queue message $message"
		}
	}

	proc get_projects {} {
		registry get notifications.projects
	}

	proc get_notification_channel {project group} {
		if {$project == "Wolfplex"} {
			return "#wolfplex"
		}
		if {$project == "TrustSpace"} {
			return "#wolfplex"
		}
		if {$project == "Keruald"} {
			return "#nasqueron-logs"
		}
		if {$project == "Nasqueron"} {
			switch $group {
				eglide { return "#eglide" }
				tasacora { return "#tasacora" }
				trustspace { return "#wolfplex" }
				docker { return "#nasqueron-ops" }
				ops { return "#nasqueron-ops" }
				orgz { return "#nasqueron-ops" }
				devtools { return "#nasqueron-logs" }
				nasqueron { return "#nasqueron-logs" }
				default {
					putdebug "Message for unknown group: $project $group"
					return "#nasqueron-logs"
				}
			}
		}
		return ""
	}

	proc get_image_from_docker_payload {payload} {
		set repository [dict get $payload repository]
		dict get $repository repo_name
	}

	proc docker_build_summary {service project group rawContent type text link} {
		if {$service != "DockerHub" || $type != "push"} {
			return
		}

		set image [get_image_from_docker_payload $rawContent]
		set key notifications.periodics.docker.$project

		set periodicsNotifications [registry get $key]
		dict incr periodicsNotifications $image
		registry set $key $periodicsNotifications
	}

	proc channel_notify_periodics {minutes hours day month year} {
		foreach project [get_projects] {
			channel_notify_periodics_for_project $project
		}
	}

	proc docker_format_builds {builds} {
		set first 1
		foreach "image count" $builds {
			lappend list "$image (${count}x)"
		}
		join $list ", "
	}

	proc channel_notify_periodics_for_project {project} {
		set key notifications.periodics.docker.$project
		set builds [registry get $key]
		if {$builds == ""} {
			return
		}

		set channel [get_notification_channel $project docker]
		putquick "PRIVMSG $channel :New images pushed to Docker Hub: [docker_format_builds $builds]"
		registry delete $key
	}

	proc channel_notify {service project group rawContent type text link} {
		# T790 - Ignores Docker Hub notification in real time to offer a summary instead
		if {$service == "DockerHub"} {
			return
		}

		# T1253 - Some events produce "null text"
		if {$text == "null"} {
			set routingKey "$project.$group.$service.$type"
			putdebug "Message 'null' received for $routingKey notification:"
			putdebug $rawContent
			return
		}

		set channel [get_notification_channel $project $group]
		if {$channel == ""} {
			return
		}

		set message $text
		if {$link != ""} {
			append message " — $link"
		}

		putquick "PRIVMSG $channel :$message"
	}
}
