#
# This eggdrop TCL script lets you print channel users on a web page.
#

#
# Configuration
# Paths are relative to eggdrop 
#

#The channel to save
set chanlist2html(channel) #wolfplex

#The HTML file to write
set chanlist2html(file) users.html

#The HTML template
#Remplace the list code by %%chanlist%%
set chanlist2html(tmpl) users.tmpl

#The interval to regenerate the page in minutes
set chanlist2html(time) 5

#
# Helper procs
#

#Generates a <ul><li>...<li><li>...<li></ul> HTML code from a list
proc list2ul {list {lineprefix ""}} {
	set html "${lineprefix}<ul>\n"
	foreach item $list {
		append html "${lineprefix}\t<li>${item}</li>\n"
	}
	append html "${lineprefix}</ul>"
}

#Writes $target with the $channel users list from $template
proc chanlist2html_write {channel template target} {
	if [file exists $template] {
		set fd [open $template r]
		while {![eof $fd]} {
			append buffer [gets $fd]
		}
		close $fd
	} {
		set buffer "%%chanlist%%"
	}
	set fd [open $target w]
	set chanlist [list2ul [chanlist $channel]]
	puts $fd [string map [list %%chanlist%% $chanlist] $buffer]
	flush $fd
	close $fd
}

#
# Timer
# 

proc chanlist2html {} {
	global chanlist2html
	chanlist2html_write $chanlist2html(channel) $chanlist2html(tmpl) $chanlist2html(file)
	timer $chanlist2html(time) chanlist2html
}

chanlist2html
