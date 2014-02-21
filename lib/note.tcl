## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::note 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta require     ?
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require fx::table
package require fx::mgr::config

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::note {
    namespace export \
	mail-config-show mail-config-set mail-config-unset \
	route-add route-list route-drop deliver
    namespace ensemble create

    namespace import ::fx::mgr::config
    namespace import ::fx::table::do
    rename do table
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::mail-config-show {config} {

    set settings [config get-list [$config @repository-db]]
    set settings [dict filter $settings key fx-aku-note-*]

    # Should possibly add info for missing keys, i.e. their defaults.
    # fx-aku-note-mail-debug	0
    # fx-aku-note-mail-tls	0
    # fx-aku-note-mail-user	''
    # fx-aku-note-mail-password	''
    # fx-aku-note-mail-host	localhost
    # fx-aku-note-mail-port	25
    # fx-aku-note-mail-sender	''	Mandatory

    # TODO: Have to drop the keys holding the route information.

    set data {}
    dict for {k v} $settings {
	lassign $v where mtime value
	regsub {^fx-aku-note-} $name {} name
	set isglobal [expr { ($where eq "G") ? "*" : "" }]
	if {$mtime ne {}} {
	    set mtime [clock format $mtime]
	}
	lappend data [list $name $isglobal $mtime $value]
    }

    [table t {Key Global Last-Changed Value} {
	foreach item [lsort -dict -index 0 $data] {
	    $t add {*}$item
	}
    }] show
    return
}

proc ::fx::note::mail-config-set {config} {
    # See also "fx::config::set"
    # equivalent with shorter user-visible keys

    set global [$config @global]
    set name   [$config @key]
    set value  [$config @value]
    set db     [$config @repository-db]

    puts -nonewline "Setting ${name}: "

    config set $global $db $name $value

    if {$global} {
	set current [config get-global $name]
	set suffix  " (global)"
    } else {
	set current [config get-local $db $name]
	set suffix  {}
    }

    puts '$current'$suffix
    return
}

proc ::fx::note::mail-config-unset {config} {
    set name   [$config @setting]
    set global [$config @global]

    puts -nonewline "Unsetting ${name}"

    config unset $global [$config @repository-db] $name

    puts ""
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::route-list {config} {
    # @repository(-db)

    set settings [config get-list [$config repository-db]]
    set settings [dict filter $settings key fx-aku-note-*]

    # We now have routes and standard settings mixed.
    # Get rid of the non-routes

    set data {}
    foreach k [lsort -dict [dict keys $settings]] {
	# dynamic route through ticket field
	if {[string match fx-aku-note-field:* $k]} {
	    regsub {^fx-aku-note-field:} $k {} field
	    lappend data [list ticket $field]
	    continue
	}
	# fixed route for event
	if {[string match fx-aku-note-send2-*:* $k]} {
	    regexp {^fx-aku-note-send2-([^:]*):(.*)$} $k -> event addr
	    lappend data [list $event $addr]
	    continue
	}
	# ignore everything else
    }

    [table t {Event Route} {
	foreach item [lsort -dict -index 0 [lsort -dict -index 1 $data]] {
	    $t add {*}$item
	}
    }] show
    return
}

proc ::fx::note::route-add {config} {
    # @to (list), @event, @repository(-db)
    if {[RouteAdd [$config @repository-db] \
	     fx-aku-note-send2-[$config @event]: \
	     [$config @to]]} {
	WatchMe [$config @repository]
    }
    return
}

proc ::fx::note::route-drop {config} {
    # @to (list), @event, @repository(-db)
    if {[RouteDrop [$config @repository-db] \
	     fx-aku-note-send2-[$config @event]: \
	     [$config @to]] &&
	![HasRoutes [$config @repository-db]]
    } {
	RemoveMe [$config @repository]
    }
}

proc ::fx::note::field-list {config} {
    # @repository-db
    set db [$config @repository-db]
    set columns {}

    # table_info fields: cid, name, type, notnull, dflt_value, pk
    $db eval "PRAGMA table_info(ticket)" ti {
	lappend columns $ti(name)
    }
    $db eval "PRAGMA table_info(ticketchng)" ti {
	lappend columns $ti(name)
    }

    [table t Field {
	foreach col [lsort -dict -unique $columns] {
	    # Ignore system columns.
	    if {[string match tkt_* $col]} continue
	    $t add $col
	}
    }] show
    return
}

proc ::fx::note::route-field-add {config} {
    # @field (list), @repository(-db)
    if {[RouteAdd [$config @repository-db] \
	     fx-aku-note-field: \
	     [$config @field]]} {
	WatchMe [$config @repository]
    }
    return
}

proc ::fx::note::route-field-drop {config} {
    # @field (list), @repository(-db)
    if {[RouteDrop [$config @repository-db] \
	     fx-aku-note-field: \
	     [$config @field]] &&
	![HasRoutes [$config @repository-db]]
    } {
	RemoveMe [$config @repository]
    }
}

# # ## ### ##### ######## ############# ######################
## API. Run over (all) repository/ies and generate notifications
## for all events not yet handled (i.e. not marked as seen).

proc ::fx::note::route-deliver {config} {
    # @repository, @global, /... ?? --all how ?

    if {[$config @all]} {
	config get-list-global {
	    # name, value, mtime
	    if {![string match fx-aku-note-watch:* $name]} continue
	    # Run deliver on the named repository.
	    # Recursive call through cli
	    regsub {^fx-aku-note-watch:} $name {} name
	    fx do deliver -R $name
	}
	return
    }

    # Delivery for single repository.

    # Determine not-yet-seen events.
    # Per event:
    #  Generate a mail
    #    Mail content is dependent on event type
    #  Determine receivers
    #  Send mail
    #  Remember as seen
    return
}

# # ## ### ##### ######## ############# ######################
## Internal helpers: Low level generic route management.

proc ::fx::note::RouteAdd {db prefix destinations} {
    set added 0

    foreach dst $destinations {
	puts -nonewline "  $dst ... "

	set key ${prefix}:$dst
	if {[config has $db $key]} {
	    puts "Already known"
	} else {
	    config set 0 $db $key
	    puts "Added"
	    incr added
	}
    }
    return $added
}

proc ::fx::note::RouteDrop {db prefix destinations} {
    set removed 0

    foreach pattern $destinations {
	puts -nonewline "  $dst ... "

	set key ${prefix}:$dst
	set by [config unset-glob 0 $db $key]
	if {!$by} {
	    puts "Ignored, no match"
	} else {
	    puts "Removed $by"
	    incr removed $by
	}
    }
    return $removed
}

proc ::fx::note::HasRoutes {db} {
    return [expr { [config has-glob fx-aku-note-send2-*:*] ||
		   [config has-glob fx-aku-note-field:*]      }]
}

# # ## ### ##### ######## ############# ######################
## Internal helpers.
## (De)register the repository in the global database, 'deliver all'

proc ::fx::note::WatchMe {r} {
    config set 1 fx-aku-note-watch:$r 1
}

proc ::fx::note::RemoveMe {r} {
    config unset 1 fx-aku-note-watch:$r
}

# # ## ### ##### ######## ############# ######################
package provide fx::note 0
return
