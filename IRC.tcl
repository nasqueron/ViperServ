bind evnt - init-server evnt:onconnect

proc evnt:onconnect {type} {
    identify_to_nickserv
}

proc identify_to_nickserv {} {
    global nickserv_password username

    if {[info exists nickserv_password]} {
        putquick "nickserv identify $username $nickserv_password"
    }
}
