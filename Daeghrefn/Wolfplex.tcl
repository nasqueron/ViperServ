bind pub  - !open	pub:open
bind pub  - !ouvert	pub:open
bind pub  - !close	pub:close
bind pub  - !closed	pub:close
bind pub  - !ferme	pub:close
bind pub  - !fermé	pub:close

proc pub:open {nick uhost handle chan text} {
	setisopen yes
}

proc pub:close {nick uhost handle chan text} {
	setisopen no
}

proc setisopen {status} {
	set query [::http::formatQuery oldid 0 wpTextbox1 $status wpSave Publier]
	set url "http://www.wolfplex.org/w/index.php?title=Mod%C3%A8le:IsOpen/status&action=edit"
	set tok [::http::geturl $url -query $query]
	set result [::http::data $tok]
	::http::cleanup $tok

	set fd [open debug.log w]
	puts $fd $result
	flush $fd
	close $fd
}
