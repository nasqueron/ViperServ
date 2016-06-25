bind pub -  .config	pub:config
bind dcc -   config	dcc:config
bind pub D  .+surname   pub:surname
bind dcc D   +surname   dcc:surname
bind pub D  .+nom       pub:surname
bind dcc D   +nom       dcc:surname
bind pub D  .+prenom    pub:givenname
bind dcc D   +prenom    dcc:givenname
bind pub D  .+prénom    pub:givenname
bind dcc D   +prénom    dcc:givenname
bind pub D  .+givenname pub:givenname
bind dcc D   +givenname dcc:givenname

#
# Wikidata
#

# Handles .+surname command
proc pub:surname {nick uhost handle chan arg} {
	if {[isAcceptableItemTitle $arg]} {
		create_surname $arg "serv $chan"
		return 1
	} {
		putserv "PRIVMSG $chan :$nick : ne sont gérés comme que les caractères alphanumériques, le tiret, l'apostrophe droite, de même que tout ce qui n'est pas ASCII standard."
	}
	return 0
}

# Handles .+surname command
proc dcc:surname {handle idx arg} {
	if {[isAcceptableItemTitle $arg]} {
		create_surname $arg "dcc $idx"
		return 1
	} {
		putdcc $idx "crée cet item manuellement, je ne suis pas conçu pour gérer ces caractères dans le titre."
	}
	return 0
}

# Creates a surname
# @param $title the item title
# @param $state the state to pass to the create command callback (here with a mode and a target to print result)
proc create_surname {title state} {
	run_command "[get_external_script create_surname] [posix_escape $title]" print_command_callback $state
}

# Handles .+givenname command
proc pub:givenname {nick uhost handle chan arg} {
	set params [split $arg]
	if {[llength $params] > 1} {
		set title [lindex $params 0]
		set genre [string toupper [lindex $params 1]]
		switch -- $genre {
			M {}
			F {}
			D {}
			U {}
			E {set genre U}
			default {
				puthelp "PRIVMSG $chan :Attendu : F (féminin), M (masculin), U (épicène) — e.g. .+prenom Aude F"
				return 0
			}
		}
	} {
		set title $arg
		set genre D
	}
	if {[isAcceptableItemTitle $title]} {
		create_givenname $title $genre "serv $chan"
		return 1
	} {
		puthelp "PRIVMSG $chan :$nick : crée cet item manuellement, je ne suis pas conçu pour gérer ces caractères dans le titre."
	}

}

# Handles .+givenname command
proc dcc:givenname {handle idx arg} {
	set params [split $arg]
	if {[llength $params] > 1} {
		set title [lindex $params 0]
		set genre [string toupper [lindex $params 1]]
		switch -- $genre {
			M {}
			F {}
			D {}
			U {}
			E {set genre U}
			default {
				putdcc $idx "Attendu : F (féminin), M (masculin), U (épicène) — e.g. .+prenom Aude F"
				return 0
			}
		}
	} {
		set title $arg
		set genre D
	}
	if {[isAcceptableItemTitle $title]} {
		create_givenname $title $genre "dcc $idx"
		return 1
	} {
		putdcc $idx "crée cet item manuellement, je ne suis pas conçu pour gérer ces caractères dans le titre."
	}
}

# Creates a given name
# @param $title the item title
# @param $state the state to pass to the create command callback (here with a mode and a target to print result)
proc create_givenname {title genre state} {
	run_command "[get_external_script create_given_name] [posix_escape $title] $genre" print_command_callback $state
}

# Determines if the specified title is suitable to pass as shell argument
# @param $title The title to check
# @return 0 is the title is acceptable; otherwise, false.
proc isAcceptableItemTitle {title} {
	set re {[A-Za-z \-']}
	foreach char [split $title {}] {
		set value [scan $char %c]
		if {$value < 128} {
			#ASCII
			if {![regexp $re $char]} { return 0 }
		}
		#UTF-8 ok
	}	
	return 1
}


#
# Wikimedia configuration files
#

# Handles .config pub command
proc pub:config {nick uhost handle chan arg} {
	if {[llength $arg] < 2} {
		puthelp "NOTICE $nick :Usage: .config <setting> <project>"
		return 0
	}
	putserv "PRIVMSG $chan :[wikimedia::get_config_variable [lindex $arg 0] [lindex $arg 1] [lrange $arg 2 end]]"
	return 1
}

# Handles .config dcc command
proc dcc:config {handle idx arg} {
	if {[llength $arg] < 2} {
		putdcc $idx "Usage: .config <setting> <project>"
		return 0
	}
	putdcc $idx [wikimedia::get_config_variable [lindex $arg 0] [lindex $arg 1] [lrange $arg 2 end]]
	return 1
}

namespace eval ::wikimedia {
	# Script to get a configuration variable
	set get_config_script {
<?php
	error_reporting(0);
	require_once('%%dir%%/wmf-config/InitialiseSettings.php');
	$value = $wgConf->settings%%key%%;
	if (is_array($value)) {
		$values = array();
		if (array_keys($value) !== range(0, count($value) - 1)) {
			//Associative arary
			foreach ($value as $k => $v) {
				$values[] = "$k => $v";
			}
			echo implode(' / ', $values);
		} else {
			//Numeric array
			echo implode(', ', $value);
		}
	} else if (is_bool($value)) {
		echo $value ? 'true' : 'false';
	} else {
		echo $value;
	}
?>
	}

	# Gets a configuration variable, defined in $wgConf aray
	#
	# @param $setting the config variable's name
	# @param $project the project
	# @param $args If the config variable is an array, the keys to get (facultative, specify how many you want)
	# @return the config value
	proc get_config_variable {setting project args} {
		if {[string index $setting 0] == "\$"} {
			set setting [string rang $setting 1 end]
		}
		if {![regexp "^\[a-z]\[A-Za-z0-9]*$" $setting]} {
			return "Not a valid setting: $setting"
		}
		
		if {![regexp "^\[a-z]\[a-z0-9_]*$" $project]} {
			return "Not a valid project: $project"
		}
		set key "\['$setting']\['$project']"
		foreach arg $args {
			if {$arg == ""} break
			if {![regexp "^\[A-Za-z0-9]*$" $arg]} {
				return "Not a valid setting: $arg"
			}
			append key "\['$arg']"
		}
		set code [string map [list %%key%% $key %%dir%% [registry get repositories.operations.mediawiki-config]] $wikimedia::get_config_script]
		exec_php $code
	}

	# Executes inline PHP code
	#
	# @param code The PHP code to execute
	# @return the script stdout
	proc exec_php {code} {
		string trim [exec -- echo $code | php]
	}
}
