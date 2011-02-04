package require http

bind dcc  -  sms	dcc:sms
bind pub  - !sms        pub:sms
bind pub  - !identica	pub:identica
bind pub  - !pub	pub:identica
bind pub  - !twit	pub:identica

#
# SMS
#

#Sends a SMS to $to with $message as text and $from as source
#Returns "" if SMS were sent, the error message otherwise
proc sendsms {from to message} {
	switch [set mode [registry get sms.$to.mode]] {
		1 {
			#Triskel/Wolfplex form
			set url [registry get sms.$to.url]
			set pass [registry get sms.$to.pass]
			set xtra [registry get sms.$to.xtra]
			if {$url == ""} {return "URL inconnue pour $to"}
			
			#Check length
			set len [string length $from$message]
			if {$len > 113} {
				return "Message trop long, réduisez-le de [expr $len-113] caractère[s $len-113]."
			}

			#Posts form
			package require http
			set query [::http::formatQuery m $from p $message v $pass envoi Envoyer]
			if {$xtra != ""} {append query &$xtra}
			set tok [::http::geturl $url -query $query]
			set result [::http::data $tok]
			::http::cleanup $tok

			#Parses reply
			if {[string first "Impossible d'envoyer" $result] != -1} {
				return "Le formulaire web indique qu'il est immpossible d'envoyer le message."
			} elseif {[string first "Tu as subtilement" $result] != -1} {
				return "Pass incorrect : $pass, regardez sur $url si la question antibot n'a pas été modifiée."
			} elseif {[string first "envoi \[ Ok \]" $result] != -1} {
				return ""
			} {
				putdebug $result
				return "D'après la réponse du formulaire, il n'est pas possible de déterminer si oui ou non il a été envoyé."
			}
		}

		"" {
			return "$to n'a pas activé la fonction SMS."
		}

		default {
			return "Unknown sms mode: $mode."
		}	
	}
}

#.sms
proc dcc:sms {handle idx arg} {
	# The SMS configuration is stored in the following registry variables:
	# sms.$destinataire.mode	1 Triskel or Wolfplex form
	#
	# For mode 1:
	# sms.$destinataire.url		form URL
	# sms.$destinataire.pass	e.g. rose
	# sms.$destinataire.xtra	not needed for triskel forms, who=Darkknow needed for Wolfplex form
	
	if {$arg == "" || $arg == "config"} {
		#Prints config
		switch [set mode [registry get sms.$handle.mode]] {
			1 {
				putdcc $idx "URL ..... [registry get sms.$handle.url]"
				if {[set pass [registry get sms.$handle.pass]] != ""]} {
					putdcc $idx "Pass .... $pass"
				}
				if {[set xtra [registry get sms.$handle.xtra]] != ""} {
					putdcc $idx "Extra ... $xtra"
				}
			}
			"" {
				putdcc $idx "Vous n'avez pas encore configuré votre fonctionnalité SMS."
			}
			default {
				putdcc $idx "Unknown sms mode: $mode"
			}
		}
		return 1
	} elseif {[string range $arg 0 6] == "config "} {
		putdcc $idx "Le script interactif de configuration n'est pas encore prêt."
		putcmdlog "#$handle# sms config ..."
		return 0
	} else {
		#Sends a SMS
		set to [lindex $arg 0]
		#TODO: use a proc to remove the first word instead and keep $arg as string
		set message [lrange $arg 1 end]
		if {[set result [sendsms $handle $to $message]] == ""} {
			putdcc $idx "Envoyé."
			putcmdlog "#$handle# sms ..."
		} {
			putdcc $idx $result
		}
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
		putquick "PRIVMSG $chan :$nick, c'est envoyé."
		putcmdlog "!$nick! sms ..."
	} {
		putquick "PRIVMSG $chan :$nick, $result."
	}
	return 0
}

#
# Identi.ca
#

#Posts $message on the identi.ca $account account
proc identicapost {account message} {
	set row [lindex [sql "SELECT account_username, account_password FROM identica_accounts WHERE account_code = '$account'"] 0]
	set auth "Basic [base64::encode [join $row :]]"
	set tok [::http::geturl http://identi.ca/api/statuses/update.xml -headers [list Authorization $auth] -query [::http::formatQuery status $message]]
	::http::cleanup $tok
}

#.identica
proc dcc:identica {handle idx arg} {
	
}

#!pub !identica or !twit
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
