package require http
package require tls
package require json::write

#
# HTTP support
#

::tls::init -ssl2 false -ssl3 false -tls1 true
::http::register https 443 ::tls::socket

# Determines if a specified page's source code contains the specified string
proc http_contains {pattern url} {
	try {
		set fd [::http::geturl $url -timeout 600]
	} on error {result} {
		return 0
	}

	if {[::http::status $fd] != "ok"} {
		set result 0
	} elseif {[::http::ncode $fd] != 200} {
		set result 0
	} elseif {[string first $pattern [::http::data $fd]] > -1} {
		set result 1
	} {
		set result 0
	}

	::http::cleanup $fd
	return $result
}


#
# TCL helpers
#

#Determines if $proc exists
proc proc_exists {proc} {
	expr {[info procs $proc] == $proc}
}


proc is_package_present {package} {
	expr ![catch {package present $package}]
}

#
# Loop constructs
#

# http://wiki.tcl.tk/3603
proc do {code while cond} {
    tailcall try $code\n[list $while $cond $code]
}

#
# List procs
#

# Gets the maximal value of a numeric list
proc lmax {items} {
	getultimatecomparedfromlist $items >
}

# Gets the minimal value of a numeric list
proc lmin {items} {
	getultimatecomparedfromlist $items <
}

# Gets the ultimately compared item from a list
proc getultimatecomparedfromlist {items op} {
	set hasValue 0
	set max {}

	foreach item $items {
		if {![string is double $item]} {
			continue
		}

		if {!$hasValue} {
			set hasValue 1
			set max $item
			continue
		}

		if {[expr $item $op $max]} {
			set max $item
		}
	}

	return $max
}

#
# Date and time procs
#

proc iso8601date {{clockval ""}} {
	if {$clockval == {}} {
		set clockval [clock seconds]
	}

	clock format $clockval -format %Y-%m-%dT%H:%M:%S%z
}

#
# Trivial procs
#

#Determines if $v is a number
proc isnumber {v} {
    return [expr {! [catch {expr {int($v)}}]}]
}

# Returns +-<number>
proc numberSign {number} {
	if {$number > 0} {
		return "+$number"
	} {
		return $number
	}
}

# Returns the value as is if numeric, or "0" if not
proc zeroornumber {value} {
	if {$value == "" || ![string is double $value]} {
		return 0
	}
	return $value
}

#Returns "s" if $count implies a plural
#TODO: keep this method for French (ie NOT adjusting values for English)
#      and grab the plural proc from wiki.tcl.tk for English.
proc s {count} {
	if {$count >= 2 || $count <= -2} {return "s"}
}

proc isnotasciiutf8char {char} {
    regexp {(?x)
      [\xC0-\xDF] [\x80-\xBF] |    # Two-byte chars (\u0080-\u07FF)
      [\xE0-\xEF] [\x80-\xBF]{2} | # Three-byte chars (\u0800-\uFFFF)
      [\xF0-\xF4] [\x80-\xBF]{3}   # Four-byte chars (U+10000-U+10FFFF, not suppoted by Tcl 8.5)
    } $char
}

proc isutf8char {char} {
    regexp {(?x)
      [\x00-\x7F] |                # Single-byte chars (ASCII range)
      [\xC0-\xDF] [\x80-\xBF] |    # Two-byte chars (\u0080-\u07FF)
      [\xE0-\xEF] [\x80-\xBF]{2} | # Three-byte chars (\u0800-\uFFFF)
      [\xF0-\xF4] [\x80-\xBF]{3}   # Four-byte chars (U+10000-U+10FFFF, not suppoted by Tcl 8.5)
    } $char
}

#
# Dictionaries
#

