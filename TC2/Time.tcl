utimer 5 onload
bind cron - "* * * * *" cron:minute
bind cron - "*/5 * * * *" cron:often
bind cron - "0 * * * *" cron:hourly
bind cron - "0 4 * * *" cron:daily

proc onload {} {
	sqlconnect sql7
}

proc launch {} {
	#This proc, called on startup, causes the eggdrop
	#to die on "unloadmodule server"
	#.tcl launch manually will work

	#Drops IRC support
	unloadmodule irc
	unloadmodule ctcp
	unloadmodule channels
	unloadmodule server

	#Links to primary bot
	link Daeghrefn
}

#Every minute
proc cron:minute {minute hour day month weekday} {
}

#Every 5 minutes
proc cron:often {minute hour day month weekday} {
	#Reconnects to sql, sql2
	sqlrehash

	#Sends a no-op command to keep sql7 alive
	if [catch {
		sql7 "SELECT 666"
	}] {
		putcmdlog "Warning: not connected to sql7 - mysql won't work."
	}
}

#Every hour
proc cron:hourly {minute hour day month weekday} {
}

#Every day, at 4am
proc cron:daily {minute hour day month weekday} {
}
