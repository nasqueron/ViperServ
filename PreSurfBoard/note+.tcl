#Note+
#(c) Sébastien Santoro

bind dcc - note+ dcc:note+

proc dcc:note+ {handle idx arg} {
if {$arg==""} {putdcc $idx "Usage : note+ <ops/admins/all> <texte de la note>"
               putdcc $idx "     ou note+ spec <spécialité> <texte de la note>"
               return
              }

set dest [lindex $arg 0]
set ucmd "error"
if {$dest=="ops"} {set ucmd "[userlist O]"}
if {$dest=="admins"} {set ucmd "[userlist A]"}
if {$dest=="all"} {
     
     if {!([matchattr $handle A]) && !($handle=="Laping") && !($handle=="ViperServ") } {
         putdcc $idx "Seul les administrateurs et le laping peuvent envoyer une note à tout le monde."
         putdcc $idx "Utilise à la place .news add - <texte> ou .+forum <texte>"
         return
     }

     set ucmd "[userlist]"
}

if {$dest=="spec"} {
set sujet [lrange $arg 1 end]
if {$sujet==""} {
            putdcc $idx "Usage : .note+ spec <spécialité> <texte de la note>"
            return
            }
set ucmd ""
foreach helper [userlist] {
       if {[string match "*[string tolower $sujet]*" [string tolower [getuser $helper XTRA specialites]]]} {
              lappend ucmd "$helper"
       }
}

if {$ucmd==""} {
       putdcc $idx "Aucun spécialiste en $sujet."
       return
}


}

if {$ucmd=="error"} {putdcc $idx "Usage : note+ <ops/admins/all> <texte de la note>"
                     return
                    }

set texte [lrange $arg 1 end]
if {$texte==""} {putdcc $idx "Quel note veux-tu envoyé ?"
                 returns
                }

foreach user $ucmd {
      storenote $handle $user $texte -1
}
                    
putdcc $idx "Ok, notes envoyées."
putcmdlog "#$handle# NOTE+ $dest ..."

}