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
package require fx::fossil
package require fx::mailer
package require fx::mailgen
package require fx::manifest
package require fx::mgr::config
package require fx::seen
package require fx::table
package require fx::validate::event-type
package require fx::validate::mail-config

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::note {
    namespace export \
	mail-config-show mail-config-set mail-config-unset \
	route-add route-drop route-list route-field-add \
	route-field-drop deliver event-list field-list \
	mark-pending mark-notified mark-pending-all mark-notified-all \
	show-pending test-parse test-mail-gen test-mail-config \
	test-mail-receivers

    namespace ensemble create

    namespace import ::fx::fossil
    namespace import ::fx::mailer
    namespace import ::fx::mailgen
    namespace import ::fx::manifest
    namespace import ::fx::mgr::config
    namespace import ::fx::seen
    namespace import ::fx::table::do
    rename do table

    namespace import ::fx::validate::event-type
    namespace import ::fx::validate::mail-config
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::mark-pending {config} {
    seen mark-pending [$config @uuid]
    return
}

proc ::fx::note::mark-pending-all {config} {
    seen mark-pending-all
    return
}

proc ::fx::note::mark-notified {config} {
    seen mark-notified [$config @uuid]
    return
}

proc ::fx::note::mark-notified-all {config} {
    seen mark-notified-all
    return
}

proc ::fx::note::show-pending {config} {
    [table t {Id Type UUID Comment} {
	seen forall-pending type id uuid comment {
	    $t add $id $type $uuid $comment
	}
    }] show
    return
}

proc ::fx::note::test-mail-gen {config} {
    # TODO: either handle missing context in the mailgen, or
    # auto-determine a context here, or let the user specify it.

    set uuid [$config @uuid]
    puts [mail-gen artifact \
	      [manifest parse \
		   [fossil get-manifest $uuid] \
		   self $uuid \
		   {*}[ProjectInfo]]]
    return
}

proc ::fx::note::test-mail-config {config} {
    mailer send \
	[mailer get-config] \
	[$config @destination] \
	[mail-gen test]
    return
}

proc ::fx::note::test-mail-receivers {config} {
    foreach {event routes} [RouteMap] {
	# TODO: fake parameter for message generation in case of errors.
	set e [event-type validate ... $event]
	lappend map $e [list $event [lsort -unique $routes]]
    }

    set uuid [$config @uuid]
    set m [manifest parse \
	       [fossil get-manifest $uuid] \
	       self $uuid]

    lassign [dict get $map [dict get $m $type]] ex routes

    set recv [Receivers $routes $m]

    puts [join $recv \n]
    return
}

proc ::fx::note::test-parse {config} {
    set uuid [$config @uuid]
    array set m \
	[manifest parse \
	     [fossil get-manifest $uuid] \
	     self $uuid \
	     {*}[ProjectInfo]]
    parray m
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::mail-config-show {config} {
    foreach k [mail-config all] {
	set v [config get-extended-with-default \
		   [mail-config internal $k] \
		   [mail-config default  $k]]

	lassign $v isglobal mtime v

	if {$isglobal < 0} {
	    set origin Default
	} elseif {$isglobal} {
	    set origin Global
	} else {
	    set origin Repository
	}

	set mtime [expr {($mtime ne {})
			 ? [clock format $mtime]
			 : "" }]
	lappend k $v $origin $mtime
	lappend data $k
    }

    [table t {Key Value Origin Last-Changed} {
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

    # TODO: type validation per chosen setting.

    puts -nonewline "Setting [mail-config external $name]: "

    if {$global} {
	config set-global $name $value
	set current [config get-global $name]
	set suffix  " (global)"
    } else {
	config set-local $name $value
	set current [config get-local $name]
	set suffix  {}
    }

    puts '$current'$suffix
    return
}

proc ::fx::note::mail-config-unset {config} {
    set name   [$config @key]
    set global [$config @global]

    puts -nonewline "Unsetting [mail-config external $name]"

    if {$global} {
	config unset-global $name
    } else {
	config unset-local $name
    }

    puts ""
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::route-list {config} {
    # @repository(-db)

    # Retrieve data, and restructure for table.
    set data {}
    dict for {event routes} [RouteMap] {
	foreach route $routes {
	    lassign $route static destination
	    if {!$static} {
		set destination <${destination}>
	    }
	    lappend data [list $event $destination]
	}
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

    # seen event is internal rep.
    # for storage we go back to external rep.
    set e [event-type external [$config @event]]

    if {![RouteAdd \
	     fx-aku-note-send2-${e} \
	     [$config @to]]
    } return

    WatchMe [$config @repository]
    return
}

proc ::fx::note::route-drop {config} {
    # @to (list), @event, @repository(-db)

    # seen event is internal rep.
    # for storage we go back to external rep.
    set e [event-type external [$config @event]]

    if {![RouteDrop \
	     fx-aku-note-send2-$e \
	     [$config @to]] ||
	[HasRoutes]
    } return

    RemoveMe [$config @repository]
    return
}

proc ::fx::note::event-list {config} {
    # @repository-db

    set columns [event-type all]

    [table t Event {
	foreach col [lsort -dict $columns] {
	    $t add $col
	}
    }] show
    return
}

proc ::fx::note::field-list {config} {
    # @repository-db

    set columns [fossil ticket-fields]

    [table t Field {
	foreach col [lsort -dict $columns] {
	    # Ignore system columns.
	    if {[string match tkt_* $col]} continue
	    $t add $col
	}
    }] show
    return
}

proc ::fx::note::route-field-add {config} {
    # @field (list), @repository(-db)
    if {![RouteAdd \
	     fx-aku-note-field \
	     [$config @field]]
    } return

    WatchMe [$config @repository]
    return
}

proc ::fx::note::route-field-drop {config} {
    # @field (list), @repository(-db)
    if {![RouteDrop \
	     fx-aku-note-field \
	     [$config @field]] ||
	[HasRoutes]
    } return

    RemoveMe [$config @repository]
    return
}

# # ## ### ##### ######## ############# ######################
## API. Run over (all) repository/ies and generate notifications
## for all events not yet handled (i.e. not marked as seen).

proc ::fx::note::route-deliver {config} {
    # @repository, @global, /... ?? --all how ?

    if {[$config @all]} {
	# -- TODO -- Encapsulate conversions ...
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

    # Determine the routes. This gives us (implicitly)
    #   a list of the events we can ignore, too.
    # Determine not-yet-seen events.
    # Per event:
    #   Determine receivers
    #   Generate a mail
    #     Mail content is dependent on event type
    #   Send mail
    #   Remember as seen

    foreach {event routes} [RouteMap] {
	# TODO: fake parameter for message generation in case of errors.
	set e [event-type validate ... $event]
	lappend map $e [list $event [lsort -unique $routes]]
    }

    set mc [mailer get-config]

    # Other general configuration identical across all notifications.
    set pinfo [ProjectInfo]

    # Timeline event types, and associated artifact types.
    #
    # checkin ci -- manifest
    # control g  -- control
    # event   e  -- event
    # ticket  t  -- ticket change, attachment
    # wiki    w  -- wiki page, attachment
    #
    # Note how the attachment are not their own type of timeline
    # event, but are categorized underneath the associated changed
    # artifact, i.e. ticket or wiki.
    #
    # As events can have attachments as well I suspect that these
    # are handled under 'e' too, assuming consistency.

    # Mail dispatch (and receivers) are done by timeline event type.
    # Mail generation is done by artifact type, with influences by the
    # changed artifact in case of attachments (different references to
    # the changed artifact). This is provided by the 'context', holding
    # the type of timeline event <=> type of changed artifact.

    seen forall-pending type id uuid comment {
	# TODO: no mail and such when suspended.

	if {[dict exists $map $type]} {
	    # May have routes for the event, process the artifact.
	    lassign [dict get $map $type] ex routes

	    set m [manifest parse \
		       [fossil get-manifest $uuid] \
		       tcomment $comment \
		       self     $uuid \
		       context  $ex   \
		       {*}$pinfo]

	    set recv [Receivers $routes $m]

	    if {[llength $recv]} {
		mailer send $mc $recv \
		    [mailgen artifact $m]
	    }
	}
        seen touch $id
    }
    return
}

# # ## ### ##### ######## ############# ######################
## Receiver collection

proc ::fx::note::ProjectInfo {} {
    set name [config get-with-default \
		  project-name \
		  [file rootname [file tail [fossil repository-location]]]]

    set location  [config get-with-default \
		       fx-aku-note-project-location \
		       {Location not known}]

    return [dict create project $name location $location]
}

proc ::fx::note::Receivers {routes manifest} {
    set recv {}
    set compress 0
    # NOTE: The caller made sure that all route lists have unique
    # elements.

    foreach route $routes {
	lassign $route static dest

	if {$static} {
	    lappend recv $dest
	} else {
	    # dynamic route, go through the specified field to determine actual destination.
	    # TODO dynamic routing
	    #lappend recv ...
	    incr compress
	}
    }

    if {$compress} {
	# Dynamic fields may have introduced duplicate destinations.
	set recv [lsort -unique $recv]
    }
    return $recv
}

# # ## ### ##### ######## ############# ######################
## Internal helpers: Low level generic route management.

proc ::fx::note::RouteAdd {prefix destinations} {
    set added 0

    foreach dst $destinations {
	puts -nonewline "  $dst ... "

	set key ${prefix}:$dst
	if {[config has $key]} {
	    puts "Already known"
	} else {
	    config set-local $key 1
	    puts "Added"
	    incr added
	}
    }
    return $added
}

proc ::fx::note::RouteDrop {prefix destinations} {
    set removed 0

    foreach pattern $destinations {
	puts -nonewline "  $pattern ... "

	set key ${prefix}:$pattern
	set by  [config unset-glob-local  $key]
	if {!$by} {
	    puts "Ignored, no match"
	} else {
	    puts "Removed $by"
	    incr removed $by
	}
    }
    return $removed
}

proc ::fx::note::HasRoutes {} {
    return [expr { [config has-glob fx-aku-note-send2-*:*] ||
		   [config has-glob fx-aku-note-field:*]      }]
}

proc ::fx::note::RouteMap {} {
    # @repository(-db)

    set map {}
    # map    = dict (event-type -> routes)
    # routes = list (route)
    # routes = list (static destination)
    # static = boolean, true -> dest = email
    #                   true -> dest = field 

    # TODO: Create a "config get-glob" method and use it.

    set settings [config get-list]

    # We have a mix of routes and other settings.

    # Note: The event types in the saved route information is
    # external, therefore conversion is not required for display.
    # Validation and conversion to internal will happen on actual use.

    foreach k [lsort -dict [dict keys $settings]] {
	# dynamic route through ticket field
	if {[string match fx-aku-note-field:* $k]} {
	    regsub {^fx-aku-note-field:} $k {} field

	    dict lappend map ticket [list 0 $field]
	    continue
	}
	# static route for event
	if {[string match fx-aku-note-send2-*:* $k]} {
	    regexp {^fx-aku-note-send2-([^:]*):(.*)$} $k -> event addr

	    dict lappend map $event [list 1 $addr]
	    continue
	}
	# ignore everything else
    }
    return $map
}

# # ## ### ##### ######## ############# ######################
## Internal helpers.
## (De)register the repository in the global database, 'deliver all'

proc ::fx::note::WatchMe {r} {
    config set-global fx-aku-note-watch:$r 1
}

proc ::fx::note::RemoveMe {r} {
    config unset-global fx-aku-note-watch:$r
}

# # ## ### ##### ######## ############# ######################
package provide fx::note 0
return
