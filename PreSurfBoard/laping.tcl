#Coded by Sébastien Santoro aka Dereckson
#Inspired from Clément Didier aka TheClem sentence ideas
#This version isn't the SurfBoard production one but a backup from 2001-07-29 23:39:48
#

bind dcc -|- laping laping
bind dcc -|- carotte laping2
bind dcc -|- cage laping3
bind dcc -|- herbe laping2herbe
bind dcc -|- gazon ReplanterGazon
bind dcc -|- eau DonnerBoisson
bind join -|- *!*@* join:laping
bind nick - "#win laping" nick:laping
proc nick:laping {nick uhost handle canal newnick}

proc laping {h i a} {
  global Znick
  set Znick [hand2nick $h]
  putserv "privmsg #win :$Znick cherche le laping ki et caché dans la party-line, mais il trouveras po le laping"
}

proc laping2 {h i a} {
  global Znick
  set Znick [hand2nick $h]
  putserv "privmsg #win :$Znick a pris une carotte pour attirer le laping mais le laping ne va pas tomber dans le piège."
  putserv "privmsg #win :Vive le laping !"
  }
  
proc laping2herbe {h i a} {
  global Znick
  set Znick [hand2nick $h]
  putserv "privmsg #win :$Znick arrache de l'herbe pour donner le laping"
  putserv "privmsg #win :Mais le laping n'aime pas ce type d'herbe :("
  putserv "privmsg #win :Arggg ... ViperServ va pas être content ! Tu as arraché trop d'herbe"
  putserv "kick #win $Znick :Non mais tu vas me replanter du .gazon tout de suite !" 
  setuser $h XTRA GAZON! 1
  }

proc ReplanterGazon {h i a} {
  global Znick
  set Znick [hand2nick $h]
  putserv "privmsg #win :$Znick est de corvée plantage gazon"
  putserv "privmsg #win :Le soleil lui tape sur le système ..."
  putserv "privmsg #win :<$Znick> Pitié je veux une pause, il fait trop chaud"
  putserv "privmsg #win :<Laping> Pas question ! Tu continues jusqu'à mourir d'épuisement."
  putserv "privmsg #win :<Laping> Niark Niark Niark!"
  putserv "privmsg #win :<TheClem> Vive le laping :)"
  setuser $h XTRA GAZON! 0 
}

proc DonnerBoisson {h i a} {
  global Znick
  set Znick [hand2nick $h]
  putserv "privmsg #win :*** $Znick offre de l'eau bien fraîche au laping :)"
  putserv "privmsg #win :<Laping> Slurpppppp"
  putserv "privmsg #win :<Laping> Merci $Znick"
  putserv "privmsg #win :<Laping> *Smack*"
  putserv "privmsg #win :<$Znick> Grrrrr c dégoutant ... Et il m'a encore échappé"
  putserv "privmsg #win :<TheClem> Vive le laping :)"
}

proc join:laping {nick userhost handle canal} {
if {[getuser $handle XTRA GAZON!] == "1" } { putserv "kick #win $nick :Non mais tu vas me replanter du .gazon tout de suite !"
                                             setuser $handle XTRA GAZON! 2 
                                             return 0}
if {[getuser $handle XTRA GAZON!] == "2" } { putserv "privmsg #win :Tel est pris qui croyait prendre, chasseur de laping !"
                                             setuser $handle XTRA GAZON! 1 
                                             return 0}
}

proc laping3 {h i a} {
  global Znick
  set Znick [hand2nick $h]
putserv "privmsg #win :Gniark, $Znick a libéré le laping de la party-line, allons vite protéger le stock de carottes !"
utimer 45 laping3b
utimer 90 laping3c
}
proc laping3b {} {putserv "privmsg #win :<Laping> Je suis libreeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee :)" }
proc laping3c {} {putserv "privmsg #win :Ouf j'ai récupéré le laping :) Réenfermé en partyline" }