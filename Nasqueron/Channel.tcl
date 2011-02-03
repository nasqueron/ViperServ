# #wolfplex
bind pubm - "#wolfplex *"	pubm:url

#
# URL management
#

#Determines if the URL matches a video site url:getvideotitle can handle
proc url:isvideo {url} {
	#We use grep "_VALID_URL =" /usr/local/bin/youtube-dl for this list
	foreach site "youtu.be metacafe.com dailymotion video.google.com photobucket.com video.yahoo.com youtube.com depositfiles.com" {
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
		set title [exec -- youtube-dl -e $url]
	}
	return $title
}

#This proc allows to handle URLs in lines
#Currently, it prints the video title when not provided with the URL
#TODO: checks 402/403/404/500 error codes
proc pubm:url {nick uhost handle channel text} {
	foreach url [geturls $text] {
		if [url:isvideo $url] {
			#Prints video information on the channel
			#if it's not already in $text
			set info [url:getvideotitle $url]
			if {[string first $info $text] == -1} {
				putserv "PRIVMSG $channel :$info"
			}
		}
	}
}

