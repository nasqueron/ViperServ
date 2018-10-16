bind dcc  - help dcc:help

set help {
    quux {
        quux                  print available quux categories
        quux tag              add a tag - e.g. .quux tag 17 prime
        quux <cat>            print quuxes in this category
        quux *                print all quuxes
        quux <cat> <content>  publish quux
    }
    "+db" {
        .+db lyrics           add artist, title, excerpt
        .+db rainbow          add the date of an observed rainbow
    }
}

proc dcc:help {handle idx arg} {
    global help

    if {[has_no_args $arg]} {
        global version

        putdcc $idx "
  _____                     __                ___
 |     \.---.-.-----.-----.|  |--.----.-----.'  _|.-----.
 |  --  |  _  |  -__|  _  ||     |   _|  -__|   _||     |
 |_____/|___._|_____|___  ||__|__|__| |_____|__|  |__|__|
                    |_____| eggdrop $version (ViperServ distribution)

 \[ Bureautique ]    antidater postdater days paypal quux +db
 \[ Channel ]        botnet
 \[ Communication ]  sms mail twitter
 \[ GIS  ]           fantoir
 \[ Server ]         phpfpm
 \[ Tools ]          genpass strlen unixtime
 \[ Wikimedia ]      config +surname +givenname

"
    } elseif {[dict exists $help $arg]} {
        putdcc $idx [dict get $help $arg]
    } else {
        *dcc:help $handle $idx $arg
    }
}
