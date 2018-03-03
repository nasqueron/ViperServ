package require rest

bind pub -  .+log       pub:log
bind dcc -   +log       dcc:log

bind pubm -  "#* \[*\] *"        pubm:log

proc pubm:log {nick uhost handle chan text} {
    if {[isbot $nick]} {
        return 0
    }

    regexp "^\\\[(.*)\\\] (.*)" $text match component entry

    if {[is_known_component $component]} {
        set callback [get_putbymode_chan_callback $chan $nick]
        handle_send_to_servers_log [resolve_nick $nick] $chan $text $callback
        putcmdlog "<<$nick>> !$handle! .+log $text"
    } {
        putserv "PRIVMSG $chan :$nick, if you wish to log that, confirm with .+log $text"
    }
}

proc pub:log {nick uhost handle chan arg} {
    set callback [get_putbymode_chan_callback $chan $nick]
    handle_send_to_servers_log [resolve_nick $nick] $chan $arg $callback
}

proc dcc:log {handle idx arg} {
    global username
    handle_send_to_servers_log $handle $username $arg "dcc $idx"
}

proc is_known_component {candidate} {
    # If "Dwellers" is a known component, are known:
    #   - Dwellers
    #   - Dwellers/DevCentral

    foreach component [registry get serverslog.knowncomponents] {
        if {[regexp ^${component}(/.+)?$ $candidate]} {
            return 1
        }
    }

    return 0
}

proc handle_send_to_servers_log {emitter source arg callback} {
    global network

    #Parse [component] entry
    if {[regexp "\\\[(.*)\\\] (.*)" $arg match component entry]} {
        add_to_servers_log $emitter "$network $source" $component $entry
        return 1
    } {
        putbymode $callback "use the format \[component\] message"
        return 0
    }
}

proc add_to_servers_log {emitter source component entry} {
    set request [dict2json "
        date [iso8601date]
        emitter $emitter
        source {$source}
        component $component
        entry {$entry}
    "]

    rest::simple https://api.nasqueron.org/servers-log/ {} {
        method PUT
        content-type application/json
        format json
    } $request
}
