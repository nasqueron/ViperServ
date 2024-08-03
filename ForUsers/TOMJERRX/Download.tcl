# This TCL allows to request the eggdrop to download a file at a specified URL.

package require http

#
# Configuration
#

# Where to store downloaded files?
set Download(path) ${incoming-path}

#
# Events
#

bind pub - !download pub:download
bind pub - !dl       pub:download

# Handles download public channel commands
proc pub:download {nick uhost handle chan text} {
	set url [string trim $text]

	if {$url == ""} {
		puthelp "PRIVMSG $chan :$nick, what URL do you want to download?"
		return 0
	}

	if {![isvalidurl $url]} {
		puthelp "PRIVMSG $chan :$nick, $url isn't a valid URL"
		return 0
	}

	if {![download $url]} {
		puthelp "PRIVMSG $chan :$nick, I can't download that."
		return 0
	}

	puthelp "PRIVMSG $chan :$nick, downloaded."
	return 1
}

#
# Helper methods
#

proc isvalidurl {url} {
	return 1
}

proc getfilename {url fd} {
	# Files to download should have a Content-Disposition header.
	set headers [::http::meta $fd]
	if {[dict exists $headers Content-Disposition]} {
		set re "filename=\"(.*)\""
		if {[regexp $re [dict get $headers Content-Disposition] match filename]} {
			return $filename
		}
	}

	# As a fallback, we use URL tail
	file tail $url
}

proc getlocalfilename {filename} {
	global Download
	set base [file join $Download(path) $filename]

	# Not existing filename, we can use it
	if {![file exists $base]} {
		return $base
	}

	# If it already exists, we append .1 .2 .3
	set i 1
	while {[file exists $base.$i]} {
		incr i
	}
	return $base.$i
}

proc download {url} {
	# Code from http://wiki.tcl.tk/12871 by Venkat Iyer and Martin Lemburg.
	set fd_remote [::http::geturl $url -binary 1]
	set filename [getfilename $url $fd_remote]
	set localpath [getlocalfilename $filename]

	if {[::http::ncode $fd_remote] != 200} {
		# TODO: follow redirections or invoke curl instead of doing it in native TCL
		return 0
	}

	set fd_local [open $localpath w]
	fconfigure $fd_local -translation binary
	puts -nonewline $fd_local [::http::data $fd_remote]
	close $fd_local

	::http::cleanup $fd_remote
	return 1
}