# Gets recursively a value in a dictionary
#
# @param $dict the dictionary (without any dots in keys)
# @param $key the value's key; if dict are nested, succesive keys are separated by dots (e.g. change.owner.name)
# @param $throwErrorIfKeyDoesNotExist when the key doesn't exist: if true, throws an error; otherwise, returns an empty string
# @return the dictionary value at the specified key, or an empty string if the key doesn't exist
proc dg {dict key {throwErrorIfKeyDoesNotExist 0}} {
	set keys [split $key .]
	if {[llength $keys] > 1} {
		# Recursive call
		# dg $dict a.b = dict get [dict get $dict a] b
		dg [dg $dict [lindex $keys 0] $throwErrorIfKeyDoesNotExist] [join [lrange $keys 1 end] .] $throwErrorIfKeyDoesNotExist
	} elseif {([llength $dict] % 2 == 0) && [dict exists $dict $key]} {
		# This is a dict and we have a key
		dict get $dict $key
	} elseif {$throwErrorIfKeyDoesNotExist > 0} {
		error "Key not found: $key"
	}
}

proc dict2json {dictToEncode} {
    ::json::write object {*}[dict map {k v} $dictToEncode {
        set v [::json::write string $v]
    }]
}

#
# Strings
#

proc strlen {str} {
    string length $str
}

#Completes $text by spaces or $char so the returned text length is $len
proc completestring {text len {char " "}} {
	set curlen [string length $text]
	if {$curlen >= $len} {
		return $text
	}
	if {[string length $char] < 2} {
		append text [string repeat $char [expr $len - $curlen]]
	} {
		while {[string length $text] < $len} {
			append text $char
		}
		string range $text 0 $len+1
	}
}

proc completestringright {text len {char " "}} {
	set curlen [string length $text]
	if {$curlen >= $len} {
		return $text
	}
	set completedtext [string range [completestring $text $len $char] $curlen end]
	append completedtext $text
}

## Prepends 0s to a number
##
## @param $number The number to zerofill
## @param $digits The number length
## @return The zerofilled number
proc zerofill {number digits} {
	format "%0${digits}d" $number
}

# Maps from a list of words the length of those words
# e.g. strlenmap "a aaa aa" will return {1 3 2}
proc strlenmap {words} {
	lmap key $words { string length $key }
}

# Search the max string lenghth from a list of strings
proc strlenmax {words} {
	zeroornumber [lmax [strlenmap $words]]
}

#
# SQL
#

#Reconnects to the sql & sql2 server
proc sqlrehash {} {
	global sql
	catch {
		sql  disconnect
		sql2 disconnect
	}
	sql  connect  $sql(host) $sql(user) $sql(pass)
	sql2 connect  $sql(host) $sql(user) $sql(pass)
	sql  selectdb $sql(database)
	sql2 selectdb $sql(database)
}

#Escape a string to use as sql query parameter
proc sqlescape {data} {
	#\ -> \\
	#' -> \'
	string map {"\\" "\\\\" "'" "\\'"} $data
}

#Gets the first item of the first row of a sql query (scalar results)
proc sqlscalar {sql} {
	lindex [lindex [sql $sql] 0] 0
}

#Adds specified data to specified SQL table
proc sqladd {table {data1 ""} {data2 ""}} {
	if {$data1 == ""} {
		set fields ""
		#Prints field to fill
		foreach row [sql "SHOW COLUMNS FROM $table"] {
			lappend fields [lindex $row 0]
		}
		return $fields
	}

	if {$data2 == ""} {
		set sql "INSERT INTO $table VALUES ("
		set data $data1
	} {
		set sql "INSERT INTO $table (`[join $data1 "`, `"]`) VALUES ("
		set data $data2
	}
	set first 1
	foreach value $data {
		if {$first == 1} {set first 0} {append sql ", "}
		append sql "'[sqlescape $value]'"
	}
	append sql ")"
	sql $sql
}

# Gets the value of the AUTOINCREMENT column for the last INSERT
#
# @return the last value of the primary key
proc sqllastinsertid {} {
	sql "SELECT LAST_INSERT_ID()"
}

proc sqlconnect {{sqlinstance "sql"} {defaultsfile ""}} {
	if {$defaultsfile == ""} {
		global env
		set defaultsfile $env(HOME)/.my.cnf
	}

	set config [readmycnf $defaultsfile]
	$sqlinstance connect [dict get $config host] [dict get $config user] [dict get $config password]
}

proc readmycnf {defaultsfile} {
	set config {}
	set fd [open $defaultsfile]
	while {[gets $fd line] != -1} {
		set entry [split $line =]
		if {[llength $entry] == 2} {
			dict set config {*}$entry
		}
	}
	close $fd
	return $config
}

