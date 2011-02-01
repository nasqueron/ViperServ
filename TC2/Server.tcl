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

#Handles tc2 requests from linked bots
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
		putcmdlog "(tc2) <$requester@$sourcebot> $cmd $arg"
		set reply [tc2:command:$cmd $requester $arg]
	} {
		set reply {0 "Unknown command: $cmd"}
	}

	#Reports result
	putbot $sourcebot "tc2 [dict create success [lindex $reply 0] reply [lindex $reply 1] bind $bind who $who]"
	return 1
}

#Checks if $username begins by a letter and contains only letters, digits, -, _ or .
proc tc2:username_isvalid {username} {
	regexp {^[A-Za-z][A-Za-z0-9_\-\.]*$} $username
}

#Determines if $username exists on the system
#SECURITY: to avoid shell injection, call first tc2:username_isvalid $username
proc tc2:username_exists {username} {
    #TODO: Windows and other OSes (this line has been tested under FreeBSD)
    if {[exec -- logins -oxl $username] == ""} {
        return 0
    } {
        return 1
    }
}

#Gets server hostname
proc tc2:hostname {} {
	exec hostname -s
}

#Determines if $username is root
proc tc2:isroot {username} {
	#Validates input data
	set username [string tolower $username]
	if ![tc2:username_isvalid $username] {
		return 0
	}

	#Check 1 - User has local accreditation
	if ![sql "SELECT count(*) FROM tc2_roots WHERE account_username = '$username' AND server_name = '[sqlescape [tc2:hostname]]'"] {
		return 0
	}

	#Check 2 - User is in the group wheel on the server
	if {[lsearch [exec -- id -Gn $username] wheel] == "-1"} {
		return 0
	} {
		return 1
	}
}

#Determines if $requester is *EXPLICITELY* allowed to allowed to manage the account $user
#When you invoke this proc, you should also check if the user is root.
# e.g. if {[tc2:isroot $requester] || [tc2:userallow $requester $user]} { ... }
proc tc2:userallow {requester user} {
	set sql "SELECT count(*) FROM tc2_users_permissions WHERE server_name = '[sqlescape [tc2:hostname]]' AND account_username = '[sqlescape $user]' AND user_id = [getuserid $user]"
	putdebug $sql
	sql $sql
}

#tc2:getpermissions on $username: Gets permissions on the $username account
#tc2:getpermissions from $username: Gets permissions $username have on server accounts
proc tc2:getpermissions {keyword username} {
	switch $keyword {
		"from" {
			set sql "SELECT account_username FROM tc2_users_permissions WHERE server_name = '[sqlescape [tc2:hostname]]' AND user_id = '[getuserid $username]'"
		}
		"on" {
			set sql "SELECT u.username FROM tc2_users_permissions p, users u WHERE p.server_name = '[sqlescape [tc2:hostname]]' AND p.account_username = '$username' AND u.user_id = p.user_id"
		}
		default {
			error "from or on expected"
		}
	}
	set accounts ""
	foreach row [sql $sql] {
		lappend accounts [lindex $row 0]
	}

}

