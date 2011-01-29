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

bind bot  - tc2 bot:tc2

proc bot:tc2 {sourcebot command text} {
	#Sourcebot: Nasqueron
	#Command:   tc2
	#Text:      requester Dereckson command phpfpm arg status
	set requester	[dict get $text requester]
	set cmd		[dict get $text command]
	set arg		[dict get $text arg]
	set bind	[dict get $text bind]
	set who		[dict get $text who]

	#Logs entry
	log tc2 "$requester@$sourcebot" "$cmd $arg"

	#Executes command
	if [proc_exists tc2:command:$cmd] {
		set reply [tc2:command:$cmd $requester $arg]
	} {
		set reply {0 "Unknown command: $cmd"}
	}

	#Reports result
	putbot $sourcebot "tc2 [dict create success [lindex $reply 0] reply [lindex $reply 1] bind $bind who $who]"
	return 1
}

proc tc2:username_isvalid {username} {

}

proc tc2:username_exists {username} {
    #TODO: Windows and other OSes
    if {[exec -- logins -oxl $username] == ""} {
        return 0
    } {
        return 1
    }
}

}

#phpfpm reload
#phpfpm status
#phpfpm create <user>
proc tc2:command:phpfpm {requester arg} {
	set command [lindex $arg 0]

	switch $command {
		"reload" {
			if [catch {exec /usr/local/etc/rc.d/php-fpm reload} output] {
				return {0 $output}
			} {
				return {1 "ok, php-fpm reloaded"}
			}
		}

		"status" {
			catch {exec /usr/local/etc/rc.d/php-fpm status} output
			set reply 1
			lappend reply [string map {"\n" " "} $output]
			putdebug $reply
			return $reply
		}

		"create" {
			set user [lindex $arg 1]
			if {$user == ""} {
				return {0 "syntax: phpfpm create <user>"}
			}
			if [file exists "/usr/local/etc/php-fpm/$user.conf"] {
				return {0 "there is already a $user pool"}
			}
			return {0 "not yet implemented"}
			set port [sql "SELECT MAX(pool_port) FROM tc2_phpfpm_pools]
			if {$port == ""} {
				set port 9000
			} {
				incr port
			}
			#string map "%REQUESTER% $requester %TIME% [unixtime] %PORT% $port %USER% $user" $template
		}

		default {
			set reply 0
			lappend reply "unknown command: $command"
		}
	}
}