#
# Registry
#

#Gets, sets, deletes or increments a registry value
proc registry {command key {value ""}} {
	switch -- $command {
		"add" {
			sqladd registry "data value" [list $key $value]
		}

		"get" {
			sqlscalar "SELECT value FROM registry WHERE `data` = '$key'"
		}

		"set" {
			sqlreplace registry "data value" [list $key $value]
		}

		"del" {
			registry delete $key $value
		}

		"delete" {
			sql "DELETE FROM registry WHERE `data` = '$key'"
		}

		"incr" {
			if {$value == ""} {
				set term 1
			} elseif {[string is integer $value]} {
				set term $value
			} {
				error "The increment term must be an integer."
			}

			set current [registry get $key]
			if {$current == ""} {
				registry set $key $term
			} {
				registry set $key [incr current $term]
			}
		}

		default {
			error "unknown subcommand: must be add, get, set, incr or delete"
		}
	}
}

#
# Users information
#

# Gets user_id from a username, idx or user_id
#
#
proc getuserid {who} {
	if {$who == ""} {
		return
	} elseif {![isnumber $who]} {
		#username -> user_id
		sql "SELECT user_id FROM users WHERE username = '[sqlescape $who]'"
	} elseif {$who < 1000} {
		#idx -> user_id
		getuserid [idx2hand $who]
	} else {
		#user_id -> user_id (or "" if not existing)
		sql "SELECT user_id FROM users WHERE user_id = $who"
	}
}

# Gets user info
#
# @param who The user
# @param what The information to get
proc getuserinfo {who what} {
	sqlscalar "SELECT $what FROM users WHERE user_id = [getuserid $who]"
}

#
# Text parsing
#

