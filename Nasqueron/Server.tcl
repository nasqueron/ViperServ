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

bind dcc  W  phpfpm	 dcc:phpfpm
bind dcc  W  php-fpm	 dcc:phpfpm
bind pub  W .phpfpm	 pub:phpfpm
bind pub  W .php-fpm	 pub:phpfpm
bind bot  -  tc2	 bot:tc2

set tc2(bot)	TC2

proc dcc:phpfpm {handle idx arg} {
	tc2 dcc $idx $handle phpfpm $arg
	return 1
}

proc pub:phpfpm {nick uhost handle chan text} {
	tc2 pub "$chan $nick" $handle phpfpm $text
	return 1
}

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
