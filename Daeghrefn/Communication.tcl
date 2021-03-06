bind dcc  -  sms	dcc:sms
bind dcc  -  mail	dcc:mail
bind dcc  -  twitter	dcc:twitter
bind pub  - !sms        pub:sms
bind pub  - !identica	pub:identica
bind pub  - !pub	pub:twitter
bind pub  - !twit	pub:twitter
bind pub  - !tweet	pub:twitter
bind pub  - !idee	pub:idee
bind pub  - !idees	pub:idee
bind pub  - !idée       pub:idee
bind pub  - !ideert	pub:ideert
bind pub  - !idéert	pub:ideert
bind pub  - !idee-rt	pub:ideert
bind pub  - !idée-rt	pub:ideert
bind pub  - !styleencyclo pub:styleencyclo
bind pub  - !style        pub:styleencyclo

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
# Identi.ca and Twitter
#

#Posts $message on the identi.ca $account account
proc identicapost {account message} {
	package require base64
	set row [lindex [sql "SELECT account_username, account_password FROM identica_accounts WHERE account_code = '$account'"] 0]
	set auth "Basic [base64::encode [join $row :]]"
	set tok [::http::geturl http://identi.ca/api/statuses/update.xml -headers [list Authorization $auth] -query [::http::formatQuery status $message]]
	#putdebug [::http::data $tok]
	::http::cleanup $tok
}

#Posts $message on the Twitter $account account
proc twitterpost {account message} {
	set status_url "https://api.twitter.com/1.1/statuses/update.json"
	if {[catch {twitter_query $status_url $account [list status $message]} error]} {
		putdebug "Twitter error: $error"
		return 0
	}
	return 1
}

#Gets the Twitter OAuth token
proc twitter_token {account} {
	registry get twitter.oauth.tokens.$account
}

proc dcc:twitter {handle idx arg} {
	set command [lindex $arg 0]
	switch $command {
		"setup" {
			set account [lindex $arg 1]
			if {$account == ""} {
				putdcc $idx "What account to setup?"
				return 0
			}
			if {[twitter_token $account] != ""} {
				switch [lindex $arg 2] {
					"--force" { registry del twitter.oauth.tokens.$account }
					"" {
						putdcc $idx "There is already a token set for this account. Please use '.twitter setup $account --force' to erase it."
						return 0
					}
				}
			}
			set pin [lindex $arg 2]
			if {$pin == "" || $pin == "--force"} {
				#Initializes requests
				if {[catch {oauth::get_request_token {*}[registry get twitter.oauth.consumer]} data]} {
					putdebug "Can't request OAuth token for Twitter $account account: $data"
					putdcc $idx "An error occured, I can't request an OAuth token for you account."
					return 0
				} {
					registry set twitter.oauth.tokens.$account "[dict get $data oauth_token] [dict get $data oauth_token_secret]"
					putdcc $idx "Step 1 — Go to [dict get $data auth_url]"
					putdcc $idx "Step 2 — .twitter setup $account <the PIN code>"
					return 1
				}
			} {
				#Saves token
				if {[catch {oauth::get_access_token {*}[registry get twitter.oauth.consumer] {*}[twitter_token $account] $pin} data]} {
					putdebug "Can't confirm OAuth token for Twitter $account account: $data"
					putdcc $idx "An error occured, I can't confirm an OAuth token for you account."
					return 0
				} {
					registry set twitter.oauth.tokens.$account "[dict get $data oauth_token] [dict get $data oauth_token_secret]"
					putdcc $idx "Ok, I've now access to account [dict get $data screen_name]."
					putcmdlog "#$handle# twitter setup $account ..."
					return 0
				}
			}
		}

		"reconfigure" {
			twitter_update_short_url_length
			return 1
		}

		default { putdcc $idx "Unknown Twitter command: $arg"}
	}
}

#Sends a query
proc twitter_query {url account {query_list {}} {method {}}} {
	# Uses POST for any query
	if {$method == ""} {
		if {$query_list == ""} {
			set method GET
		} {
			set method POST
		}
	}
	if {$method == "GET" && $query_list == ""} {
		append url ?
		append url [http::formatQuery {*}$query_list]
	}

	# Requests
	set token [twitter_token $account]
	if {$token == ""} {
		error "Unidentified Twitter account: $account"
	} {
		set reply [oauth::query_api $url {*}[registry get twitter.oauth.consumer] $method {*}$token $query_list]
		json::json2dict $reply
	}
}

#.identica
proc dcc:identica {handle idx arg} {

}

# Publishes to special accounts
proc pub:idee {nick uhost handle chan text} {
	twitter_pub_publish_to_account ideedarticles $nick $text
}

proc pub:styleencyclo {nick uhost handle chan text} {
	twitter_pub_publish_to_account styleencyclo $nick $text
}

proc twitter_pub_publish_to_account {account nick text} {
	set who [whois $nick]
	if {$who == ""} {
		append text " – via IRC."
	} {
		append text " – $who, via IRC."
	}
	twitterpublish $account $nick $text
}

#!ideert
proc pub:ideert {nick uhost handle chan text} {
	set status ""
	if {[twitter_try_extract_status $text status]} {
		twitter_retweet ideedarticles $status
		return 1
	} {
		return 0
	}
}

#!identica
proc pub:identica {nick uhost handle chan text} {
	putquick "NOTICE $nick :!identica is currently disabled. Is identi.ca still usable since pump.io migration? If so, please request the command."
}

#!pub or !twit or !tweet
#The account is channel dependant
proc pub:twitter {nick uhost handle chan text} {
	set account [registry get twitter.channels.$chan.account]
	set is_protected [registry get twitter.channels.$chan.protected]

	if {$account == ""} {
		putquick "NOTICE $nick :!pub isn't n'est pas activé sur le canal $chan / !pub isn't enabled on channel $chan"
		return
	}

	if {$is_protected == "1"} {
		set who [whois $nick]
		if {$who == ""} {
			putquick "NOTICE $nick :Pour utiliser !pub sur $chan, vous devez disposer d'un cloak projet ou unaffiliated, être connecté depuis un host sans chiffre ou encore avoir votre user@host reconnu par mes soins."
			return 0
		} {
			append text " — $who"
		}
	}

	twitterpublish $account $nick $text
}

proc twitter_message_len {} { return 140 }

proc twitterpublish {account nick text} {
	if {$text == ""} {
		putquick "NOTICE $nick :Syntaxe : !pub <texte à publier sur identi.ca et Twitter>"
		return
	}
	set len [twitter_compute_len $text]
	if {$len > [twitter_message_len]} {
		putquick "NOTICE $nick :[twitter_message_len] caractères max, là il y en a $len ([twitter_get_short_url_length] par lien)."
		return
	}
	if [twitterpost $account $text] {
		putquick "NOTICE $nick :Publié sur Twitter"
		return 1
	} {
		putquick "NOTICE $nick :Non publié, une erreur a eu lieu."
	}
}

# Extracts the id of the status from an URL or directly from this ID
#
# @param text The text containing the status ID
# @param If successful, will be set to the id of the status to retweet
# @return 1 if successful; otherwise, 0
proc twitter_try_extract_status {text status} {
	upvar 1 $status value

	# Trivial case: value is already the status identifier
	if {[isnumber $text]} {
		set value $text
		return 1
	}

	regexp "twitter\.com/.*/status/(\[0-9\]+)" $text matches value
}

# Retweets a status
#
# @param account The retweeting account username
# @param status The id of the status to retweet
# @return The API reply, as a dictionary
proc twitter_retweet {account status} {
	set url https://api.twitter.com/1.1/statuses/retweet/$status.json
	twitter_query $url $account "" POST
}

# @param param The parameter to fetch in the API reply
# return The value from configuration the JSON document, or a dict if it contains several parameters
proc twitter_get_configuration_parameter {param} {
	set account [registry get twitter.default_account]
	set url https://api.twitter.com/1.1/help/configuration.json
	set config [twitter_query $url $account]
	dict get $config $param
}

proc twitter_update_short_url_length {} {
	set len [twitter_get_configuration_parameter short_url_length]
	registry set twitter.short_url_length $len
}

proc twitter_get_short_url_length {} {
	registry get twitter.short_url_length
}

# Computes len of a tweet, taking in consideration t.co URL length
# See https://dev.twitter.com/basics/tco
proc twitter_compute_len {text} {
	set short_url_length [twitter_get_short_url_length]

	set len [strlen $text]
	foreach url [geturls $text] {
		incr len [expr $short_url_length - [strlen $url]]
	}
	return $len
}

#
# Mail
#

# .mail
proc dcc:mail {handle idx arg} {
        global mail special
        if {$arg == ""} {
            putdcc $idx "## Syntaxe : .mail <destinataire> \[objet\]"
            return
        } elseif {[validuser [lindex $arg 0]]} {
            set mail($idx-to) [getuserinfo [lindex $arg 0] user_email]
        } elseif {[regexp {^[A-Za-z0-9._-]+@[[A-Za-z0-9.-]+$} [lindex $arg 0]]} {
            set mail($idx-to) [lindex $arg 0]
        } else {
            putdcc $idx "Destinataire invalide : [lindex $arg 0]"
            return
        }
        set mail($idx) ""
        putdcc $idx "\002Alors, que désires tu envoyer comme mail ?\002"
        putdcc $idx "Pour envoyer l'e-mail, entre une ligne ne contenant que ceci: \002+\002"
        putdcc $idx "Pour annuler l'e-mail, entre une ligne ne contenant que ceci: \002-\002"

        set mail($idx-subject) [truncate_first_word $arg]
        if {$mail($idx-subject) == ""} {
            putdcc $idx "\002Objet :\002"
        } else {
            putdcc $idx "\002Message :\002"
        }

        control $idx control:mail
        dccbroadcast "Tiens, $handle est parti rédiger un mail ..."
}

# Controls mail encoding processus
proc control:mail {idx text} {
        global mail
        if {$text == "+"} {
                mail.send $mail($idx-to) $mail($idx-subject) $mail($idx) [getuserinfo $idx user_email]
                unset mail($idx)
                putdcc $idx "Envoyé :-)"
                dccbroadcast "Et, hop, un mail d'envoyé pour [idx2hand $idx] :)"
                return 1
        } elseif {$text == "-"} {
                unset mail($idx)
                dccbroadcast "[idx2hand $idx] vient de changer d'avis et revient."
                putdcc $idx "Ok, le mail a été annulé: retour au party line !"
                return 1
        } elseif {$mail($idx-subject) == ""} {
                set mail($idx-subject) $text
                putdcc $idx "\002Message :\002"
        } else {
                regsub -all {\\} $text "\\\\\\" text
                regsub -all "'" $text "\\'" text
                append mail($idx) "\n$text"
        }
}

# Sends a mail
#
# @param to The recipient
# @param subject The mail subject
# @param message The message to send
# @param from The mail author (optional)
proc mail.send {to subject message {from {}}} {
        set fd [open "|sendmail -t" w]
        if {$from != ""} {
                puts $fd "From: $from"
        }
	puts $fd "To: $to"
	puts $fd "Subject: $subject"
	puts $fd
        puts $fd "$message"
        flush $fd
        close $fd
}
