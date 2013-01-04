bind pub -  .config	pub:config
bind dcc -   config	dcc:config

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
		foreach ($value as $k => $v) {
			$values[] = "$k => $v";
		}
		echo implode(' / ', $values);
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
