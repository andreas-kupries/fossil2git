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
package require fileutil
package require interp
package require linenoise
package require textutil::adjust
package require try

package require fx::fossil
package require fx::mailer
package require fx::mgr::config
package require fx::mgr::map
package require fx::table
package require fx::util

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::peer {
    namespace export \
	list add remove add-git remove-git exchange
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::fx::fossil
    namespace import ::fx::mailer
    namespace import ::fx::mgr::config
    namespace import ::fx::mgr::map
    namespace import ::fx::util

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
    variable dadd
    set old [dict get spec $area]
    set new [dict get $dadd $old $direction]

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
    variable dremove
    set old [dict get spec $area]
    set new [dict $dremove $old $direction]

    if {$new eq $old} {
	puts [color note {No change, ignored}]
	return
    }

    if {$new eq {}} {
	# No directions left for the area, drop entire area.
	dict unset spec $area
    } else {
	# Change to reduced directions of the area.
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

proc ::fx::peer::state-dir {config} {
    debug.fx/peer {}
    fossil show-repository-location

    if {[$config @dir set?]} {
	# Specified, set value.
	config set fx-aku-peer-git-state [$config @dir]
    }

    # Show current value, possibly set above.
    puts [statedir]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::peer::exchange {config} {
    debug.fx/peer {}
    fossil show-repository-location

    # See also note.tcl, ProjectInfo.
    set location [mailer get location]
    set	project  [mailer get project-name]

    set map [Get $config]
    # dict: "fossil" + url + area -> direction
    #       "git" + url           -> last-uuid

    # Note: The dictsort means that fossil peers are handled before
    # git peers. That is good because it means that any new content
    # pulled from one or more of the fossil peers will be pushed
    # immediately to the git peers, instead of getting delayed by one
    # exchange cycle.

    dict for {type spec} [util dictsort $map] {
	switch -exact -- $type {
	    fossil {
		dict for {url espec} [util dictsort $spec] {
		    dict for {area dir} [util dictsort $espec] {
			# Exchange data for area, per chosen direction.
			# Invokes regular fossil to perform the action.
			puts "Fossil Exchange $url: $dir $area ..."

			fossil exchange $url $area $direction
		    }
		}
	    }
	    git {
		set state [Statedir]

		GitSetup $state $project $location
		set current [GitImport $state $project $location

		dict for {url last} [util dictsort $spec] {
		    # Skip destinations which are uptodate.
		    puts -nonewline "Git    Exchange $url: push content ... "
		    if {$last eq $current} {
			puts [color note "Up-to-date, skipping"]
			continue
		    }
		    puts "Go"
		    GitPush $state $url

		    # Update the per-destination state, last uuid pushed to it.
		    map remove1 peer@fossil $url
		    map add1    peer@fossil $url $current
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

proc ::fx::peer::Statedir {} {
    debug.fx/peer {}
    return [config get-with-default \
		fx-aku-peer-git-state \
		[fossil repository-location]-git-state]
}

# taken from old setup-import script.
proc ::fx::peer::GitSetup {statedir project location} {
    debug.fx/peer {}
    if {[file exists $statedir] &&
	[file isdirectory $statedir] &&
	[file exists $statedir/.git] &&
	[file isdirectory $statedir/.git]} {
	debug.fx/peer {/initialized}
	return
    }

    # State directory is not initialized. Do it now.
    # Drop anything else which may existed in its place.
    debug.fx/peer {initialize now}

    # The git state is a sub-directory of the main state directory
    # This allows us to put other (more transient) state as a sibling
    # of the git directory while not requiring additional path
    # configuration keys.
    set git [file join $statedir git]

    file delete -force $statedir
    file mkdir $git

    set ::env(TZ) UTC
    puts "\tSetting up $statedir ..."
    Run git --bare --git-dir=$git init
    file rename --force \
	$git/hooks/post-update.sample \
	$git/hooks/post-update

    fileutil::touch     $git/git-daemon-export-ok
    fileutil::writeFile $git/description \
	"Mirror of the $project fossil repository at $location\n"

    debug.fx/peer {/done initialization}
    return
}

proc ::fx::peer::GitImport {statedir project location} {
    debug.fx/peer {}

    set git $statedir/git
    set tmp $statedir/tmp

    GitMakeReadme $git $project $location

    set current [fossil last-uuid]
    set last    [GitLastImported $git]

    puts "Git    @ $last"
    puts "Fossil @ $current"

    if {$last eq $current} {
	puts [color note "no new commits"]
	return $current
    }

    file mkdir $tmp
    try {
	set first   [expr {$lastid eq {}}]
	set elapsed [GitPull $tmp $git $first]
	puts [color note "imported new commits to git mirror in $elapsed min"]

	# Remember how far we imported.
	GitUpdateImported $git $current
    } finally {
	file delete -force $tmp
    }

    return $current
}

proc ::fx::peer::GitMakeReadme {git project location} {
    debug.fx/peer {}
    set date [Now]

    lappend map @PROJECT $project
    lappend map @URL     $location
    lappend map @DATE    $date
    
    fileutil::writeFile $git/README.html [string map $map {
	<p>This repository is a mirror of the
	<a href="@URL">@PROJECT fossil repository</a>.
	Last updated on @DATE.</p>
    }]
    return
}

proc ::fx::peer::Now {} {
    clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S}
}

proc ::fx::peer::GitLastImported {git} {
    set idfile $git/fossil-import-id
    if {![file exists $idfile]} {
	return {}
    }
    return [string trim [fileutil::cat $idfile]]
}

proc ::fx::peer::GitUpdateImported {git current} {
    set idfile $git/fossil-import-id
	    fileutil::writeFile $idfile $current
    return
}

proc ::fx::peer::GitPull {tmp git first} {
    set begin [clock seconds]

    set src [fossil repository-location]

    file delete -force $tmp
    file mkdir         $tmp

    Run git --bare  --git-dir $tmp init
    Run fossil export -R $src --git | git --bare --git-dir $tmp fast-import

    # Ensure that the new repository contains the HEAD of the old
    # repository.  If something goes wrong in the import then all the
    # commit ids get peturbed from the point of corruption on up and
    # this test will fail. If all is ok then this id will be present
    # in the new repo and we can push the new commits.

    if {!$first} {
	if {[catch {
	    set ref [Runx git --bare --git-dir $git rev-parse HEAD]
	    Run git --bare --git-dir $tmp cat-file -e $ref
	} msg]} {
	    puts [color error "review $tmp for errors: $msg"]
	    return 0
	}
    }

    # Rename trunk to master to suit git terminology better.
    file rename $tmp/refs/heads/trunk $tmp/refs/heads/master

    # Push the new changes from tmp to local destination
    Run git --bare --git-dir $tmp remote add target $git
    Run git --bare --git-dir $tmp push --force target --all
    Run git --bare --git-dir $tmp push --force target --tags

    file delete -force $tmp
    set elapsed [expr {([clock seconds] - $begin)/60}]

    # Also - after the very first import you need to repack the git
    # repository using 'git repack -adf --window=50' to avoid an
    # excessively large repo.  git fast-import is fast, not space
    # efficient - so always repack.

    if {$first} {
	Run git --bare  --git-dir $git repack -adf --window=50
    }

    # Done pulling in changes
    return $elapsed
}

proc ::fx::peer::GitPush {statedir remote} {
    # Perform garbage collect as required
    set git $statedir/git

    set count [runx git --bare --git-dir $git count-objects | awk {{print $1}}]
    if {$count > 50} {
	run git --bare --git-dir $git gc
    }

    log "push to $remote"

    #return

    run git --bare --git-dir $git push --mirror $remote
    return
}
#-----------------------------------------------------------------------------

proc  ::fx::peer::Silent {args} {
    debug.fx/peer {}
    exec 2> /dev/null > /dev/null {*}$args
}

proc  ::fx::peer::Runx {args} {
    debug.fx/peer {}
    exec 2>@ stderr {*}$args
}

proc ::fx::peer::Run {args} {
    debug.fx/peer {}
    exec 2>@ stderr >@ stdout {*}$args
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
## Tables to manipulate the direction pseudo-bits.
## The explicit tables are easier to maintain and understand
## than coding the implied decision table.

namespace eval ::fx::peer {
    variable dadd {
	push {
	    push push
	    pull sync
	    sync sync
	}
	pull {
	    push sync
	    pull pull
	    sync sync
	}
	sync {
	    push sync
	    pull sync
	    sync sync
	}
    }

    variable dremove {
	push {
	    push {}
	    pull push
	    sync {}
	}
	pull {
	    push pull
	    pull {}
	    sync {}
	}
	sync {
	    push pull
	    pull push
	    sync {}
	}
    }
}

# # ## ### ##### ######## ############# ######################
package provide fx::peer 0
return
