#This script is included w/ 1.4.2 to update any bots still using bseen1.3.x
#It will bring 1.3.x databases up to spec for use with 1.4.x
set bs(updaterversion) 10402

###
#Bass's Seen script database updater from 1.3.x to 1.4.x 
#
#This file has no adjustable parameters.
#It should come as part of a larger package, including bseen1.4.x.tcl
#If you question the integrity of this file, get the distribution file:
#ftp://ftp.eggheads.org/pub/eggdrop/tcl.bass/bseen1.4.2.tar.gz

proc bsu_save {} {
  global bsu_list userfile bs; if {[array size bsu_list] == 0} {return 1}
  if {![string match */* $userfile]} {set name [lindex [split $userfile .] 0]} {
    set temp [split $userfile /] ; set temp [lindex $temp [expr [llength $temp]-1]] ; set name [lindex [split $temp .] 0]
  }
  if {[file exists bs_data.$name]} {catch {exec cp -f bs_data.$name bs_data.$name.bak}}
  set fd [open bs_data.$name w] ; set id [array startsearch bsu_list] ; putlog "     Saving updated records..."
  puts $fd "#$bs(updaterversion)"
  while {[array anymore bsu_list $id]} {set item [array nextelement bsu_list $id] ; puts $fd "$bsu_list($item)"} ; array donesearch bsu_list $id ; close $fd
  return 0
}
proc bsu_read {} {
  global bsu_list userfile
  if {![string match */* $userfile]} {set name [lindex [split $userfile .] 0]} {
    set temp [split $userfile /] ; set temp [lindex $temp [expr [llength $temp]-1]] ; set name [lindex [split $temp .] 0]
  }
  if {![file exists bs_data.$name]} {
    if {![file exists bs_data.$name.bak]} {
      putlog "     Old seen data not found!" ; return 1
    } {exec cp bs_data.$name.bak bs_data.$name ; putlog "     Old seen data not found! Using backup data."}
  } ; set fd [open bs_data.$name r]
  set bsu_version ""
  while {![eof $fd]} {
    set inp [gets $fd] ; if {[eof $fd]} {break} ; if {[string trim $inp " "] == ""} {continue}
    if {[string index $inp 0] == "#"} {set bsu_version [string trimleft $inp #] ; continue}
    set nick [lindex $inp 0] ; set bsu_list([string tolower $nick]) $inp
  } ; close $fd ; putlog "     Done loading [array size bsu_list] seen records."
}
putlog "$bs(version):  -- Bass's SEEN updater loaded --"

proc bsu_go {} {
  global bsu_list
  if {![info exists bsu_list] || [array size bsu_list] == 0} {putlog "     Loading seen database for updating..." ; bsu_read}
  if {![info exists bsu_list] || [array size bsu_list] == 0} {putlog "     No records found." ; return 1}
  set fix 0 ; set new 0 ; set list [array names bsu_list] ; set errors 0
  foreach item $list {
    set data $bsu_list($item)
    if {[lindex $data 3] == "nick"} {
      set tonick [bs_filt [lindex $data 5]] ; set ltonick [join [string tolower $tonick]]
      set ndata "$tonick [lrange [lreplace $data 3 3 rnck] 1 4] [bs_filt [lindex $data 0]]"
      if {[lsearch -exact $list $ltonick] > -1} {
        if {[lindex $data 2] > [lindex $bsu_list($ltonick) 2]} {
          set bsu_list($ltonick) $ndata ; incr fix
          if {[lindex $data 3] == "nick" && [string tolower [lindex $data 5]] == $ltonick} {incr errors}
        }
      } {
        set bsu_list([join $ltonick]) $ndata ; incr fix ; incr new
      }
    }
  }
  putlog "     $fix problems in the database were corrected.  $new new records were created in the process.  $errors catastrophic errors were prevented.  :)"
  return 0
}
proc bsu_finish {} {
  global bsu_list
  if {[bsu_save]} {putlog "     Error:  data not found.  The update was not successful." ; return 1}
  putlog "     Cleaning up..." ; unset bsu_list ; putlog "     Done!"
  return 0
}
return "ok"
