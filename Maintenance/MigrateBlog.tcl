# .tcl source scripts/Maintenance/MigrateBlog.tcl

#
# Dotclear -> Wordpress blog migration
# Gets post lang from DotClear, and add relevant Wordpress post metadata for Polylang plugin.
#

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
