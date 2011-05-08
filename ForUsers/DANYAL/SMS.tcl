package require http

bind pub  - !sms        pub:sms
bind pub  - .sms        dcc:sms

#Accounts
#set sms(<nickname>) {<url> <form password>}
set sms(dereckson) {http://dereckson.devio.us/sms.php rose}
set sms(DANYAL) {http://rockpaki.net/ 4}

#
# SMS
#

#Sends a SMS to $to with $message as text and $from as source
#Returns "" if SMS were sent, the error message otherwise
proc sendsms {from to message} {
	#Gets params
	global sms
	if [info exists sms($to)] {
		foreach "url pass" $sms($to) {}
	} {
		return "$to doesn't have enabled SMS feature."
	}

	#Check length
	set len [string length $from$message]
	if {$len > 113} {
		return "Message too long, drop [expr $len-113] chars]."
	}

	#Posts form
	package require http
	set query [::http::formatQuery m $from p $message v $pass envoi Envoyer]
	set tok [::http::geturl $url -query $query]
	set result [::http::data $tok]
	::http::cleanup $tok

	#Parses reply
	if {[string first "Impossible d'envoyer" $result] != -1 || [string first "There is an error" $result] != -1} {
		return "Can't send a SMS, according the web form."
	} elseif {[string first "Tu as subtilement" $result] != -1 || [string first "forget to write" $result] != -1} {
		return "Incorrect pass: $pass, check on $url if the antispam question haven't been modified."
	} elseif {[string first "envoi \[ Ok \]" $result] != -1 || [string first "our message have been sent with success" $result] != -1} {
		return ""
	} {
		return "I can't determine from the SMS web form reply if the message have been sent or not."
	}
}

proc dcc:sms {handle idx arg} {
	#Sends a SMS
	set to [lindex $arg 0]
	#TODO: use a proc to remove the first word instead and keep $arg as string
	set message [lrange $arg 1 end]
	if {[set result [sendsms $handle $to $message]] == ""} {
		putdcc $idx "SMS sent."
		putcmdlog "#$handle# sms ..."
	} {
		putdcc $idx $result
	}
	return 0
}

#!sms
proc pub:sms {nick uhost handle chan text} {
	#Sends a SMS
	if {$handle == "" || $handle == "*"} {
		set from $nick
	} {
		set from $handle
	}
	set to [lindex $text 0]
	#TODO: use a proc to remove the first word instead and keep $arg as string
	set message [lrange $text 1 end]
	if {[set result [sendsms $from $to $message]] == ""} {
		putquick "PRIVMSG $chan :$nick, SMS sent."
		putcmdlog "!$nick! sms ..."
	} {
		putquick "PRIVMSG $chan :$nick, $result."
	}
	return 0
}
