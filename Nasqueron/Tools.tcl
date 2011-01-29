# Collection of tools and gadgets, to boost
# your productivity or to have fun.

bind dcc - genpass dcc:genpass
bind dcc - strlen  dcc:strlen

#
# .genpass <master password> <domain name>
# www.supergenpass.com/genpass legacy generator
#

proc genpass {master domain} {
	string range [md5 "$master:$domain"] 0 8
}

proc dcc:genpass {handle idx arg} {
	if {[llength $arg] != 2} {
		putdcc $idx "Usage: .genpass <master password> <domain name>"
	} {
		putcmdlog "#$handle# genpass ..."
		putdcc $idx [genpass [lindex $arg 0] [lindex $arg 1]]
	}
	return 0
}

#
# .strlen <string>
# Gets the specified string's length
#

proc dcc:strlen {handle idx arg} {
	putdcc $idx [string length $arg]
	putcmdlog "#$handle# strlen ..."
	return 0
}
