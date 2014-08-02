# .tcl source scripts/Daeghrefn/MediaWiki.tcl
#
# MediaWiki RC 
#

#
# Configuration
# 
set MediaWikiRC(source) 127.0.0.1
set MediaWikiRC(port) 8676
set MediaWikiRC(channel) #wolfplex
set MediaWikiRC(color) 0
set MediaWikiRC(warnKnownEditorsChanges) 0

# This code implements "A simple UDP server"
# sample from http://tcludp.sourceforge.net/
package require udp

#Gets editor
proc get_editor {message} {
	set message [stripcodes abcgru $message]
	regexp "\\* (.*?) \\*" $message match0 match1
	if {![info exists match1]} {
		return ""
	}
	return $match1
}

#Checks if editor is known
proc is_known_editor {editor} {
	expr {$editor == "Dereckson" || $editor == "Spike"}
}

#Handles UDP event from $sock
proc mediawiki_rc_udp_event_handler {sock} {
    global MediaWikiRC
    set pkt [read $sock]
    set peer [fconfigure $sock -peer]
    #Check if peer is source IP to avoid flood
    if {[string range $peer 0 [string length $MediaWikiRC(source)]-1] == $MediaWikiRC(source)} {
        #putdebug "Received on udp: $pkt"
	#putdebug "Editor: [get_editor $pkt]"
        if {$MediaWikiRC(warnKnownEditorsChanges) || ![is_known_editor [get_editor $pkt]]} {
            if $MediaWikiRC(color) {
                puthelp "PRIVMSG $MediaWikiRC(channel) :$pkt"
            } {
                puthelp "PRIVMSG $MediaWikiRC(channel) :[stripcodes abcgru $pkt]"
            }
        } 
    } {
            putdebug "$peer: [string length $pkt] {$pkt}"
    }
    return
}

#Listens UDP on $port
proc mediawiki_rc_udp_listen {port} {
    set srv [udp_open $port]
    putdebug "UDP connection on port $port: $srv"
    fconfigure $srv -buffering none -translation binary
    fileevent $srv readable [list ::mediawiki_rc_udp_event_handler $srv]
    #putdebug "Listening on udp port: [fconfigure $srv -myport]"
    return $srv
}

mediawiki_rc_udp_listen $MediaWikiRC(port)
