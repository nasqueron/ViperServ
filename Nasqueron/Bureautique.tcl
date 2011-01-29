bind dcc  -  antidater	 dcc:antidater
bind dcc  -  postdater	 dcc:postdater
bind dcc  -  days	 dcc:days

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
