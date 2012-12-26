bind dcc  -  antidater	 dcc:antidater
bind dcc  -  postdater	 dcc:postdater
bind dcc  -  days	 dcc:days
bind dcc  -  quux        dcc:quux

#
# Dates calculation
#

#Removes $days from $date or if unspecified, current unixtime
proc antidater {days {date ""}} {
	postdater [expr $days * -1] $date
}

#Adds $days from $date or if unspecified, current unixtime
proc postdater {days {date ""}} {
	if {$date == ""} {
		set date [unixtime]
	}
	incr date [expr 86400 * $days]
}

#.antidater 15
#.antidater 2011-01-29 4
proc dcc:antidater {handle idx arg} {
	set argc [llength $arg]
	if {$argc == 0} {
		putdcc $idx "De combien de jours dois-je antidater ?"
		return
	}
	if {$argc == 1} {
		set date ""
		set days $arg
	} {
		if [catch {set date [clock scan [lindex $arg 0]]} err] {
			putdcc $idx $err
			return
		}
		set days [lindex $arg 1]
	}
	if ![isnumber $days] {
		putdcc $idx "$days n'est pas un nombre de jours"
		return
	}
	putdcc $idx [clock format [antidater $days $date] -format "%Y-%m-%d"]
	return 1
}

#.postdater 15
#.postdater 2011-01-29 4
proc dcc:postdater {handle idx arg} {
	set argc [llength $arg]
	if {$argc == 0} {
		putdcc $idx "De combien de jours dois-je postdater ?"
		return
	}
	if {$argc == 1} {
		set date ""
		set days $arg
	} {
		if [catch {set date [clock scan [lindex $arg 0]]} err] {
			putdcc $idx $err
			return
		}
		set days [lindex $arg 1]
	}
	if ![isnumber $days] {
		putdcc $idx "$days n'est pas un nombre de jours"
		return
	}
	putdcc $idx [clock format [postdater $days $date] -format "%Y-%m-%d"]
	return 1
}

proc quux {userid category content {tags ""}} {
	global username
	lappend tags client:$username
	sqladd quux "user_id quux_date quux_category quux_content quux_tags" [list $userid [unixtime] $category $content $tags]
}

proc dcc:quux {handle idx arg} {
	switch [llength $arg] {
		0 {
			putdcc $idx "Quuxons !"
		}
		1 {
			putdcc $idx "Usage: .quux <category> <content>"
		}
		default {
			set category [lindex $arg 0]
			set content [string range $arg [string length $category]+1 end]
			quux [getuserid $idx] $category $content
			putcmdlog "#$handle# quux ..."
		}
	}
}