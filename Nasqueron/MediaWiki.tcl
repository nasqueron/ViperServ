#
# MediaWiki RC 
#

#
# Configuration
# 
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
    #TODO check if peer is 127.0.0.1 if there is somme flood
    #putdebug "$peer: [string length $pkt] {$pkt}"
    if $MediaWikiRC(color) {
         puthelp "PRIVMSG $MediaWikiRC(channel) :$pkt"
    } {
         puthelp "PRIVMSG $MediaWikiRC(channel) :[stripcodes abcgru $pkt]"
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
