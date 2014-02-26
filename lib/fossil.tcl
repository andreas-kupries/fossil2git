## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::fossil 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta require     sqlite3
# Meta subject     fossil
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require sqlite3

namespace eval ::fx::fossil {
    namespace export \
	global global-location \
	repository repository-location \
	repository-open repository-find \
	fx-tables fx-enums fx-enum-items \
	ticket-title ticket-fields get-manifest
    namespace ensemble create

    # Cached location of the repository we are working with.
    variable repo_location {}

    # Location of a fossil binary for things we are shelling out
    # (still).
    variable fossil [auto_execok fossil]
}

# # ## ### ##### ######## ############# ######################
## Commands for global and repository databases.

proc ::fx::fossil::global {args} {
    # Drop the procedure.
    rename ::fx::fossil::global {}

    # And replace it with the database command.
    sqlite3 ::fx::fossil::global [global-location]

    if {![llength $args]} return

    # Run the new database on the arguments.
    return [uplevel 1 [list ::fx::fossil::global {*}$args]]
}

proc ::fx::fossil::repository {args} {
    # This procedure will be overwritten by 'repository-open' below.
    global argv0
    return -code error \
	-errorcode {FX FOSSIL REPOSITORY UNKNOWN} \
	"$argv0 was not able to determine the repository"
}

# # ## ### ##### ######## ############# ######################

proc ::fx::fossil::repository-open {p} {
    # cmdr generate callback

    # NOTE how we are keeping the repository database until process
    # end.  Assumes that locate is called only once. See also fx cmdr
    # specification.

    set location [$p config @repository]
    if {$location eq {}} {
	# Do not create a repository db if we have no location for it
	# (see repo-location below, use case "all").
	return {}
    }

    sqlite3 ::fx::fossil::repo $location
    return  ::fx::fossil::repo
}

# # ## ### ##### ######## ############# ######################

proc ::fx::fossil::global-location {} {
    return ~/.fossil
}

proc ::fx::fossil::repository-location {} {
    variable repo_location
    return  $repo_location
}

proc ::fx::fossil::repository-find {p} {
    # cmdr generate callback
    variable repo_location

    if {[$p config has @all] && [$p config @all set?]} {
	# Leave the single repository undefined, do not even try to
	# find it. This way we cannot run into an error when an "all"
	# operation is run outside of a checkout and without a
	# "repository".
	return {}
    }

    # NOTE how we are keeping the checkout database until process end.
    # Assumes that locate is called only once. See also fx cmdr
    # specification.

    sqlite3 CK [ckout [scan-up Repository [pwd] fx::fossil::is]]

    set repo_location [file normalize [CK onecolumn {
	SELECT value
	FROM vvar
	WHERE name = 'repository'
    }]]

    rename CK {}
    return $repo_location
}

# # ## ### ##### ######## ############# ######################

proc ::fx::fossil::fx-enum-items {table} {
    return [repository eval [subst {
	SELECT item
	FROM   $table
	ORDER BY item
    }]]
}

proc ::fx::fossil::fx-enums {} {
    set enums {}
    foreach table [fx-tables] {
	if {![string match fx_aku_enum_* $table]} continue
	regsub {^fx_aku_enum_} $table {} enum
	lappend enums $enum
    }
    return $enums
}

proc ::fx::fossil::fx-tables {} {
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
    # TODO: get configured name of the title field.

    set titlefield title
    return [fossil repository onecolumn [subst {
	SELECT $titlefield
	FROM ticket
	WHERE tkt_uuid = :uuid
    }]]
}

proc ::fx::fossil::ticket-fields {} {
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
    variable fossil
    variable repo_location
    return [exec {*}$fossil artifact $uuid -R $repo_location]
}

# # ## ### ##### ######## ############# ######################

proc ::fx::fossil::is {dir} {
    foreach control {
	_FOSSIL_
	.fslckout
	.fos
    } {
	set control $dir/$control
	if {[file exists $control] &&
	    [file isfile $control]
	} {return 1}
    }
    return 0
}

proc ::fx::fossil::ckout {dir} {
    foreach control {
	_FOSSIL_
	.fslckout
	.fos
    } {
	set control $dir/$control
	if {[file exists $control] &&
	    [file isfile $control]
	} {return $control}
    }
    return -code error \
	-errorcode {FX FOSSIL CHECKOUT} \
	"Not a checkout: $dir"
}

proc ::fx::fossil::scan-up {this dir predicate} {
    set dir [file normalize $dir]
    while {1} {
	# Found the proper directory, per the predicate.
	if {[{*}$predicate $dir]} {
	    return $dir
	}

	# Not found, walk to parent
	set new [file dirname $dir]

	# Stop when reaching the root.
	if {$new eq $dir} { return {} }
	if {$new eq {}} { return {} }

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
