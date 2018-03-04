bind dcc  -  antidater   dcc:antidater
bind dcc  -  postdater   dcc:postdater
bind dcc  -  days        dcc:days
bind dcc  -  quux        dcc:quux
bind dcc  -  paypal      dcc:paypal
bind dcc  - +db          dcc:db

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

#
# Database
#

namespace eval ::datacube {
    proc get_table {cube} {
        set table [dg $cube datasource.db]
        append table .
        append table [dg $cube datasource.table]
    }

    proc insert_data_into_cube {cube} {
        set fields [get_fields_properties $cube name]
        set values [dict get $cube values]

        if {[llength $fields] != [llength $values]} {
            error "Datacube: count mismatch between fields and values"
        }

        sqladd [get_table $cube] $fields $values
    }

    proc is_cube_title_exists {title} {
        set title [sqlescape $title]
        sqlscalar "SELECT count(*) FROM db_datacubes WHERE title = '$title'"
    }

    proc get_cube {title} {
        set cube [get_cube_properties $title]
        dict set cube current_position -1
    }

    proc get_cube_properties {title} {
        set title [sqlescape $title]
        sqlscalar "SELECT properties FROM db_datacubes WHERE title = '$title'"
    }

    proc get_fields_properties {cube property} {
        set properties {}
        foreach field [get_fields $cube] {
            lappend properties [dict get $field $property]
        }
        return $properties
    }

    proc get_fields {cube} {
        dict get $cube fields
    }

    proc get_fields_count {cube} {
        llength [get_fields $cube]
    }

    proc get_current_position {cube} {
        dict get $cube current_position
    }

    proc get_current_field {cube} {
        set current_position [get_current_position $cube]

        if {$current_position >= [get_fields_count $cube]} {
            error "Datacube: out of range position"
        }

        lindex [get_fields $cube] $current_position
    }

    proc get_current_field_info {cube info} {
        dict get [get_current_field $cube] $info
    }

    proc is_cube_in_last_position {cube} {
        set current_position [get_current_position $cube]
        set fields_count [get_fields_count $cube]

        if {$current_position >= $fields_count} {
            error "Datacube: out of range position"
        }

        expr $current_position == $fields_count - 1
    }

    proc fill_buffer {cube_variable_name text} {
        upvar 1 $cube_variable_name cube

        if {[dict exists $cube buffer]} {
            dict append cube buffer \n
        }
        dict append cube buffer $text
    }

    # Returns 1 if the current field is full and we can go forward
    #         0 if the buffer has been used (multiline mode)
    proc fill_cube_data {cube_variable_name text} {
        upvar 1 $cube_variable_name cube

        set type [get_current_field_info $cube type]

        if {$type == "multiline"} {
            fill_buffer cube $text
        } elseif {$type == "line"} {
            dict lappend cube values $text
            return 1
        } else {
            error "Unknown type for datacube value: $type"
        }

        return 0
    }

    proc fill_cube_data_from_buffer {cube_variable_name} {
        upvar 1 $cube_variable_name cube

        dict lappend cube values [dict get $cube buffer]
        dict unset cube buffer
    }

    # Controls database new entry process
    # Returns 0 when we need to keep control, 1 when we're done
    proc control_handle {idx text} {
        global db

        if {$text == "+"} {
            fill_cube_data_from_buffer db($idx)
            control_on_data_saved $idx
        } elseif {$text == "-"} {
            control_abort $idx
            return 1
        } else {
            # Fill datacube
            control_append $idx $text
        }
    }

    proc control_on_data_saved {idx} {
        global db

        if {[is_cube_in_last_position $db($idx)]} {
            control_save_cube $idx
            return 1
        }

        control_forward_cube $idx
        return 0
    }

    proc control_append {idx text} {
        global db

        set done [fill_cube_data db($idx) $text]
        if {$done} {
            control_on_data_saved $idx
        } {
            return 0
        }
    }

    proc control_abort {idx} {
        global db

        unset db($idx)
        putdcc $idx "Ok, le cube est laissé intact, retour sur la party line."
    }

    proc control_forward_cube {idx} {
        global db

        dict incr db($idx) current_position

        putdcc $idx \002[get_current_field_info $db($idx) prompt]\002

        set type [get_current_field_info $db($idx) type]
        if {$type == "multiline"} {
            putdcc $idx "Pour valider, entre une ligne ne contenant que ceci: \002+\002"
        }
    }

    proc control_save_cube {idx} {
        global db

        if {[catch {
            insert_data_into_cube $db($idx)
        } sqlError]} {
            putdcc $idx $sqlError
            return 0
        }

        unset db($idx)
        putdcc $idx "Ajouté dans le cube :-)"
    }
}

proc dcc:db {handle idx arg} {
    if {![datacube::is_cube_title_exists $arg]} {
        putdcc $idx "Unknown datacube: $arg"
        return 0
    }

    global db
    set db($idx) [datacube::get_cube $arg]
    datacube::control_forward_cube $idx
    control $idx datacube::control_handle

    return 1
}
