# bip.tcl v2,0 par Golden <kishpa@globetrotter.net>
# Description: Script pemettant d'am�liorer les chances d'un usager pour un contacter un autre au moyen de note et de sons.
# Utilisation: '.bip <nick IRC | nick sur le bot>'

#Binds

bind dcc - bip dcc:bip

#Proc�dures de bip
 
proc dcc:bip {h i t} {
  global botnick
  
  if  {([lindex $t 0] == "all")} {
    foreach list [dcclist chat] {
      set hand [lindex $list 1]
      if {[hand2nick $hand] != ""} {append handlelist "$hand "}
    }
    foreach user $handlelist { if {$user != $h} {dcc:bip $h $i "$user [lrange $t 1 end]"} }
    return 1
  }
  
    if  {([lindex $t 0] == "ops")} {
    foreach list [dcclist chat] {
      set hand [lindex $list 1]
      if {[hand2nick $hand] != "" && [matchattr $hand o] } {append handlelist "$hand "}
    }
    foreach user $handlelist { if {$user != $h} {dcc:bip $h $i "$user -� tous les ops- [lrange $t 1 end]"} }
    return 1
  }
  
    if  {([lindex $t 0] == "admins")} {
    foreach list [dcclist chat] {
      set hand [lindex $list 1]
      if {[hand2nick $hand] != "" && [matchattr $hand A] } {append handlelist "$hand "}
    }
    foreach user $handlelist { if {$user != $h} {dcc:bip $h $i "$user -� tous les admins- [lrange $t 1 end]"} }
    return 1
  }
  
  if {![validuser [lindex $t 0]]} {
    putdcc $i "Usager non-valide"
    return 0
  }
# V�rification si l'usager est accessible par le bot
  if {[hand2idx [lindex $t 0]] == "-1" && [hand2nick [lindex $t 0]] == ""} {
    putdcc $i "([lindex $t 0]) n'est pr�sent ni sur IRC ni en partyline"
    return 0 
    }  {
# Exploitation du nick IRC de l'usag� pour le contacter
    if {[hand2idx [lindex $t 0]] == "-1"} {
      putquick "notice [hand2nick [lindex $t 0]] :Tu es appel� en partyline par $h ([lrange $t 1 end])"
      putquick "privmsg [hand2nick [lindex $t 0]] :\001sound wakeup.wav\001"
      putdcc $i "[lindex $t 0] a �t� apell� dans $botnick"
      return 1
      }  {
# Exploitation de l'interface partyline du bot pour le contacter
      putquick "notice [hand2nick [lindex $t 0]] :Tu es appel� en partyline par $h ([lrange $t 1 end])"
      putdcc [hand2idx [lindex $t 0] ] "4$h d�sire te parler ([lrange $t 1 end])"
      putquick "privmsg [hand2nick [lindex $t 0]] :\001sound wakeup.wav\001"
      putdcc $i "[lindex $t 0] ([hand2nick [lindex $t 0]]) a �t� apell� dans $botnick"
      return 1
    }
  }
}