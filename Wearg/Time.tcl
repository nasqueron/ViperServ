#bind cron - "* * * * *" cron:minute
bind cron - "?2 * * * *" cron:often
bind cron - "?7 * * * *" cron:often
#bind cron - "0 * * * *" cron:hourly
#bind cron - "0 4 * * *" cron:daily

#Every 5 minutes
proc cron:often {minute hour day month weekday} {
	#Reconnects to broker
	if {[mq connected]} {
		mq disconnect
	}
}

#Every hour
proc cron:hourly {minute hour day month weekday} {
}

#Every day, at 4am
proc cron:daily {minute hour day month weekday} {
}
