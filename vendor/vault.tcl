# -*- tcl -*-
#
# Copyright (c) 2022 by Sébastien Santoro <dereckson@espace-win.org>
#
# A client to use HashiCorp Vault through the HTTP API.

package require http
package require json
package require json::write
package require tls

::http::register https 443 ::tls::socket

package provide vault 0.1

namespace eval ::vault {

    variable addr
    variable token

}

###
### Initialize parameters
###

proc ::vault::init {{address ""}} {
    variable addr
    variable token

    if {$address == ""} {
        # Try to read VAULT_ADDR standard environment variable
        if {[info exists env(VAULT_ADDR)]} {
            set addr $env(VAULT_ADDR)
            return
        }

        error "Address must be specified as argument or available in VAULT_ADDR environment variable."
    }

    set addr $address
    set token ""
}

proc ::vault::setToken {sessionToken} {
    variable token
    set token $sessionToken
}

###
### Helper methods
###

proc ::vault::request {method url {params {}}} {
    variable addr
    variable token

    set command [list ::http::geturl $addr$url -method $method]

    if {[llength $params] > 0} {
        lappend command -query
        lappend command [::vault::payload $params]
    }

    if {$token != ""} {
        lappend command -headers
        lappend command [list X-Vault-Token $token]
    }

    set httpToken [{*}$command]
    if {[::http::ncode $httpToken] != 200} {
        error "Vault returned [::http::code $httpToken], 200 OK was expected."
    }

    set response [::json::json2dict [::http::data $httpToken]]
    ::http::cleanup $httpToken
    return $response
}

proc ::vault::payload {params} {
    ::json::write object {*}[dict map {k v} $params {
        set v [::json::write string $v]
    }]
}

proc ::vault::resolveKVPath {path} {
    set parts [split $path /]

    return /v1/[lindex $parts 0]/data/[join [lrange $parts 1 end] /]
}

###
### API methods
###

proc ::vault::appRoleLogin {roleID secretID} {
    set params [list role_id $roleID secret_id $secretID]
    set response [::vault::request POST /v1/auth/approle/login $params]

    variable token
    set token [dict get [dict get $response auth] client_token]
}

proc ::vault::readKV {path {key {}}} {
    set response [::vault::request GET [::vault::resolveKVPath $path]]
    set response [dict get $response data]

    if {$key == ""} {
        return $response
    }

    dict get [dict get $response data] $key
}
