# .tcl source scripts/Maintenance/MigrateBlog.tcl

#
# Dotclear -> Wordpress blog migration
# Gets post lang from DotClear, and add relevant Wordpress post metadata for Polylang plugin.
#

namespace eval ::blog:: {
	set lang(fr) 31
	set lang(en) 32

	#sqladd -> sqladd7
	proc sqladd7 [info args sqladd] [string map {"sql \$sql" "sql7 \$sql"} [info body sqladd]]

	proc launch_migration {} {
		#Migration counters
		set counter_fail 0
		set counter_pass 0

		foreach row [sql7 "SELECT post_titre_url, post_lang FROM Blog.dc_post"] {
			foreach "title lang" $row {}
			set post_id [sql7 "SELECT ID FROM Dereckson_Blog.wp_posts WHERE post_name = '[sqlescape $title]'"]
			if {$post_id == ""} {
				putdebug "Can't find post: $title"
				incr counter_fail
				continue
			}
			if {$lang == "efr"} {
				putdebug "Bilingual post: $title - http://www.dereckson.be/blog/wp-admin/post.php?post=$post_id&action=edit"
				incr counter_fail
			} {
				#putdebug "$post_id -> _translations: [get_metadata $post_id $lang]"
				sqladd7 Dereckson_Blog.wp_postmeta "post_id meta_key meta_value" "$post_id _translations [get_translation_metadata $post_id $lang]"
				incr counter_pass
			}
		}
		putdebug "$counter_fail post[s $counter_fail] to manually take care of, $counter_pass post[s $counter_pass] updated."
	}

	proc get_translation_metadata {post_id lang} {
		# We need a PHP serialized array [ '$lang' => $post_id, '$altlang' => 0 ]
		if {$lang == "en"} { set altlang fr } { set altlang en }
		return "a:2:{s:2:\"$lang\";i:$post_id;s:2:\"$altlang\";i:0;}"
	}

	## Fixes translation, when every post is in English, setting the correct one in French
	proc fix_translation {} {
		# Finds posts in French (from DotCler post_lang info)
		set posts {}
		foreach row [sql7 "SELECT post_titre_url, post_lang FROM Blog.dc_post"] {
			foreach "title lang" $row {}
			set post_id [sql7 "SELECT ID FROM Dereckson_Blog.wp_posts WHERE post_name = '[sqlescape $title]'"]
			if {$post_id == ""} {
				putdebug "Can't find post: $title"
			} elseif {$lang == "fr"} {
				lappend posts $post_id
			}
		}

		# Sets metadata French in Wordpress
		batch_en2fr $posts
	}

	proc batch_en2fr {posts_id} {
		set postsUpdated 0
		foreach post_id $posts_id {
			incr postsUpdated [change_post_language $post_id $blog::lang(en) $blog::lang(fr)]
		}
		if {$postsUpdated > 0} {
			sql7 "UPDATE Dereckson_Blog.wp_term_taxonomy SET `count` = `count` - $postsUpdated WHERE term_taxonomy_id = $blog::lang(en)"
			sql7 "UPDATE Dereckson_Blog.wp_term_taxonomy SET `count` = `count` + $postsUpdated WHERE term_taxonomy_id = $blog::lang(fr)"
		}
	}

	proc en2fr {post_id} {
		change_post_language $post_id $blog::lang(en) $blog::lang(fr)
	}

	proc change_post_language {post_id oldlang newlang {updateTaxonomy 1}} {
		set isNewLang [sql7 "SELECT count(*) FROM Dereckson_Blog.wp_term_relationships WHERE object_id = $post_id AND term_taxonomy_id IN ('$newlang')"]
		if $isNewLang {
			putdebug "Post $post_id is already in this language."
			return 0
		} {
			sql7 "DELETE FROM Dereckson_Blog.wp_term_relationships WHERE object_id = $post_id AND term_taxonomy_id = $oldlang"
			sql7 "INSERT INTO Dereckson_Blog.wp_term_relationships (object_id, term_taxonomy_id) VALUES ($post_id, $newlang)"
			if {$updateTaxonomy} {
				sql7 "UPDATE Dereckson_Blog.wp_term_taxonomy SET `count` = `count` - 1 WHERE term_taxonomy_id = $blog::lang(en)"
				sql7 "UPDATE Dereckson_Blog.wp_term_taxonomy SET `count` = `count` + 1 WHERE term_taxonomy_id = $blog::lang(fr)"
			}
			return 1
		}
	}
}
