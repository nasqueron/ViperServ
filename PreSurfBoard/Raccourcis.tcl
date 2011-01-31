# Notefix.tcl v1.2 par Golden <kishpa@globetrotter.net>
# Description: Scripts pemettant d'envoyer rapidement des notes aux personne qui nous ont envoyer des notes ou aux personne
#              ayant recu une note de nous.
# Utilisation: ++ ou & r�envoie une nouvelle note � la personne que vous avez not� la derni�re fois que vous avez envoy� une note.
#              -- ou | ou � r�envoie une nouvelle note � la personne qui vous a not� la derni�re fois que vous avez re�u une note.
# Installation: 1) Mettez ce tcl dans un r�pertoire accesible par l'Eggdrop.
#               2) Chargez le scripts par un des moyen suivant:
#                a) En partyline, tapez => .tcl source repertoire_du_scripts/nom_du_scripts.tcl
#                b) Ajoutez A LA TOUTE FIN du votre fichier de configuration g�n�ral (eggdrop.conf) Ceci =>
#                   source repertoire_du_scripts/nom_du_scripts.tcl
# ATTENTION: Afin d'utiliser correctement se script, vous devez avoir charg� le module 'NOTES' de Eggdrop.
#            Par simple s�curit�, v�rifier que la commande loadmodule notes a bien �t� �x�cut� avant le chargement du script.

# Binds de filtration du texte envoy� au note permettant de d�finir ce qui est une note d'une autre commande.

bind filt - ".note *" filt:note
bind filt - "++ *" note:resend
bind filt - "++ *" note:reponse


# Proc�dure employ� afin d'enregistrer les actions pos�es par les usagers (cot� note)

proc filt:note {idx text} {
  set note [lrange $text 1 end]
  foreach destinataire [split [lindex $text 1] ,] {
    if {![validuser $destinataire] || [matchattr $destinataire b]} {putdcc $idx "$destinataire n'est pas un usager valide" ; continue}
    setuser [idx2hand $idx] XTRA LASTSEND $destinataire
    setuser $destinataire XTRA LASTRECEIVE [idx2hand $idx]
    return ".note $destinataire $note"
  }
}

# Proc�dure employ� afin de trouv� qui vous avez not� pour la derni�re fois

proc note:resend {idx text} {
  if {[getuser [idx2hand $idx] XTRA LASTSEND] == ""} {
    putdcc $idx "Vous n'avez jamais envoy� de note!"
    return 0
  }
  set handle [getuser [idx2hand $idx] XTRA LASTSEND]
  return ".note $handle $text"
}

# Proc�dure employ� afin de trouv� de qui vous avez recu une note pour la derni�re fois

proc note:reponse {idx text} {
  if {[getuser [idx2hand $idx] XTRA LASTRECEIVE] == ""} {
    putdcc $idx "Vous n'avez jamais re�u de note!"
    return 0
  }
  set handle [getuser [idx2hand $idx] XTRA LASTRECEIVE]
  return ".note $handle $text"
}
