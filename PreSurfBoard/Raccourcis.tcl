# Notefix.tcl v1.2 par Golden <kishpa@globetrotter.net>
# Description: Scripts pemettant d'envoyer rapidement des notes aux personne qui nous ont envoyer des notes ou aux personne
#              ayant recu une note de nous.
# Utilisation: ++ ou & réenvoie une nouvelle note à la personne que vous avez noté la dernière fois que vous avez envoyé une note.
#              -- ou | ou ¦ réenvoie une nouvelle note à la personne qui vous a noté la dernière fois que vous avez reçu une note.
# Installation: 1) Mettez ce tcl dans un répertoire accesible par l'Eggdrop.
#               2) Chargez le scripts par un des moyen suivant:
#                a) En partyline, tapez => .tcl source repertoire_du_scripts/nom_du_scripts.tcl
#                b) Ajoutez A LA TOUTE FIN du votre fichier de configuration général (eggdrop.conf) Ceci =>
#                   source repertoire_du_scripts/nom_du_scripts.tcl
# ATTENTION: Afin d'utiliser correctement se script, vous devez avoir chargé le module 'NOTES' de Eggdrop.
#            Par simple sécurité, vérifier que la commande loadmodule notes a bien été éxécuté avant le chargement du script.

# Binds de filtration du texte envoyé au note permettant de définir ce qui est une note d'une autre commande.

bind filt - ".note *" filt:note
bind filt - "++ *" note:resend
bind filt - "++ *" note:reponse


# Procédure employé afin d'enregistrer les actions posées par les usagers (coté note)

proc filt:note {idx text} {
  set note [lrange $text 1 end]
  foreach destinataire [split [lindex $text 1] ,] {
    if {![validuser $destinataire] || [matchattr $destinataire b]} {putdcc $idx "$destinataire n'est pas un usager valide" ; continue}
    setuser [idx2hand $idx] XTRA LASTSEND $destinataire
    setuser $destinataire XTRA LASTRECEIVE [idx2hand $idx]
    return ".note $destinataire $note"
  }
}

# Procédure employé afin de trouvé qui vous avez noté pour la dernière fois

proc note:resend {idx text} {
  if {[getuser [idx2hand $idx] XTRA LASTSEND] == ""} {
    putdcc $idx "Vous n'avez jamais envoyé de note!"
    return 0
  }
  set handle [getuser [idx2hand $idx] XTRA LASTSEND]
  return ".note $handle $text"
}

# Procédure employé afin de trouvé de qui vous avez recu une note pour la dernière fois

proc note:reponse {idx text} {
  if {[getuser [idx2hand $idx] XTRA LASTRECEIVE] == ""} {
    putdcc $idx "Vous n'avez jamais reçu de note!"
    return 0
  }
  set handle [getuser [idx2hand $idx] XTRA LASTRECEIVE]
  return ".note $handle $text"
}
