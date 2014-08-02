#
# VT100 server
#

listen [registry get bbs.vt100.port] script listen:vt100
set protect-telnet 0

proc listen:vt100 {newidx} {
	putcmdlog "Serving vt100 for idx $newidx."
	listen:vt100:welcome $newidx
	control $newidx control:vt100
}

proc listen:vt100:welcome {idx} {
	#Menu files in 3 cols
	set txtroot [registry get bbs.vt100.txtroot]
	set files [split [glob $txtroot/*.vt]]
	set pos [strlen $txtroot]
	set cols 3
	set rows  [expr [llength $files].0 / $cols]
	set rowsc [expr ceil($rows)]
	set rows  [expr floor($rows)]
	for {set i 0} {$i < $rowsc} {incr i} {
		set line ""
		for {set j 0} {$j < $cols} {incr j} {
			set item [string range [lindex $files [expr int ($i + $j * $rows)]] $pos+1 end-3]
			append line [completestring $item 24]
		}
		putdcc $idx $line
	}
	putdcc $idx [string repeat _ 72]
	putdcc $idx "Text to read: "
	return 1
}

#Plays the relevant file to $idx, cleans and exit
proc vt100:play {idx} {
	putcmdlog "(vt100) Playing file for idx $idx"
	global vt100
	set txtroot [registry get bbs.vt100.txtroot]

	set fd [open $txtroot/[dict get $vt100($idx) file].vt r]
	set i 0
	while {![eof $fd] && $i < 1000} {
		#Wait time: 0.0005s	
		putdcc $idx [gets $fd]
		after 3
		incr i
	}
	if {$i == 5000} {
		putdcc $idx "Stop at 5000th line."
		putcmdlog "(vt100) Stopping at 5000th line for idx $idx"
	}
	close $fd
	putcmdlog "(vt100) End play file for idx $idx"

	#Cleans and exit
	unset vt100($idx)
	killdcc $idx
}

#Controls the telnet connection
proc control:vt100 {idx text} {
	global vt100
	set txtroot [registry get bbs.vt100.txtroot]
	if ![info exists vt100($idx)] {
		if [file exists $txtroot/$text.vt] {
			#Reads file
			set vt100($idx) [dict create file $text]

			#Prints file
			vt100:play $idx
		} {
			putdcc $idx "Not a valid file"
		}
	} {
		switch $text {
			exit {
				putdcc $idx "Ja mata!"

				#Cleans and exit
				unset vt100($idx)
				return 1
			}
			default {
				putdcc $idx "Unknown command: $text"
			}
		}
	}
	return 0
}
