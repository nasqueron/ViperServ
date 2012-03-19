#
# MediaWiki RC 
#

#
# Configuration
# 
set MediaWikiRC(source) 127.0.0.1
set MediaWikiRC(port) 8675
set MediaWikiRC(channel) #wolfplex
set MediaWikiRC(color) 0

# This code implements "A simple UDP server"
# sample from http://tcludp.sourceforge.net/
package require udp

#Handles UDP event from $sock
proc mediawiki_rc_udp_event_handler {sock} {
    global MediaWikiRC
    set pkt [read $sock]
    set peer [fconfigure $sock -peer]
    #Check if peer is source IP to avoid flood
    if {[string range $peer 0 [string length $MediaWikiRC(source)]-1] == $MediaWikiRC(source)} {
        if $MediaWikiRC(color) {
            puthelp "PRIVMSG $MediaWikiRC(channel) :$pkt"
        } {
            puthelp "PRIVMSG $MediaWikiRC(channel) :[stripcodes abcgru $pkt]"
        }
    } {
            putdebug "$peer: [string length $pkt] {$pkt}"
    }
    return
}

#Listens UDP on $port
proc mediawiki_rc_udp_listen {port} {
    set srv [udp_open $port]
    fconfigure $srv -buffering none -translation binary
    fileevent $srv readable [list ::mediawiki_rc_udp_event_handler $srv]
    #putdebug "Listening on udp port: [fconfigure $srv -myport]"
    return $srv
}

mediawiki_rc_udp_listen $MediaWikiRC(port)
