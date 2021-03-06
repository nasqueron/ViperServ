bind pubm - * pubm:url
bind sign - "#wikipedia-fr *!*@*" sign:excessflood

bind dcc  o botnet dcc:botnet

setudef flag parse-url

#
# URL management
#

#Determines if the URL matches a video site url:getvideotitle can handle
proc url:isvideo {url} {
	foreach site "youtu.be metacafe.com dailymotion video.google.com photobucket.com video.yahoo.com youtube.com depositfiles.com vimeo.com" {
		if {[string first $site $url] > -1} {
			return 1
		}
	}
	return 0
}

#Gets video title
proc url:getvideotitle {url} {
	set title ""
	catch {
		set title [exec -- youtube-dl --no-warnings -e $url]
	}
	return $title
}

#This proc allows to handle URLs in lines
#Currently, it prints the video title when not provided with the URL
#TODO: checks 402/403/404/500 error codes
proc pubm:url {nick uhost handle channel text} {
	if {![channel get $channel parse-url]} {
		return 0
	}
	foreach url [geturls $text] {
		if [url:isvideo $url] {
			#Prints video information on the channel
			#if it's not already in $text
			set info [url:getvideotitle $url]
			if {[string length [string trim $info]] > 0 && [string first $info $text] == -1} {
				putserv "PRIVMSG $channel :\[Vid\] $info"
			}
		}
	}
}

#
# #wikipedia-fr botnet mitigation
#

proc isbotnetsuspecthost {host} {
	if [isip $host] {
		return 1
	}
	foreach domain [registry get protection.botnet.hosts] {
		if [string match $domain $host] {
			return 1
		}
	}
	return 0
}

proc isfloodquitmessage {reason} {
	foreach floodreason [registry get protection.botnet.reasons] {
		if [string match $reason $floodreason] {
			return 1
		}
	}
	return 0
}

proc sign:excessflood {nick uhost handle channel reason} {
	# We're interested by unknown users quitting with Excess Flood message.
	if {![isfloodquitmessage $reason] || $handle != "*"} {
		return
	}

	# Botnet nicks have 3 to 5 characters
	set len [strlen $nick]
	if {$len < 3 || $len > 5} {
		return
	}

	# And belong to specific ISPs
	set host [gethost $uhost]
	if [isbotnetsuspecthost $host] {
		add_botnet_ban $host
	}
}

proc dcc:botnet {handle idx arg} {
	if {$arg == ""} {
		putdcc $idx "Usage: .botnet <nick>"
		return
	}

	set nick $arg
	set uhost [getchanhost $nick]

	if {$uhost == ""} {
		putdcc $idx "User unknown: $nick"
		return
	}

	set host [gethost $uhost]
	if [isbotnetsuspecthost $host] {
		add_botnet_ban $host
		return 1
	} {
		putdcc $idx "Not a botnet suspect."
		return
	}
}

proc add_botnet_ban {host} {
	global botname

	newchanban [registry get protection.botnet.channel] *!*@$host $botname [registry get protection.botnet.banreason] [registry get protection.botnet.banduration] sticky
	sql "INSERT INTO log_flood (host, `count`) VALUES ('[sqlescape $host]', 1) ON DUPLICATE KEY UPDATE `count` = `count` + 1;"
}
