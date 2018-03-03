bind dcc  -  antidater   dcc:antidater
bind dcc  -  postdater   dcc:postdater
bind dcc  -  days        dcc:days
bind dcc  -  quux        dcc:quux
bind dcc  -  paypal      dcc:paypal

#
# Dates calculation
#

#Removes $days from $date or if unspecified, current unixtime
proc antidater {days {date ""}} {
    postdater [expr $days * -1] $date
}

#Adds $days from $date or if unspecified, current unixtime
proc postdater {days {date ""}} {
    if {$date == ""} {
        set date [unixtime]
    }
    incr date [expr 86400 * $days]
}

#.antidater 15
#.antidater 2011-01-29 4
proc dcc:antidater {handle idx arg} {
    set argc [llength $arg]
    if {$argc == 0} {
        putdcc $idx "De combien de jours dois-je antidater ?"
        return
    }
    if {$argc == 1} {
        set date ""
        set days $arg
    } {
        if [catch {set date [clock scan [lindex $arg 0]]} err] {
            putdcc $idx $err
            return
        }
        set days [lindex $arg 1]
    }
    if ![isnumber $days] {
        putdcc $idx "$days n'est pas un nombre de jours"
        return
    }
    putdcc $idx [clock format [antidater $days $date] -format "%Y-%m-%d"]
    return 1
}

#.postdater 15
#.postdater 2011-01-29 4
proc dcc:postdater {handle idx arg} {
    set argc [llength $arg]
    if {$argc == 0} {
        putdcc $idx "De combien de jours dois-je postdater ?"
        return
    }
    if {$argc == 1} {
        set date ""
        set days $arg
    } {
        if [catch {set date [clock scan [lindex $arg 0]]} err] {
            putdcc $idx $err
            return
        }
        set days [lindex $arg 1]
    }
    if ![isnumber $days] {
        putdcc $idx "$days n'est pas un nombre de jours"
        return
    }
    putdcc $idx [clock format [postdater $days $date] -format "%Y-%m-%d"]
    return 1
}

namespace eval ::quux:: {
    ## Adds a quux
    ##
    ## @param $userid The user id
    ## @param $category The quux category
    ## @param $content The quux content
    ## @param $tags The quux tags [optional]
    proc add {userid category content {tags ""}} {
        global username
        lappend tags client:$username
        sqladd quux "user_id quux_date quux_category quux_content quux_tags" [list $userid [unixtime] $category $content $tags]
        sqllastinsertid
    }

    ## Tags a quux
    ##
    ## @param $id The quux id
    ## @param $tags The tags to add
    proc tag {id tags} {
        if {![isnumber $id]} { error "bad id \"$id\": must be integer" }
        switch [sql "SELECT LENGTH(quux_tags) FROM quux WHERE quux_id = $id"] {
            ""  { error "Not existing quux: $id" }
            0   { set value '[sqlescape $tags]' }
            default { set value "CONCAT(quux_tags, ' ', '[sqlescape $tags]')" }
        }
        sql "UPDATE quux SET quux_tags = $value WHERE quux_id = $id"
    }

    ## Determines if the specified user is the quux's owner
    ##
    ## @param $id The quux id
    ## @param $userid The user id
    ## @return 1 if the quux exists and added by the specified user; otherwise, 0
    proc isauthor {id userid} {
        if {![isnumber $id]} { error "bad id \"$id\": must be integer" }
        if {![isnumber $userid]} { error "bad userid \"$userid\": must be integer" }
        sql "SELECT count(*) FROM quux WHERE quux_id = $id AND user_id = $userid"
    }
}

proc dcc:quux {handle idx arg} {
    #.quux
    if {[llength $arg] == 0} {
        #Prints categories
        putdcc $idx [sql "SELECT DISTINCT quux_category FROM quux WHERE user_id = [getuserid $idx] AND quux_deleted = 0"]
        return 1
    }

    #.quux <command>
    set command [lindex $arg 0]
    switch $command {
        "tag" {
            #.quux tag <quux id> <tag to add>

            set id [lindex $arg 1]
            set content [string range $arg [string length $id]+5 end]

            if {![isnumber $id]} {
                putdcc $idx "Not a number."
            } elseif {![quux::isauthor $id [getuserid $idx]]} {
                putdcc $idx "Not your quux."
            } {
                quux::tag $id $content
                putcmdlog "#$handle# quux tag ..."
            }
            return 0
        }
    }

    #.quux <category>
    if {[llength $arg] == 1} {
        global username
        set category $arg
        set i 0
        set dateformat [registry get date.formats.long]
        set sql "SELECT quux_id, quux_date, quux_category, quux_content, quux_tags FROM quux WHERE user_id = [getuserid $idx] AND quux_deleted = 0"
        if { $category != "*" } { append sql " AND quux_category = '[sqlescape $category]'" }
        append sql " ORDER BY quux_date DESC LIMIT 20"
        foreach row [sql $sql] {
            foreach "id date cat content tags" $row {}
            set text "[completestringright $id 3]. "
            if { $category == "*" } { append text "$cat - " }
            append text $content

            #Tags
            set tags [string trim [string map [list "client:$username" ""] $tags]]
            if {$tags != ""} {
                append text " \00314$tags\003"
            }

            putdcc $idx $text
            incr i
        }
        if {$i == 0} {
            putdcc $idx "$arg xuuQ."
            return 0
        }
        return 1
    }

    #.quux <category> <text to add>
    set category [lindex $arg 0]
    set content [string range $arg [string length $category]+1 end]
    putdcc $idx "Published under QX[quux::add [getuserid $idx] $category $content]"
    putcmdlog "#$handle# quux ..."
    return 0
}

#
# Paypal calculation
#

namespace eval ::paypal {
    # -rate% - 0.35 €
    # Default rate: 3.4% for EU
    proc gross2net {net {rate 3.4}} {
        format %0.2f [expr ($net - 0.35) / (100 + $rate) * 100]
    }

    # +rate% + 0.35 €
    proc net2gross {gross {rate 3.4}} {
        format %0.2f [expr $gross * (100 + $rate) / 100 + 0.35]
    }
}
