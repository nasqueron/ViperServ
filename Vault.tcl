package require vault

proc vault_login {} {
    global vault

    ::vault::init $vault(host)
    ::vault::appRoleLogin $vault(roleID) $vault(secretID)
}

proc vault_get {property {key {}}} {
    if {[catch {set credential [::vault::readKV apps/viperserv/$property $key]} err]} {
        if {[string match "*403 Forbidden*" $err]} {
            # Token expired?
            vault_login
            return [::vault::readKV apps/viperserv/$property $key]
        }
    }

    return $credential
}

vault_login
