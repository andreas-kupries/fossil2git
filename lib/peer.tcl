## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::peer 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

# # ## ### ##### ######## ############# ######################

package require Tcl 8.5
package require cmdr::color
package require debug
package require debug::caller
package require interp
package require linenoise
package require textutil::adjust
package require try

package require fx::fossil
package require fx::mgr::peer
package require fx::table
package require fx::util

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::peer {
    namespace export \
	list add remove add-git remove-git exchange
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::fx::fossil
    namespace import ::fx::util
    namespace import ::fx::mgr::map
    namespace import ::fx::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

debug level  fx/peer
debug prefix fx/peer {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::fx::peer::list {config} {
    debug.fx/peer {}
    Init
    fossil show-repository-location

    set map [Get $config]
    # dict: "fossil" + url + area -> direction
    #       "git" + url           -> last-uuid

    # Restructure the map to be indexed by url, and canonicalize the
    # associated data for the table.
    set tmap {}
    dict for {type spec} $map {
	switch -exact -- $type {
	    fossil {
		dict for {url espec} $spec {
		    set etype $type
		    dict for {area dir} [util dictsort $espec] {
			dict lappend tmap $url [::list $etype $dir $area]
			# Drop type information in multiple rows of the same url
			set etype {}
		    }
		}
	    }
	    git {
		dict for {url last} $spec {
		    dict lappend tmap $url [::list $type push content]
		}
	    }
	    default {
		error "Bad peer type \"$type\", expected one of fossil, or git"
	    }
	}
    }

    # Show the table
    [table t {Url Type Flow Area} {
	foreach {u speclist} [util dictsort $tmap] {
	    foreach spec [lsort -dict $speclist] {
		$t add $u {*}$spec
		# Drop the url in multiple rows of the same url.
		set u {}
	    }
	}
    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::peer::add {config} {
    debug.fx/peer {}
    fossil show-repository-location
    Init

    set url  [$config @peer]
    set dir  [$config @direction]
    set area [$config @area]

    puts -nonewline "  Adding fossil \"$url $dir $area\" ... "
    flush stdout

    set peers [map get peer@fossil]

    if {![dict exists $peers $url]} {
	map add1 peer@fossil $url $direction
	puts [color good OK]
	return
    }

    # Merge areas ...
    set spec [dict get $peers $url]

    if {![dict exists $spec $area]} {
	dict set spec $area $dir
	fossil repository transaction {
	    map remove1 peer@fossil $url
	    map add1    peer@fossil $url $spec
	}
	puts [color good OK]
	return
    }

    # Merge directions ...
    set old [dict get spec $area]
    set new [PermAdd $old $direction]

    if {$new eq $old} {
	puts [color note {No change, ignored}]
	return
    }

    puts -nonewline [color note "upgraded to $new "]
    flush stdout

    dict set spec $area $new
    fossil repository transaction {
	map remove1 peer@fossil $url
	map add1    peer@fossil $url $spec
    }

    puts [color good OK]
    return
}

proc ::fx::peer::remove {config} {
    debug.fx/peer {}
    fossil show-repository-location

    set url  [$config @peer]
    set dir  [$config @direction]
    set area [$config @area]

    puts -nonewline "  Removing fossil \"$url $dir $area\" ... "
    flush stdout

    set peers [map get peer@fossil]

    if {![dict exists $peers $url]} {
	puts [color note {No change, ignored}]
	return
    }

    # Drop areas ...
    set spec [dict get $peers $url]

    if {![dict exists $spec $area]} {
	puts [color note {No change, ignored}]
	return
    }

    # Merge directions ...
    set old [dict get spec $area]
    set new [PermDrop $old $direction]

    if {$new eq $old} {
	puts [color note {No change, ignored}]
	return
    }

    if {$new eq {}} {
	dict unset spec $area
    } else {
	dict set set spec $new
    }

    if {![dict size $spec]} {
	# Drop entirely...
	map remove1 peer@fossil $url
	puts [color good OK]
    }

    # Change stored spec.
    fossil repository transaction {
	map remove1 peer@fossil $url
	map add1    peer@fossil $url $spec
    }

    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::peer::add-git {config} {
    debug.fx/peer {}
    fossil show-repository-location
    Init

    set url [$config @peer]

    puts -nonewline "  Adding git \"$url push content\" ... "
    flush stdout

    set peers [map get peer@git]

    if {[dict exists $peers $url]} {
	puts [color note {No change, ignored}]
	return
    }

    map add1 peer@fossil $url {}
    puts [color good OK]
    return
}

proc ::fx::peer::remove-git {config} {
    debug.fx/peer {}
    fossil show-repository-location
    Init

    set url [$config @peer]

    puts -nonewline "  Removing git \"$url push content\" ... "
    flush stdout

    set peers [map get peer@git]

    if {![dict exists $peers $url]} {
	puts [color note {No change, ignored}]
	return
    }

    # NOTE: Having the last-uuid state stored here looks to be bad, as
    # we cannot re-add a mistakenly removed peer without either having
    # a command to fix the uuid information, or working from scratch.
    # OTOH, having it in the git peer state in some temp dir ... Would
    # be removed as well, so does not really matter.
    #
    # Could however ask for confirmation.

    # TODO: Manage the git peer exchange state (git checkout).

    map remove1 peer@fossil $url
    puts [color good OK]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::peer::exchange {config} {
    debug.fx/peer {}
    fossil show-repository-location

    set r [fossil repository-location]

    set map [Get $config]
    # dict: "fossil" + url + area -> direction
    #       "git" + url           -> last-uuid

    dict for {type spec} [util dictsort $map] {
	switch -exact -- $type {
	    fossil {
		dict for {url espec} [util dictsort $spec] {
		    dict for {area dir} [util dictsort $espec] {
			# Exchange data for area, per chosen direction.
			# Invokes regular fossil to perform the action.
			puts "Fossil Exchange $url: $dir $area ..."

			if {$area eq "content"} {
			    exec 2>@ stderr >@ stdout \
				fossil $dir $url -R $r --once
			} else {
			    exec 2>@ stderr >@ stdout \
				fossil configuration $dir $area $url -R $r
			}
		    }
		}
	    }
	    git {
		dict for {url last} [util dictsort $spec] {
		    # TODO: git export
		    puts "Git    Exchange $url: push content"
		}
	    }
	    default {
		error "Bad peer type \"$type\", expected one of fossil, or git"
	    }
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################
## Internal import support commands.

proc ::fx::peer::PermAdd {perm bit} {
    # Current Add  New  Notes
    # ------- ---- ---- -----
    # push    push push (a)
    #         pull sync (d)
    #         sync sync (c)
    # ------- ---- ---- -----
    # pull    push sync (d)
    #         pull pull (a)
    #         sync sync (c)
    # ------- ---- ---- -----
    # sync    push sync (b)
    #         pull sync (b)
    #         sync sync (a)
    # ------- ---- ---- -----

    debug.fx/peer {}
    if {$perm eq $bit   } { return $perm } ;# (a)
    if {$perm eq "sync" } { return $perm } ;# (b)
    if {$bit  eq "sync" } { return $bit  } ;# (c)
    # a != b, must push+pull => becomes sync  (d)
    return "sync"
}

proc ::fx::peer::PermDrop {perm bit} {
    # Current Drop New  Notes
    # ------- ---- ---- -----
    # push    push {}   (a)
    #         pull push (d)
    #         sync {}   (c)
    # ------- ---- ---- -----
    # pull    push pull (d)
    #         pull {}   (a)
    #         sync {}   (c)
    # ------- ---- ---- -----
    # sync    push pull (b)
    #         pull push (b)
    #         sync {}   (a)
    # ------- ---- ---- -----

    debug.fx/peer {}
    if {$perm eq $bit   } { return {}          } ;# (a)
    if {$perm eq "sync" } { return [Anti $bit] } ;# (b)
    if {$bit  eq "sync" } { return {}          } ;# (c)
    # perm != bit, must push+pull => keep perm      (d)
    return $perm
}

proc ::fx::peer::Anti {bit} {
    if {$bit eq "push" } { return "pull" }
    if {$bit eq "pull" } { return "push" }
    # sync becomes nothing, although should not be reached
    # given how it is called (see PermDrop)
    return {}
}

proc ::fx::peer::Get {config} {
    debug.fx/peer {}

    # All peering information is loaded, and merged into a single
    # structure.
    #
    # dict: "fossil" + url + area -> direction
    #       "git" + url           -> last-uuid

    set map {}

    # I. Fossil peers
    dict for {url dlist} [map get peer@fossil] {
	foreach {area dir} {
	    $config @configarea set $area
	    $config @syncdir    set $dir

	    dict set map fossil $url \
		[$config @configarea] \
		[$config @syncdir]
	}
    }

    # II. Git peers.
    # Note how the configuration contains state information.
    # (Last uuid pushed to git mirror).
    dict for {url last} [map get peer@git] {
	dict set map git $url $last
    }
    return $map
}

proc ::fx::peer::Init {} {
    debug.fx/peer {}
    # Redefine to nothing for all future calls.
    proc ::fx::peer::Init {} {}

    # Create mappings used to store peering information. Note how
    # their names use illegal characters. This makes them inaccessible
    # to the regular map commands, preventing users from messing
    # things up by direct editing. Of course, they still can do that
    # via direct database access and sql commands, so the commands
    # above will still validate the data they get from the repository

    # peer@fossil: repo url -> dict (area dir ...)
    # peer@git   : repo url -> last uuid sync'd so far.

    foreach map {
	peer@fossil
	peer@git
    } {
	if {[map has $map]} continue
	map create $map
    }
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::peer 0
return