proc geturls {text} {
	#Finds the first url position
	set pos -1
	foreach needle "http:// https:// www. youtu.be" {
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

#Reads specified URL and returns content
proc geturltext {url {trim 1}} {
	set fd [http::geturl $url]
	set text [http::data $fd]
	http::cleanup $fd
	if $trim {
		string trim $text
	} {
		return $text
	}
}

proc numeric2ordinal {n} {
	switch $n {
		 1 { return first }
		 2 { return second }
		 3 { return third }
		 5 { return fifth }
		 8 { return eight }
		 9 { return ninth }
		#todo: ve -> f / y -> ie
		12 { return twelfth }
		default {
			set ordinal "[numeric2en $n]th"
			set m [expr $n % 10]
			if {$m == 0} {
				return [string map "yth ieth" $ordinal]
			}
			if {$n < 20} { return $ordinal }
			if {$n > 100} { return "${n}th" }
			return "[numeric2en [expr $n - $m]]-[numeric2ordinal $m]"
		}
	}
}

proc numeric2en {n {optional 0}} {
    #---------------- English spelling for integer numbers
    if {[catch {set n [expr $n]}]}  {return $n}
    if {$optional && $n==0} {return ""}
    array set dic {
        0 zero 1 one 2 two 3 three 4 four 5 five 6 six 7 seven
        8 eight 9 nine 10 ten 11 eleven 12 twelve
    }
    if [info exists dic($n)] {return $dic($n)}
    foreach {value word} {1000000 million 1000 thousand 100 hundred} {
        if {$n>=$value} {
            return "[numeric2en $n/$value] $word [numeric2en $n%$value 1]"
        }
    } ;#--------------- composing between 13 and 99...
    if $n>=20 {
        set res $dic([expr $n/10])ty
        if  $n%10 {append res -$dic([expr $n%10])}
    } else {
        set res $dic([expr $n-10])teen
    } ;#----------- fix over-regular compositions
    regsub "twoty" $res "twenty" res
    regsub "threet" $res "thirt" res
    regsub "fourty"  $res  "forty"  res
    regsub "fivet"  $res  "fift"  res
    regsub  "eightt"   $res  "eight" res
    set res
} ;#RS

# Truncates the first word
#
# @param string the string to truncate
# @return the truncated string
proc truncate_first_word {string} {
        set pos [string first " " $string]
        if {$pos == -1} return
        string range $string $pos+1 end
}

proc xmlescape {text} {
	#Determines if we should use <![CDATA[]]>
	set useCDATA 0
	if {[string first < $text] > -1 || [string first > $text] > -1} {
		set useCDATA 1
	}
	#TODO: check if there is no other case for CDATA
	#      check when to use CDATA instead &lt; &gt;

	#Output
	set text [string map {& {&amp;} ' {&apos;} "\"" {&quot;}} $text]

	if {$useCDATA} {
		return "<!\[CDATA\[$text]]>"
	}
	return $text
}

#
# URLs
#

namespace eval url {
        variable map
        variable alphanumeric a-zA-Z0-9._~-
        namespace export encode decode
        namespace ensemble create
}
proc url::init {} {
        variable map
        variable alphanumeric a-zA-Z0-9._~-

        for {set i 0} {$i <= 256} {incr i} {
                set c [format %c $i]
                if {![string match \[$alphanumeric\] $c]} {
                        set map($c) %[format %.2x $i]
                }
        }
        # These are handled specially
        array set map { " " + \n %0d%0a }
}
url::init
proc url::encode {str} {
        variable map
        variable alphanumeric

        # The spec says: "non-alphanumeric characters are replaced by '%HH'"
        # 1 leave alphanumerics characters alone
        # 2 Convert every other character to an array lookup
        # 3 Escape constructs that are "special" to the tcl parser
        # 4 "subst" the result, doing all the array substitutions

        regsub -all \[^$alphanumeric\] $str {$map(&)} str
        # This quotes cases like $map([) or $map($) => $map(\[) ...
        regsub -all {[][{})\\]\)} $str {\\&} str
        return [subst -nocommand $str]
}

# Decodes an URL
#
# @param $str The URL to decode
# @return The decoded URL
proc url::decode {str} {
        # rewrite "+" back to space
        # protect \ from quoting another '\'
        set str [string map [list + { } "\\" "\\\\"] $str]

        # prepare to process all %-escapes
        regsub -all -- {%([A-Fa-f0-9][A-Fa-f0-9])} $str {\\u00\1} str

        # process \u unicode mapped chars
        return [subst -novar -nocommand $str]
}

#
# GUID
#

# Gets the MD5 of a string, and returns it following the GUID format
#
# @param $str The string to compute the hash
# @return The MD5, formatted as a GUID
proc guidmd5 {str} {
	set md5 [md5 $str]
	set output ""
	for {set i 0} {$i < 32} {incr i} {
		if {$i == 8 || $i == 12 || $i == 16 || $i == 20} {
			append output "-"
		}
		append output [string index $md5 $i]
	}
	return $output
}

#
# Run interactive commands with callbacks
#

# Uses fileevent example code by Bryan Oakley
# http://stackoverflow.com/a/172061/1930997
#
# e.g. proc put_command_callback {fd line state} { put[lindex $state 0] [lindex $state 1] $line }
#
#      run_command "pwd" put_command_callback "" {dcc 12}
#      run_command "pwd" put_command_callback "" {quick "#foo"}
#
#      (we provide a more generic print_command_callback procedure for this general use.)

# Callback to print non interactive commands output in partyline, debug, channel or query
#
# @param $fd File descriptor of the command (not used)
# @param $line Line printed by the command result
# @param $state A list of two items, the first the mode, the second the target
#
# Accepted modes and matched target descriptions:
# - bot: target is another linked bot. A third optional state parameter could be the bot command.
# - quick/serv/help: target is a channel or a nick (through a private message)
# - notice: target is a nick (through a notice, sent in the putserv queue)
# - dcc: target is the dcc connection IDX
# - debug: prints the line as debug, target is ignored
proc print_command_callback {fd line state} {
    foreach "mode target" $state {}
    switch $mode {
        bot {
            if {[llength $state] > 2} {
                  set cmd [lindex $state 2]
                  putbot $target $cmd $line
            } {
                  putbot $target $line
            }
        }
        dcc     { putdcc $target $line }
        quick   { putquick "PRIVMSG $target :$line" }
        serv    { putserv  "PRIVMSG $target :$line" }
        help    { puthelp  "PRIVMSG $target :$line" }
        notice  { putserv  "NOTICE  $target :$line" }
        debug   { putdebug $line }
        default { putdebug "Unknown message mode: $mode (line were $line)" }
    }
}

# Same to print a Python error without the traceback
proc print_python_error_callback {fd output state} {
    print_command_callback $fd [extractPythonError $output] $state
}

# Runs a command, opens a file descriptor to communicate with the process
#
# @param $cmd the command to run
# @param $callbackProc a callback proc to handle the command output and send input
# @param $errorCallbackProc a callback proc to handle the command error output
# @param $state a state object to send to the callback proc
proc run_command {cmd callbackProc {errorCallbackProc ""} state} {
    set fd [open "| $cmd" r]
    fconfigure $fd -blocking false
    fileevent $fd readable [list interactive_command_handler $fd $callbackProc $errorCallbackProc $state]
}

# Closes a command
#
# @param $fd File descriptor to the command process
proc close_interactive_command {fd {errorCallbackProc ""} {state ""}} {
    fconfigure $fd -blocking true
    if {[catch {close $fd} err]} {
        if {$errorCallbackProc == ""} {
            putdebug $err
        } {
            $errorCallbackProc $fd $err $state
        }
    }
}

# Callback for fileevent to handle command output and state
#
# @param $fd File descriptor to the command process
# @param $callbackProc a callback proc to handle the command output and send input
# @param $state a state object to send to the callback proc
proc interactive_command_handler {fd callbackProc errorCallbackProc {state ""}} {
    set status [catch {gets $fd line} result]
    if { $status != 0 } {
        # unexpected error
        putdebug "Unexpected error running command: "
        putdebug $result
        close_interactive_command $fd $errorCallbackProc $state
    } elseif {$result >= 0} {
	$callbackProc $fd $line $state
    } elseif {[eof $fd]} {
        close_interactive_command $fd $errorCallbackProc $state
    } elseif {[fblocked $f]} {
        # Read blocked, so do nothing
    }
}

proc posix_escape {name} {
    foreach char [split $name {}] {
      switch -regexp $char {
        {'}           {append escaped \\'     }
        {[[:alnum:]]} {append escaped $char   }
        {[[:space:]]} {append escaped \\$char }
        {[[:punct:]]} {append escaped \\$char }
        default       {append escaped '$char' }
      }
    }
    return $escaped
}

# Returns absolute path to external script
proc get_external_script {script} {
	global env
	set path $env(HOME)/bin/
	append path $script
}

# Extracts the error from Python
proc extractPythonError {exception} {
    # The exception is one of the line of the text (so the newline-sensitive matching)
    # Before that, we have the full traceback we want to ignore
    # e.g. of a line to match: pywikibot.data.api.APIError: modification-failed: Item …
    if {[regexp -line {^([A-Za-z\.]+)\: (.*)$} $exception line type message]} {
        return $line
    } {
        putdebug "Regexp doesn't match a Python error for this output in extractPythonError:"
        putdebug $exception
    }
}

###
### Handle / nick handling
###

# Determines if a nick belongs to a bot
proc isbot {nick} {
    matchattr [nick2hand $nick] b
}

proc resolve_nick {nickname} {
	set resolved [whois $nickname 0]

	if {$resolved == ""} {
		return $nickname
	}

	return $resolved
}

# Returns an identified nickname or "" if not identified
# By default, can also return strings like "kumkum!kumkum@eglide.org"
proc whois {nickname {useUserHost 1}} {
	# By handle
	set result [nick2hand $nickname]
	if {$result != "*"} {
		#Will return "", when nick doesn't exist to avoid further processing.
		return $result
	}

	#Gets user@host
	set uhost [getchanhost $nickname]
	set host [lindex [split $uhost @] 1]

	# By Cloak
	if {[regexp / $host]} {
		set cloak [split $host /]
		set group [lindex $cloak 0]

		if {$group != "gateway" && $group != "nat"} {
			# @freenode/staff/ubuntu.member.niko → niko
			# @wikipedia/pdpc.21for7.elfix → elfix
			# @wikipedia/poulpy → poulpy
			return [lindex [split [lindex $cloak end] .] end]
		}
	}

	# By NickServ
	# TODO: code with callback

	# By user@host, when the host doesn't contain any digit
	if {$useUserHost && [regexp {^[^0-9]*$} $host]} {
		return "$nickname!$uhost"
	}

	# Can't identify
	return ""
}

#
# IP and host string manipulations
#

# Gets the host part of a [nick!]user@host string
proc gethost {uhost} {
	set pos [string first @ $uhost]
	if {$pos == -1} {
		return ""
	}
	string range $uhost [expr $pos + 1] end
}

# Determines if the specified string is a valid IPv4 address
proc isipv4 {string} {
	# http://wiki.tcl.tk/989 - Michael A. Cleverly
	set octet {(?:\d|[1-9]\d|1\d\d|2[0-4]\d|25[0-5])}
	regexp -- "^[join [list $octet $octet $octet $octet] {\.}]\$" $string

}

# Determines if the specified string is a valid IPv6 address
proc isipv6 {string} {
	#
	# NOTE: 2001:0db8:0000:0000:0000:0000:1428:57ab
	#				2001:0db8:0000:0000:0000::1428:57ab
	#				2001:0db8:0:0:0:0:1428:57ab
	#				2001:0db8:0:0::1428:57ab
	#				2001:0db8::1428:57ab
	#				2001:db8::1428:57ab
	#				2001:0db8:0000:0000:0000:0000:<IPv4>
	#				::1
	#				::
	#
	if {$string eq "::"} then {
		return true
	}

	if {[string range $string 0 1] == "::"} then {
		set string [string range $string 1 end]
	}

	if {[string range $string end-1 end] == "::"} then {
		set string [string range $string 0 end-1]
	}

	set octets [split $string :]
	set llength [llength $octets]

	if {$llength > 0 && $llength <= 8} then {
		set last [expr {$llength - 1}]

		for {set index 0} {$index < $llength} {incr index} {
			set octet [lindex $octets $index]
			set length [string length $octet]

			if {$length == 0} then {
				if {![info exists null]} then {
					set null $index; continue
				} else {
					return false
				}
			}

			if {$length <= 4 && [string is xdigit -strict $octet]} then {
				continue
			}

			if {$llength <= 7 && $index == $last && [isipv4 $octet]} then {
				continue
			}

			return false
		}

		return true
	}

	return false
}

# Determines if the specified string is a valid IP address
proc isip {string} {
	expr [isipv4 $string] || [isipv6 $string]
}

###
### IP helper procedures
###

# Extracts an IP address from a Freenode cloak
# Freenode tends to add IPs as suffix for gateway cloaks.
proc extract_addr_from_cloak {host} {
	if {[string first gateway/web/cgi-irc/kiwiirc.com/ip. $host] == 0} {
		return [string range $host 35 end]
	}

	# Finds an IPv4
	# Regexp from http://www.jamesoff.net/site/projects/eggdrop-scripts/proxycheck
	if {[regexp {[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$} $host ip]} {
		return $ip
	}

	return ""
}

# Extracts an IP or hostname from an IRC host
# If the host is a cloak not parseable, returns "".
proc extract_addr {host} {
	if {[string first / $host] > -1} {
		return [extract_addr_from_cloak $host]
	}

	return $host
}

###
### Send messages
###
### This system allows to offer more easily dual commands available in partyline
### and on a channel. An example implementation is in Wearg/ServersLog.tcl.
###

proc putbymode {callback message} {
    if {[llength $callback] != 2} {
        error "Callback must be a list of two elements: the mode and the target."
    }

    foreach "mode target" $callback {}
    switch -- $mode {
        "dcc" {
            putdcc $target $message
        }

        "chan" {
            if {[llength $target] != 2} {
                error "Target for chan mode must be a list of two elements: the channel and the nick."
            }

            foreach "chan nick" $target {}
            putserv "PRIVMSG $chan :$nick, $message"
        }

        default {
			error "Unknown mode: $mode"
		}
    }
}

proc get_putbymode_chan_callback {chan nick}  {
    list chan [list $chan $nick]
}
