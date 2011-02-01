# ===============================================
# =========        ====     ======   ============
# ============  ======  ===  ===   =   ==========
# ============  =====  ========   ===   =========
# ============  =====  =============   ==========
# ============  =====  ============   ===========
# == DcK =====  =====  ===========   ============
# ============  =====  ==========   =============
# ============  ======  ===  ===   ==============
# ============  =======     ===        ==========
# ===============================================
# ===============================================
# == Tau Ceti Central == Server administration ==
# ==  This is a very dangerous product to use  ==
# ==   Don't deploy it in stable environment   ==
# ==    Or say goodbye to the serv security    ==
# ==     This warning will not be repeated     ==
# ==      All your base are belong to us!      ==
# ===============================================
# ===============================================
#
#     (c) 2011 Sébastien Santoro aka Dereckson.
#     Released under BSD license.

#
# Configuration
#

set tc2(bot)		TC2
set tc2(commands)	{account phpfpm}

#
# Binds
#

bind bot  -  tc2	 bot:tc2

#Commands aliases only, main commands are handled by tc2:initialize
bind dcc  W  php-fpm	 dcc:phpfpm
bind pub  W .php-fpm	 pub:phpfpm

#
# Initializes bind and creates procedures for every tc2 commands
#

proc tc2:initialize {} {
	global tc2
	set proc_tc2_command_dcc {
		tc2 dcc $idx $handle %COMMAND% $arg
		return 1
	}
	set proc_tc2_command_pub {
		tc2 pub "$chan $nick" $handle %COMMAND% $text
		return 1
	}
	foreach command $tc2(commands) {
		bind dcc W $command dcc:$command
		bind pub W ".$command" pub:$command
		proc dcc:$command {handle idx arg} [string map "%COMMAND% $command" $proc_tc2_command_dcc]
		proc pub:$command {nick uhost handle chan text} [string map "%COMMAND% $command" $proc_tc2_command_pub]
	}
}

tc2:initialize

#
# TC2 clients procdures
#

proc bot:tc2 {sourcebot command text} {
	if [catch {
		set success	[dict get $text success]
		set reply	[dict get $text reply]
		set bind	[dict get $text bind]
		set who		[dict get $text who]
		tc2:reply $bind $who $reply
	}] {
		putdebug $text
	}
}

proc tc2 {bind who handle command arg} {
	global tc2
	if ![islinked $tc2(bot)] {
		tc2:reply $bind $who "$tc2(bot) isn't linked"
		return
	}
	putbot $tc2(bot) "tc2 [dict create requester $handle command $command arg $arg bind $bind who $who]"
}

proc tc2:reply {bind who message} {
	if {$bind == "dcc"} {
		putdcc $who $message
	} elseif {$bind == "pub"} {
		foreach "chan nick" $who {}
		putserv "PRIVMSG $chan :$nick, $message"
	} {
		error "Unknown bind in tc2:reply: $bind (expected: dcc or pub)"
	}
}
