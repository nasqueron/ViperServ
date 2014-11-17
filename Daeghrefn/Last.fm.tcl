# .tcl source scripts/Daeghrefn/Last.fm.tcl

package require json

bind dcc - lastfm dcc:lastfm

proc dcc:lastfm {handle idx arg} {
	switch [set command [lindex $arg 0]] {
		"" {
			return [*dcc:help $handle $idx lastfm]
		}

		"count" {
			
		}

		"top5" {
			set username [lindex $arg 1]
			if {$username == ""} { set username $handle }
			set i 0
			foreach track [lastfm::library_getTracks $username 5] {
				putdcc $idx "[incr i]. [dg $track artist.name] - [dg $track name] ([dg $track playcount])"
			}
		}

		default {
			putdcc $idx "Unknown command: $command"
			return 0
		}
	}
}

namespace eval ::lastfm {
	proc library_getTracks {username {tracks 50} {artist ""}} {
		set url "?method=library.gettracks&&user=[url::encode $username]&limit=$tracks"
		if {$artist != ""} {
			append url &artist=[url::encode $artist]
		}
		set result [get_json $url]
		dg $result tracks.track
	}

	proc getTrackPlayCount {username artist track} {
		foreach artistTrack [library_getTracks $username 500 $artist] {
			if {[string tolower [dg $artistTrack name]] == [string tolower $track]} {
				return [dg $artistTrack playcount]
			}
		}
		return 0
	}

	proc get_json {url} {
		set url [url]${url}&api_key=[key]&format=json
		set token [http::geturl $url]
		set data [http::data $token]
		http::cleanup $token
		json::json2dict $data
	}

	proc key {} {
		registry get lastfm.api.key
	}

	proc url {} {
		registry get lastfm.api.url
	}
}