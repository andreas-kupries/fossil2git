## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::fossil 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     sqlite3
# Meta subject     fossil
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require sqlite3
package require debug
package require debug::caller
package require fx::color

debug level  fx/fossil
debug prefix fx/fossil {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval ::fx {
    namespace export fossil
    namespace ensemble create
}
namespace eval ::fx::fossil {
    namespace export \
	c_show_repository c_set_repository c_reset_repository \
	c_default_repository \
	branch-of changeset reveal user-info users user-config \
	get-manifest fx-tables fx-enums fx-enum-items \
	ticket-title ticket-fields global global-location \
	repository repository-location set-repository-location \
	show-repository-location repository-find repository-open
	
    namespace ensemble create

    namespace import ::fx::color

    # Cached location of the repository we are working with.
    variable repo_location {}
    # Information about where the location came from (one of 'user',
    # 'checkout', or 'default').
    variable repo_origin {}

    # Location of a fossil binary for things we are shelling out to
    # (still, although only 'get-manifest' does).
    variable fossil [auto_execok fossil]

    # Configuration key used to save/read the current repository.
    variable rkey "fx-aku-current-repository"
}

# # ## ### ##### ######## ############# ######################

proc ::fx::fossil::c_show_repository {config} {
    debug.fx/fossil {}
    show-repository-location
    return
}

proc ::fx::fossil::c_set_repository {config} {
    debug.fx/fossil {}
    variable rkey
    # Note that we are effectively inlining the command
    #    "fx::mgr::config::set-global".
    # We have to, to avoid a dependency cycle with fx::mgr::config.

    # Determine location, as absolute path.
    set location [file normalize [$config @target]]

    # Save to external global configuration
    global eval {
	INSERT OR IGNORE INTO global_config
	VALUES (:rkey, :location);

	UPDATE global_config
	SET   value = :location
	WHERE name  = :rkey
    }

    # Update in-memory information, for the display following.
    clear-repository-location
    set-repository-location $location default

    show-repository-location
    return
}

proc ::fx::fossil::c_reset_repository {config} {
    debug.fx/fossil {}
    variable rkey
    # Note that we are effectively inlining the commands
    #    "fx::mgr::config::unset-global", and "...::has-global".
    # We have to, to avoid a dependency cycle with fx::mgr::config.

    # Load current default, if there is any. Abort early if not.
    set havedefault 0
    global eval {
	SELECT value AS location
	FROM  global_config
	WHERE name  = :rkey
    } {
	incr havedefault
	clear-repository-location
	set-repository-location $location default
	debug.fx/fossil {==> default $location}
    }

    if {!$havedefault} {
	puts [color warning {No default repository known, done nothing}]
	return
    }

    # Remove from external configuration.
    global eval {
	DELETE
	FROM global_config
	WHERE name = :rkey
    }

    # Show what was unset, and clear from memory as well.
    show-repository-location " [color warning {Now unset}]"
    clear-repository-location
    return
}

proc ::fx::fossil::c_default_repository {config} {
    debug.fx/fossil {}
    variable rkey
    # Note that we are effectively inlining the commands
    #    "fx::mgr::config::has-global".
    # We have to, to avoid a dependency cycle with fx::mgr::config.

    # Load current default, if there is any. Abort early if not.
    set havedefault 0
    global eval {
	SELECT value AS location
	FROM  global_config
	WHERE name  = :rkey
    } {
	incr havedefault
	clear-repository-location
	set-repository-location $location default
	debug.fx/fossil {==> default $location}
    }

    if {!$havedefault} {
	puts [color warning {No default repository known}]
	return
    }

    # Show the current setting, and clear it from memory again.
    show-repository-location
    clear-repository-location
    return
}

# # ## ### ##### ######## ############# ######################
## Commands for global and repository databases.

proc ::fx::fossil::global {args} {
    debug.fx/fossil {1st call, create and short-circuit all following}
    # Drop the procedure.
    rename ::fx::fossil::global {}

    # And replace it with the database command.
    sqlite3 ::fx::fossil::global [global-location]

    if {![llength $args]} return

    # Run the new database on the arguments.
    try {
	set r [uplevel 1 [list ::fx::fossil::global {*}$args]]
    } on return {e o} {
	# tricky code here. We have rethrow with -code return to keep
	# the semantics in case we are called with the 'transaction'
	# method here, which passes a 'return' of the script as its
	# own 'return', and we must do the same here.
	return {*}$o -code return $e
    }
    return $r
}

proc ::fx::fossil::repository {args} {
    debug.fx/fossil {fail}
    # This procedure will be overwritten by 'repository-open' below.
    ::global argv0
    return -code error \
	-errorcode {FX FOSSIL REPOSITORY UNKNOWN} \
	"[file tail $argv0] was not able to determine the repository"
}

# # ## ### ##### ######## ############# ######################

proc ::fx::fossil::repository-open {p} {
    debug.fx/fossil {}
    # cmdr generate callback

    # NOTE how we are keeping the repository database until process
    # end. We assume that this command is called only once. See also
    # the fx cmdr specification (fx.tcl).

    set location [$p config @repository]

    # Note: If the repository was not specified the search process
    # will have already set the variable below. However for a
    # user-specified location the search did not happen, leaving it
    # uninitialized. So we do that now, making sure.
    set-repository-location $location user

    debug.fx/fossil {@ $location}
    if {$location eq {}} {
	# Do not create a repository db if we have no location for it
	# (see repo-location below, use case "all").
	return {}
    }

    sqlite3 ::fx::fossil::repository $location
    return  ::fx::fossil::repository
}

# # ## ### ##### ######## ############# ######################

proc ::fx::fossil::global-location {} {
    debug.fx/fossil {}
    return [file normalize ~/.fossil]
}

proc ::fx::fossil::show-repository-location {{suffix {}}} {
    debug.fx/fossil {}
    variable repo_location
    variable repo_origin
    puts "[color warning [string totitle $repo_origin]] @ [color note $repo_location]$suffix"
    return
}

proc ::fx::fossil::repository-location {} {
    variable repo_location
    debug.fx/fossil {@ $repo_location}
    return  $repo_location
}

proc ::fx::fossil::set-repository-location {path origin} {
    debug.fx/fossil {@ $origin ($path)}
    variable repo_location
    variable repo_origin

    # Skip when already defined.
    if {$repo_origin ne {}} return

    set repo_location $path
    set repo_origin   $origin
    return
}

proc ::fx::fossil::clear-repository-location {} {
    debug.fx/fossil {}
    variable repo_location {}
    variable repo_origin   {}
    return
}

proc ::fx::fossil::repository-find {p} {
    debug.fx/fossil {}
    # cmdr generate callback

    if {[$p config has @no-search] ||
	([$p config has @all] && [$p config @all set?])} {
	# Leave the single repository undefined, do not even try to
	# find it. This way we cannot run into an error when an "all"
	# operation is run outside of a checkout and without a
	# "repository".
	debug.fx/fossil {skip on --all, or <no-search>}
	return {}
    }

    # NOTE how we are keeping the checkout database until process end.
    # Assumes that locate is called only once. See also fx cmdr
    # specification.

    # Get checkout directory and database.
    try {
	set ckout [ckout [scan-up Repository [pwd] fx::fossil::is]]
	debug.fx/fossil {checkout located @ $ckout}
    } trap {FX FOSSIL SCAN-UP}  {e o} - \
      trap {FX FOSSIL CHECKOUT} {e o} {
	# Check if a target is set. If yes, use that as our
	# repository. Otherwise rethrow the error, making it public.

	# Note that we are effectively inlining the command
	# "fx::mgr::config::get-global". We have to, to avoid a
	# dependency cycle.

	variable rkey
	global eval {
	    SELECT value AS location
	    FROM  global_config
	    WHERE name  = :rkey
	} {
	    if {[file pathtype $location] ne "absolute"} {
		return -code error \
		    -errorcode {FX REPOSITORY DEFAULT PATHTYPE} \
		    "Bad default repository, expected an absolute path, got $location"
	    }

	    set-repository-location $location default
	    debug.fx/fossil {done ==> default $location}
	    return $location
	}

	return {*}$o $e
    }
    sqlite3 CK $ckout

    # Retrieve repository location. This may be relative (to the
    # checkout directory).
    set location [CK onecolumn {
	SELECT value
	FROM vvar
	WHERE name = 'repository'
    }]
    debug.fx/fossil {directed to  $location}

    # Merge the path of the checkout directory and the location it
    # refered to, to resolve relative paths in the context of the
    # checkout, not the working directory. Of couse, an absolute
    # repository location supercedes the preceding path segments.
    set location [file join [file dirname $ckout] $location]
    debug.fx/fossil {resolved as  $location}

    # Normalize to make the path nicer.
    set location [file normalize $location]
    debug.fx/fossil {normalized as $location}

    rename CK {}

    set-repository-location $location checkout
    debug.fx/fossil {done ==> checkout $location}
    return $location
}

# # ## ### ##### ######## ############# ######################

proc ::fx::fossil::fx-enum-items {table} {
    debug.fx/fossil {}
    return [repository eval [subst {
	SELECT item
	FROM   $table
	ORDER BY item
    }]]
}

proc ::fx::fossil::fx-enums {} {
    debug.fx/fossil {}
    set enums {}
    foreach table [fx-tables] {
	if {![string match fx_aku_enum_* $table]} continue
	regsub {^fx_aku_enum_} $table {} enum
	lappend enums $enum
    }
    return $enums
}

proc ::fx::fossil::fx-tables {} {
    debug.fx/fossil {}
    set tables {}
    repository eval {
	SELECT name
	FROM sqlite_master
	WHERE type = 'table'
	AND   name LIKE 'fx_aku_%'
	;
    } {
	lappend tables [string tolower $name]
    }
    return $tables
}

proc ::fx::fossil::ticket-title {uuid} {
    debug.fx/fossil {}
    # TODO: get configured name of the title field.
    set titlefield title

    return [fossil repository onecolumn [subst {
	SELECT $titlefield
	FROM ticket
	WHERE tkt_uuid = :uuid
    }]]
}

proc ::fx::fossil::ticket-fields {} {
    debug.fx/fossil {}
    # table_info fields: cid, name, type, notnull, dflt_value, pk
    # Looking at tables "ticket" and "ticketchng".

    set columns {}
    repository eval {
	PRAGMA table_info(ticket)
    } ti {
	lappend columns $ti(name)
    }
    repository eval {
	PRAGMA table_info(ticketchng)
    } ti {
	lappend columns $ti(name)
    }

    return [lsort -unique $columns]
}

proc ::fx::fossil::get-manifest {uuid} {
    debug.fx/fossil {}
    variable fossil
    variable repo_location

    # We go through a temp file so that we can load the result with
    # proper binary translation. That is something 'exec' does not
    # provide for its results, that is always auto.
    #
    # We spawn the actual fossil executable to avoid having to write
    # our own implementation of the delta-decoder, and of inflate.
    #
    # FUTURE: Consider writing and using a Tcl binding to libfossil.

    set afile [pid].$uuid
    set efile [pid].error

    try {
	# There may be race conditions which cause the spawned process
	# to error with 'database locked'. If that happens we back up
	# and try again (up to 10 times). After that we throw a nice
	# error for the higher layers to handle.

	# TODO: future: make it configurable
	set trials 10
	while {[catch {
	    debug.fx/fossil {go}
	    exec > $afile 2> $efile \
		{*}$fossil artifact $uuid -R $repo_location
	} e o]} {
	    debug.fx/fossil {caught out: $e}

	    # Read the error message to see if this is about
	    # blocking. If not we throw the issue up immediately,
	    # without retrying.

	    set theerror [fileutil::cat $efile]

	    debug.fx/fossil {message.1 = [lindex [split $theerror \n] 0]}

	    if {![string match *locked* $theerror]} {
		debug.fx/fossil {rethrow}
		return {*}$o $e
	    }

	    debug.fx/fossil {locked @$trials}

	    incr trials -1
	    if {!$trials} {
		debug.fx/fossil {giving up}
		# Lock has not cleared in some time, giving up.
		return -code error \
		    -errorcode {FOSSIL PROCESS LOCKED} \
		    "artifact retrieval locked"
	    }
	    # Wait a bit first, to clear the condition.
	    # TODO: Make the delay configurable.
	    debug.fx/fossil {delay and retry}
	    after 500
	}

	set archive [fileutil::cat -translation binary -encoding binary $afile]
    } finally {
	# Ensure removal of temp files in presence of errors.
	# (Note however that this is not enough to deal with ^C).
	file delete $afile
	file delete $efile

	debug.fx/fossil {cleaned temp files}
    }

    debug.fx/fossil {done ==> <content elided>}
    return $archive
}

proc ::fx::fossil::branch-of {uuid} {
    debug.fx/fossil {}
    return [repository onecolumn {
	SELECT tag.tagname
	FROM blob, tagxref, tag
	WHERE blob.uuid = :uuid
	AND blob.rid = tagxref.rid
	AND tagxref.tagtype > 0
	AND tagxref.tagid = tag.tagid
    }]
}

proc ::fx::fossil::changeset {uuid} {
    debug.fx/fossil {}
    set r {}
    repository eval {
        SELECT filename.name AS thepath,
               CASE WHEN nullif(mlink.pid,0) is null THEN 'added'
                    WHEN nullif(mlink.fid,0) is null THEN 'deleted'
                    ELSE                                  'edited'
               END AS theaction
        FROM   mlink, filename, blob
        WHERE  mlink.mid  = blob.rid
	AND    blob.uuid = :uuid
        AND    mlink.fnid = filename.fnid
        ORDER BY filename.name
    } {
	dict lappend r $theaction $thepath
    }
    return $r
}

proc ::fx::fossil::reveal {value} {
    debug.fx/fossil {}
    if {$value eq {}} { return $value }
    repository eval {
	SELECT content
	FROM concealed
	WHERE hash = :value
    } {
	set value $content
    }
    return $value
}

proc ::fx::fossil::user-info {value} {
    debug.fx/fossil {}
    if {$value eq {}} { return $value }
    repository eval {
	SELECT info
	FROM user
	WHERE login = :value
    } {
	set value $info
    }
    return $value
}

proc ::fx::fossil::user-config {} {
    debug.fx/fossil {}
    return [repository eval {
	SELECT login, cap, info, mtime
	FROM user
    }]
}

proc ::fx::fossil::users {} {
    debug.fx/fossil {}
    return [repository eval {
	SELECT login
	FROM user
    }]
}

# # ## ### ##### ######## ############# ######################

proc ::fx::fossil::is {dir} {
    debug.fx/fossil {}
    foreach control {
	_FOSSIL_
	.fslckout
	.fos
    } {
	debug.fx/fossil {iterate $control}
	set control $dir/$control
	if {[file exists $control] &&
	    [file isfile $control]
	} {
	    debug.fx/fossil {done ==> HIT}
	    return 1
	}
    }
    debug.fx/fossil {done ==> MISS}
    return 0
}

proc ::fx::fossil::ckout {dir} {
    debug.fx/fossil {}
    foreach control {
	_FOSSIL_
	.fslckout
	.fos
    } {
	debug.fx/fossil {iterate $control}
	set control $dir/$control
	if {[file exists $control] &&
	    [file isfile $control]
	} {
	    debug.fx/fossil {done ==> $control}
	    return $control
	}
    }
    return -code error \
	-errorcode {FX FOSSIL CHECKOUT} \
	"Not a checkout: $dir"
}

proc ::fx::fossil::scan-up {this dir predicate} {
    debug.fx/fossil {}
    set dir [file normalize $dir]
    while {1} {
	debug.fx/fossil {iterate $dir}

	# Found the proper directory, per the predicate.
	if {[{*}$predicate $dir]} {
	    debug.fx/fossil {done ==> $dir}
	    return $dir
	}

	# Not found, walk to parent
	set new [file dirname $dir]

	# Stop when reaching the root.
	if {($new eq $dir) ||
	    ($new eq {})}   {
	    debug.fx/fossil {done ==> nothing found ($new)}
	    return {}
	}

	# Ok, truly walk up.
	set dir $new
    }
    return -code error \
	-error {FX FOSSIL SCAN-UP} \
	"$this not found"
}

# # ## ### ##### ######## ############# ######################
package provide fx::fossil 0
return
