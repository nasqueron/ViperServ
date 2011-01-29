package require http

bind dcc  -  sms	dcc:sms
bind pub  - !identica	pub:identica
bind pub  - !pub	pub:identica
bind pub  - !twit	pub:identica

#
# SMS
#

#.sms
proc dcc:sms {handle idx arg} {
	if {$arg == "" || $arg == "config"} {
		#Prints config
		return 1
	} elseif {[string range $arg 0 6] == "config "} {
		putcmdlog "#$handle# sms config ..."
		return 0
	} else {
		#Sends a SMS
		set to [lindex $arg 0]
		putcmdlog "#$handle# sms ..."
	}
	return 0
}

#
# Identi.ca
#

proc identicapost {account message} {
	set row [lindex [sql "SELECT account_username, account_password FROM identica_accounts WHERE account_code = '$account'"] 0]
	set auth "Basic [base64::encode [join $row :]]"
	set tok [::http::geturl http://identi.ca/api/statuses/update.xml -headers [list Authorization $auth] -query [::http::formatQuery status $message]]
	::http::cleanup $tok
}

proc dcc:identica {handle idx arg} {
	
}

proc pub:identica {nick uhost handle chan text} {
	if {$chan == "#wikipedia-fr"} {
		set account wikipediafr
	} elseif {$chan == "#wolfplex"} {
		set account wolfplex
	} {
		putquick "NOTICE $nick :!pub n'est pas activésur $chan"
		return
	}
	if {$text == ""} {
		putquick "NOTICE $nick :Syntaxe : !pub <texte à publier sur identi.ca et Twitter>"
		return
	}
	set len [string length $text]
	if {$len > 140} {
		putquick "NOTICE $nick :140 caractères max, là il y en a $len."
		return
	}
	identicapost $account $text
	putquick "NOTICE $nick :Publié sur identi.ca"
	return 1
}
