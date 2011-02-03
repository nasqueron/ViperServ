# #wolfplex
bind pubm - "#wolfplex *"	pubm:url

#
# URL management
#

proc geturls {text} {
	#Finds the first url position
	set pos -1
	foreach needle "http:// https:// www." {
		set pos1 [string first $needle $text]
		if {$pos1 != -1 && ($pos == -1 || $pos1 < $pos)} {
			set pos $pos1
		}
	}

	#No URL found
	if {$pos == -1} {return}

	#URL found
	set pos2 [string first " " $text $pos]
	if {$pos2 == -1} {
		#Last URL to be found
		string range $text $pos end
	} {
		#Recursive call to get other URLs
		concat [string range $text $pos $pos2-1] [geturls [string range $text $pos2+1 end]]
	}
}

proc url:isvideo {url} {
	#We use grep "_VALID_URL =" /usr/local/bin/youtube-dl for this list
	foreach site "youtu.be metacafe.com dailymotion video.google.com photobucket.com video.yahoo.com youtube.com depositfiles.com" {
		if {[string first $site $url] > -1} {
			return 1
		}
	}
	return 0
}

proc url:getvideoinfo {url} {
	set title ""
	catch {
		set title [exec -- youtube-dl -e $url]
	}
	return $title
}

proc pubm:url {nick uhost handle channel text} {
	foreach url [geturls $text] {
		if [url:isvideo $url] {
			#Prints video information on the channel
			#if it's not already in $text
			set info [url:getvideoinfo $url]
			if {[string first $info $text] == -1} {
				putserv "PRIVMSG $channel :$info"
			}
		}
	}
}

