# Geographical data procs

bind pub - !fantoir pub:fantoir
bind dcc -  fantoir dcc:fantoir

namespace eval fantoir {
	#Path to the FANTOIR file
	variable file_all [registry get fantoir.files.all]

	#Path to the FANTOIR file, containing only streets
	variable file_streets [registry get fantoir.files.streets]

	# Performs a search
	#
	# @param text The text to search
	# @return the number of lines in the file matching the expression
	proc search {text} {
		variable file_all
		variable file_streets

		if {[catch {set count_all [exec -- grep -a -c "$text" $file_all]}]} {
			set count_all 0
		}
		set count_all [string trim $count_all]
		set reply "$count_all occurrence[s $count_all]"
		if {$count_all > 0} {
			if {[catch {set count_voies [exec -- grep -a -c "$text" $file_streets]}]} {
				set count_voies 0
			}
			set count_voies [string trim $count_voies]
			append reply "(dont $count_voies voie[s $count_voies])"
		} {
			return $reply
		}
	}

	# Determines if a search expression is valid
	#
	# @param $expression The expression to check
	# @return 1 if the expression is valid; otherwise, 0
	proc is_valid_search_expression {expression} {
		#TODO: allow some regexp
		expr [regexp "^\[A-Z0-9 ]*\$" $expression] && [string length $expression] < 100
	}
}

# Handles fantoir dcc bind
proc dcc:fantoir {handle idx arg} {
	set text [string toupper $arg]
	if {![::fantoir::is_valid_search_expression $text]} {
		putdcc $idx "Format incorrect, !fantoir <chaîne de texte à rechercher, sans accent>"
		return 0
	}
	putdcc $idx [::fantoir::search $text]
	return 1
}

# Handles !fantoir pub bind
proc pub:fantoir {nick uhost handle chan text} {
	set text [string toupper $text]
	if {![::fantoir::is_valid_search_expression $text]} {
		puthelp "NOTICE $nick :Format incorrect, !fantoir <chaîne de texte à rechercher, sans accent>"
		return 0
	}
	putserv "PRIVMSG $chan :$nick: [::fantoir::search $text]"
	return 1
}
