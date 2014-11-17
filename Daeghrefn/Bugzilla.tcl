# .tcl source scripts/Daeghrefn/Bugzilla.tcl

package require XMLRPC
package require SOAP
package require rpcvar

bind dcc - bug dcc:bug

#
# Bugzilla structures
#

namespace import -force rpcvar::typedef

typedef {
   login	string
   password	string
   remember	boolean
} userLoginRequest

#
# Bugzilla libraries
#

namespace eval ::Bugzilla:: {
	proc endpoint {server} {
		return [registry get bugzilla.$server.url]/xmlrpc.cgi
	}

	proc login {server} {
		global errorInfo
		if [catch { ::Bugzilla::${server}::UserLogin [list \
			login		[registry get bugzilla.$server.username] \
			password	[registry get bugzilla.$server.password] \
			remember	1 \
		] } reply] {
			error [lindex [split $errorInfo \n] 0]
		}
		return $reply
	}

	proc version {server} {
		::Bugzilla::${server}::BugzillaVersion
	}
}

#
# XML-RPC procedures
#

foreach bzServer [registry get bugzilla.servers] {
	namespace eval ::Bugzilla::${bzServer} { }
	XMLRPC::create ::Bugzilla::${bzServer}::UserLogin -name "User.login" -proxy [Bugzilla::endpoint $bzServer] -params {login userLoginRequest}
	XMLRPC::create ::Bugzilla::${bzServer}::BugzillaVersion -name "Bugzilla.version" -proxy [Bugzilla::endpoint $bzServer]
}

#
# Userland
#

proc dcc:bug {handle idx arg} {
	
}