#account permission
#account isroot
#account exists
proc tc2:command:account {requester arg} {
	set command [lindex $arg 0]
	switch -- $command {
		"exists" {
			set username [lindex $arg 1]
			if ![tc2:username_isvalid $username] {
				return {0 "this is not a valid username"}
			}
			if [tc2:username_exists $username] {
				list 1 "$username is a valid account on [tc2:hostname]."
			} {
				list 1 "$username isn't a valid account on [tc2:hostname]."
			}
		}

		"isroot" {
			set username [lindex $arg 1]
			if ![tc2:username_isvalid $username] {
				return {0 "this is not a valid username"}
			}
			if [tc2:isroot $username] {
				list 1 "$username has got root accreditation on [tc2:hostname]."
			} {
				list 1 "$username doesn't seem to have any root accreditation [tc2:hostname]."
			}
		}

		"permission" {
			set username [lindex $arg 1]
			if ![tc2:username_isvalid $username] {
				return {0 "this is not a valid username"}
			}

			switch -- [lindex $arg 2] {
				"" {
					set sentences {}
					set accounts_from [tc2:getpermissions from $username]
					set accounts_on [tc2:getpermissions on $username]
					if {$accounts_on != ""} {
						lappend sentences "has authority upon [join $accounts_on ", "]"
					}
					if {$accounts_from != ""} {
						lappend sentences "account can be managed from IRC by [join $accounts_from ", "]"
					}
					if {[tc2:isroot $username]} {
						lappend sentences "has root access"
					}
					if {$sentences == ""} {
						list 1 nada
					} {
						list 1 "$username [join $sentences " / "]."
					}
				}

				"add" {
					#e.g. .account permission espacewin add dereckson
					#      will give access to the espacewin account to dereckson
					if {![tc2:isroot $requester] && ![tc2:userallow $requester $username]} {
						return "0 {you don't have the authority to give access to $username account.}"
					}

					#Asserts mandataire has an account
					set mandataire [lindex $arg 3]
					if {[set mandataire_user_id [getuserid $mandataire]] == ""} {
						return "0 {please create first a bot account for $mandataire.}"
					}

					#Adds the permission
					sqlreplace tc2_users_permissions "server_name account_username user_id" [list [tc2:hostname] $username $mandataire_user_id]

					return "1 {$mandataire has now access to $username account.}"
				}

				"del" {
					#e.g. .account permission espacewin del dereckson
					#      will remove access to the espacewin account to dereckson
					if {![tc2:isroot $requester] && ![tc2:userallow $requester $username]} {
						return "0 {you don't have the authority to manage the $username account.}"
					}

					#Asserts mandataire is a valid bot account
					set mandataire [lindex $arg 3]
					if {[set mandataire_user_id [getuserid $mandataire]] == ""} {
						return "0 {$mandataire doesn't have a bot account, and so, no such permission.}"
					}

					#Checks if the permission exists
					if ![tc2:userallow $requester $mandataire] {
						return "0 {$mandataire haven't had an access to $username account.}"
					}

					#Removess the permission
					sql "DELETE FROM tc2_users_permissions WHERE server_name = '[sqlescape [tc2:hostname]]' AND account_username = '$username' AND user_id = '$mandataire_user_id'"

					return "1 {$mandataire doesn't have access to $username account anymore.}"
				}

				"+root" {
					#Checks right and need
					if ![tc2:isroot $requester] {
						return "0 {you don't have root authority yourself.}"
					}
					if [tc2:isroot $username] {
						return "0 {$username have already root authority.}"
					}

					#Declares him as root
					sqlreplace tc2_roots "server_name account_username user_id" [list [tc2:hostname] $username [getuserid $username]]

					#Checks if our intervention is enough
					if [tc2:isroot $username] {
						list 1 "$username have now root authority."
					} {
						list 1 "$username have been added as root and will have root authority once in the wheel group."
					}
				}

				"-root" {
					if ![tc2:isroot $requester] {
						return {0 "you don't have root authority yourself."}
					}
					if ![tc2:isroot $username] {
						list 0 "$username doesn't have root authority."
					} {
						#Removes entry from db
						sql "DELETE FROM tc2_roots WHERE server_name = '[sqlescape [tc2:hostname]]' AND account_username = '[sqlescape $username]'"

						#Checks if our intervention is enough
						list 1 "$username doesn't have root authority on IRC anymore. Check also the wheel group."
					}
				}

				default {
					list 0 "expected: add <username>, del <username>, exists, +root, -root, or nothing"
				}
			}
		}

		"groups" {
			set username [lindex $arg 1]
			if ![tc2:username_isvalid $username] {
				return {0 "this is not a valid username"}
			}
			if [tc2:username_exists $username] {
				list 1 [exec -- id -Gn $username]
			} {
				list 0 "$username isn't a valid account on [tc2:hostname]."
			}
		}

		"" {
			return {0 "permission, isroot, exists or groups expected"}
		}

		default {
			set reply 0
			lappend reply "unknown command: $command"
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
			return $reply
		}

		"create" {
			set user [lindex $arg 1]
			if {$user == ""} {
				return {0 "syntax: phpfpm create <user>"}
			}
			if ![tc2:username_isvalid $user] {
				return {0 "not a valid username"}
			}
			if ![tc2:username_exists $user] {
				return "0 {$user isn't a valid [tc2:hostname] user}"
			}
			if [file exists [set file "/usr/local/etc/php-fpm/$user.conf"]] {
				return "0 {there is already a $user pool}"
			}
			if {![tc2:isroot $requester] && ![tc2:userallow $requester $user]} {
				return "0 {you don't have the authority to create a pool under $user user}"
			}
			set port [sql "SELECT MAX(pool_port) FROM tc2_phpfpm_pools"]
			if {$port == ""} {
				set port 9000
			} {
				incr port
			}

			#Adds it in MySQL table
			set time [unixtime]
			sqladd tc2_phpfpm_pools {pool_user pool_port pool_requester pool_time} [list $user $port $requester $time]

			#Write config gile
			global username
			set fd [open /usr/local/etc/php-fpm/pool.tpl r]
			set template [read $fd]
			close $fd
			set fd [open $file w]
			puts $fd [string map "%REQUESTER% $requester %TIME% $time %PORT% $port %USER% $user %COMMENT% {Autogenerated by $username}" $template]
			close $fd
			exec -- chown root:config $file
			exec -- chmod 644 $file
			return {1 "pool created, use '.phpfpm reload' to enable it"}
		}

		"" {
			return {0 "create, status or reload expected"}
		}

		default {
			set reply 0
			lappend reply "unknown command: $command"
		}
	}
}
