utimer 90 onload
bind cron - "* * * * *" cron:minute
bind cron - "*/5 * * * *" cron:often
bind cron - "0 * * * *" cron:hourly
bind cron - "0 4 * * *" cron:daily

proc onload {} {
	#Drops IRC support
	unloadmodule irc
	unloadmodule ctcp
	unloadmodule channels
	unloadmodule server

	#Links to Nasqueron
	link Nasqueron
}

#Every minute
proc cron:minute {minute hour day month weekday} {
}

#Every 5 minutes
proc cron:often {minute hour day month weekday} {
	sqlrehash
}

#Every hour
proc cron:hourly {minute hour day month weekday} {
}

#Every day, at 4am
proc cron:daily {minute hour day month weekday} {
}
