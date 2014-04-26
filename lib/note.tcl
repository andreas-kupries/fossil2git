## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::note 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
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
package require fx::color
package require fx::table
package require fx::validate::event-type
package require fx::validate::mail-config
package require interp

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::note {
    namespace export \
	mail-config-show mail-config-set mail-config-unset \
	mail-config-export mail-config-import route-export \
	route-import route-add route-drop route-list route-field-add \
	route-field-drop deliver event-list field-list \
	mark-pending mark-notified \
	show-pending test-parse test-mail-gen test-mail-config \
	test-mail-receivers

    namespace ensemble create

    namespace import ::fx::fossil
    namespace import ::fx::mailer
    namespace import ::fx::mailgen
    namespace import ::fx::manifest
    namespace import ::fx::mgr::config
    namespace import ::fx::seen
    namespace import ::fx::color
    namespace import ::fx::table::do
    rename do table

    namespace import ::fx::validate::event-type
    namespace import ::fx::validate::mail-config
}

# # ## ### ##### ######## ############# ######################

debug level  fx/note
debug prefix fx/note {[debug caller] | }

# # ## ### ##### ######## ############# ######################

proc ::fx::note::mark-pending {config} {
    debug.fx/note {}
    fossil show-repository-location

    if {[$config @overall]} {
	seen mark-pending-all
    } else {
	seen mark-pending [$config @uuid]
    }
    return
}

proc ::fx::note::mark-notified {config} {
    debug.fx/note {}
    fossil show-repository-location

    if {[$config @overall]} {
	seen mark-notified-all
    } else {
	seen mark-notified [$config @uuid]
    }
    return
}

proc ::fx::note::show-pending {config} {
    debug.fx/note {}

    global env
    if {[info exists env(FX_COLUMNS)]} {
	set w $env(FX_COLUMNS)
	if {$w < 0} {
	    set u -1
	    set c -1
	} else {
	    set u [expr {$w*4/10}]
	    set c [expr {$w*6/10}]
	}
    } else {
	set w [linenoise columns]
	incr w -6
	incr w -7

	set u [expr {$w*4/10}]
	set c [expr {$w*6/10}]
    }

    fossil show-repository-location
    [table t {Id Type UUID Comment} {
	seen forall-pending type id uuid comment {
	    set type [event-type external $type]
	    $t add $id $type \
		[mailgen limit $u $uuid] \
		[mailgen limit $c [lindex [split $comment \n] 0]]
	}
    }] show
    fossil show-repository-location
    return
}

proc ::fx::note::test-mail-gen {config} {
    debug.fx/note {}
    # Context (event type, comment, etc. is automatically determined,
    # similar to the code in deliver.

    set uuid  [$config @uuid]
    set all   [$config @overall]
    set pinfo [ProjectInfo]

    if {$all} {
	# Scan entire pending set of events and check that the mail
	# generator is ok with them.

	# TODO: switchable progress animation

	fossil show-repository-location
	[table t {UUID Status} {
	    set max [seen num-pending]
	    set n 0
	    set fmt %[string length $max]d

	    seen forall-pending type id uuid comment {
		incr n
		puts -nonewline stderr "\r\033\[K\r[format $fmt $n]/$max: $uuid"
		flush stderr

		try {
		    set extype [event-type external $type]
		    mailgen artifact \
			[manifest parse \
			     [fossil get-manifest $uuid] \
			     ecomment $comment \
			     etype    $extype  \
			     self     $uuid    \
			     {*}$pinfo]
		} on ok {e o} {
		    # No lines for ok artifacts. Not of interest.
		    #$t add $uuid OK
		} on error {e o} {
		    $t add $uuid $e ;#"ERROR: $e"
		}
	    }
	}] show
	return
    }

    # Single uuid
    set context [seen get-event $uuid]
    dict with context {} ;# type, id, uuid, comment
    set extype [event-type external $type]

    fossil show-repository-location ": $uuid"
    puts [mailgen artifact \
	      [manifest parse \
		   [fossil get-manifest $uuid] \
		   ecomment $comment \
		   etype    $extype  \
		   self     $uuid    \
		   {*}$pinfo]]
    return
}

proc ::fx::note::test-mail-config {config} {
    debug.fx/note {}
    fossil show-repository-location
    mailer send \
	[mailer get-config] \
	[$config @destination] \
	[mailgen test]
    return
}

proc ::fx::note::test-mail-receivers {config} {
    debug.fx/note {}

    set uuid [$config @uuid]
    set all  [$config @overall]
    set map  [RouteMap $config]

    #array set xx $map ; parray xx ; unset xx

    if {$all} {
	# Test all pending events.

	fossil show-repository-location
	[table t {UUID # Destinations} {
	    set max [seen num-pending]
	    set n 0
	    set fmt %[string length $max]d

	    seen forall-pending type id uuid comment {
		incr n
		puts -nonewline stderr "\r\033\[K\r[format $fmt $n]/$max: $uuid"
		flush stderr

		lassign [MailCore $uuid $type $map] recv m
		$t add $uuid [llength $recv] [join [lsort -dict $recv] {, }]
	    }
	}] show

    } else {
	# Single uuid, show in details

	lassign [MailCore $uuid {} $map] recv m

	fossil show-repository-location
	[table t [list "Destinations $uuid"] {
	    foreach dest [lsort -dict $recv] {
		$t add $dest
	    }
	}] show
    }
    return
}

proc ::fx::note::MailCore {uuid type map {context {}}} {
    debug.fx/note {}
    # Timeline event types, and associated artifact types.
    #
    # extype  type
    # ------  ----
    # checkin ci -- manifest (checkin)
    # control g  -- control        (comment change, tag change on a checkin)
    # event   e  -- event,         attachment
    # ticket  t  -- ticket change, attachment
    # wiki    w  -- wiki page,     attachment
    # ------  ----
    #
    # Note how the attachment are not their own type of timeline
    # event, but are categorized underneath the associated changed
    # artifact, i.e. ticket or wiki.
    #
    # As events can have attachments as well I suspect that these
    # are handled under 'e' too, assuming consistency.

    # Mail dispatch (and receivers) are done by timeline event type.
    # Mail generation is done by artifact type, with influences by the
    # actually changed artifact in case of attachments (different
    # references to the changed artifact). This is provided by the
    # 'econtext', holding the 'type' of timeline event <=> type of
    # changed artifact.

    # Back fill for single uuid
    if {$type eq {}} {
	# Get the timeline's information about the event, deduce its
	# type, and use that to choose the set of routes to follow.

	set econtext [seen get-event $uuid]
	#array set cc $econtext ; parray cc ; unset cc

	if {$uuid ne [dict get $econtext uuid]} {
	    error "uuid $uuid context does not match"
	}
	dict with econtext {} ;# type, id, uuid, comment
    }

    set extype [event-type external $type]
    if {![dict exists $map $extype]} { return {{} {}} }

    set routes [dict get $map $extype]
    if {![llength $routes]} { return {{} {}} }

    #puts type\t$extype
    #puts routes\t[join $routes \n\t]

    # Next, get the event's manifest and use it to deduce and add the
    # dynamic routes
    set m [manifest parse \
	       [fossil get-manifest $uuid] \
	       etype $extype  \
	       self  $uuid \
	       {*}$context]

    #array set mm $m ; parray mm

    list [Receivers $routes $m] $m
}

proc ::fx::note::test-parse {config} {
    debug.fx/note {}
    # Context (event type, comment, etc. is all automatically
    # determined, similar to the code in deliver.

    set uuid  [$config @uuid]
    set all   [$config @overall]
    set pinfo [ProjectInfo]

    if {$all} {
	# Scan entire pending set of events and check that the
	# manifest parser is ok with them.

	# TODO: switchable progress animation

	[table t {UUID Status} {
	    set max [seen num-pending]
	    set n 0
	    set fmt %[string length $max]d

	    seen forall-pending type id uuid comment {
		incr n
		puts -nonewline stderr "\r\033\[K\r[format $fmt $n]/$max: $uuid"
		flush stderr

		try {
		    set extype [event-type external $type]
		    manifest parse \
			[fossil get-manifest $uuid] \
			ecomment $comment \
			etype    $extype  \
			self     $uuid    \
			{*}$pinfo]
		} on ok {e o} {
		    # No lines for ok artifacts. Not of interest.
		    #$t add $uuid OK
		} on error {e o} {
		    $t add $uuid $e ;#"ERROR: $e"
		}
	    }
	}] show
	return
    }

    # Single uuid
    set context [seen get-event $uuid]
    dict with context {} ;# type, id, uuid, comment
    set extype [event-type external $type]

    array set m \
	[manifest parse \
	     [fossil get-manifest $uuid] \
	     ecomment $comment \
	     etype    $extype  \
	     self     $uuid    \
	     {*}[ProjectInfo]]

    # Unpack the sub-dictionaries for nicer printing.
    if {[info exists m(field)]} {
	foreach {k v} $m(field) {
	    set m(field,$k) $v
	}
	unset m(field)
    }
    if {[info exists m(tags)]} {
	foreach {k v} $m(tags) {
	    set m(tags,$k) $v
	}
	unset m(tags)
    }

    fossil show-repository-location ": $uuid"
    [table t {Key Value} {
	foreach k [lsort -dict [array names m]] {
	    $t add $k $m($k)
	}
    }] show
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::mail-config-export {config} {
    debug.fx/note {}
    #fossil show-repository-location

    set chan      [$config @output]
    set useglobal [$config @global]

    # Retrieve and assemble semi-table.
    foreach k [mail-config all] {
	# NOTE: k :: mail-config external (string) rep.
	# See mailer::Get
	set v [config get-extended-with-default \
		   [mail-config internal   $k] \
		   [mail-config default-of $k]]

	lassign $v isglobal mtime v

	# Ignore defaults
	if {$isglobal < 0} continue

	# Ignore values specified by the unwanted section
	if {(!$useglobal && $isglobal) ||
	    ($useglobal && !$isglobal)} continue
	puts $chan [list mail-config $k $v]
    }
    return
}

proc ::fx::note::mail-config-import {config} {
    debug.fx/note {}
    fossil show-repository-location

    set global [$config @global]
    set input  [$config @import]

    set data [read $input]
    $config @import forget

    # Run the import script in a safe interpreter with just the import
    # commands. This generates internal data structures from which we
    # then create the enumerations by looping back through the cmdr
    # hierarchy. This automatically gives us all the validation needed.
    # We catch issues and report them, but do not abort importing.

    variable imported {}

    set i [interp::createEmpty]
    $i alias mail-config ::fx::note::IMConfig [$config @mailconfig self]
    $i eval $data
    interp delete $i

    foreach {key value} $imported {
	# Note: The key is the internal rep.
	try {
	    ConfigSet $global $key $value Importing { OK}
	} on error {e o} {
	    puts $e
	}
    }
    return
}

proc ::fx::note::IMConfig {p key value} {
    debug.fx/note {}

    variable imported
    # Validate through the hidden parameter
    $p set $key
    lappend imported [$p value] $value
    return
}

proc ::fx::note::mail-config-show {config} {
    debug.fx/note {}

    # Retrieve and assemble semi-table.
    foreach k [mail-config all] {
	# See mailer::Get
	set v [config get-extended-with-default \
		   [mail-config internal   $k] \
		   [mail-config default-of $k]]

	lassign $v isglobal mtime v

	if {$isglobal < 0} {
	    set origin D
	} elseif {$isglobal} {
	    set origin G
	} else {
	    set origin R
	}

	set mtime [expr {($mtime ne {})
			 ? [clock format $mtime]
			 : "" }]
	lappend k $v $mtime
	lappend data [linsert $k 0 $origin]
    }

    # Format and show the semi-table.

    fossil show-repository-location
    [table t {{} Key Value Last-Changed} {
	foreach item [lsort -dict -index 1 $data] {
	    $t add {*}$item
	}
    }] show
    return
}

proc ::fx::note::mail-config-set {config} {
    debug.fx/note {}
    fossil show-repository-location

    # See also "fx::config::set"
    # equivalent with shorter user-visible keys

    set global [$config @global]
    set name   [$config @key]
    set value  [$config @value]

    # TODO: type validation per chosen setting.

    ConfigSet $global $name $value
    return
}

proc ::fx::note::mail-config-unset {config} {
    debug.fx/note {}
    fossil show-repository-location

    set global [$config @global]
    foreach name [$config @key] {
	puts -nonewline "Unsetting [mail-config external $name]"
	if {$global} {
	    config unset-global $name
	} else {
	    config unset-local $name
	}
	puts ""
    }
    return
}


proc ::fx::note::ConfigSet {global name value {prefix Setting} {gsuffix {}}} {
    debug.fx/note {}

    puts -nonewline "$prefix [mail-config external $name]: "
    flush stdout

    if {$global} {
	config set-global $name $value
	set current [config get-global $name]
	set suffix  " (global)"
    } else {
	config set-local $name $value
	set current [config get-local $name]
	set suffix  {}
    }

    puts '$current'$suffix$gsuffix
    flush stdout
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::note::route-list {config} {
    debug.fx/note {}

    # Retrieve data, and restructure for table.
    set map [RouteMap $config]
    dict for {event routes} $map {
	set new {}
	foreach route $routes {
	    lassign $route static destination
	    if {!$static} {
		set destination <${destination}>
	    }
	    lappend new $destination
	}
	dict set map $event [lsort -dict $new]
    }

    # Now print nicely.
    fossil show-repository-location
    [table t {Event Route} {
	foreach event [lsort -dict [dict keys $map]] {
	    $t add $event [join [dict get $map $event] \n]
	}
    }] show
    return
}

proc ::fx::note::route-export {config} {
    debug.fx/note {}

    set chan [$config @output]
    dict for {event routes} [RouteMap $config] {
	foreach route $routes {
	    lassign $route static destination
	    if {$static} {
		puts $chan [list route $event $destination]
	    } else {
		puts $chan [list field $destination]
	    }
	}
    }
    return
}

proc ::fx::note::route-import {config} {
    debug.fx/note {}
    fossil show-repository-location

    set extend [$config @extend]
    set input  [$config @import]

    set data [read $input]
    $config @import forget

    # Run the import script in a safe interpreter with just the import
    # commands. This generates internal data structures from which we
    # then create the enumerations by looping back through the cmdr
    # hierarchy. This automatically gives us all the validation needed.
    # We catch issues and report them, but do not abort importing.

    variable routes {}
    variable fields {}

    set i [interp::createEmpty]
    $i alias route ::fx::note::IRoute [$config @event self] [$config @mailaddr self]
    $i alias field ::fx::note::IField [$config @field self]

    $i eval $data
    interp delete $i

    set changes 0
    if {!$extend} {
	puts "Import replaces the existing routing ..."
	incr changes
	# Inlined drop of all routes and fields.
	RouteDrop "Event *"       fx-aku-note-send2-* *
	RouteDrop "Ticket Fields" fx-aku-note-field *	     
    } else {
	puts "Import extends the existing routing ..."
    }

    puts "New routes ..."
    foreach {event destination} $routes {
	# Inlined route-add.
	set e [event-type external $event]
	set l [event-type label    $event]
	if {![RouteAdd \
		  "Event [color name $l]" \
		  fx-aku-note-send2-${e} \
		  $destination]
	} continue
	WatchMe [$config @repository]
    }

    puts "New fields ..."
    foreach field $fields {
	# Inlined route-field-add.
	if {![RouteAdd \
		  "Ticket Fields" \
		  fx-aku-note-field \
		  $field]
	} continue
	incr changes
	WatchMe [$config @repository]
    }

    if {$changes} {
	seen set-watched-fields [Fields]
    }

    puts [color good OK]
    return
}

proc ::fx::note::IRoute {pe pd event destination} {
    debug.fx/note {}

    variable routes
    # Validate through the hidden parameters.
    $pe set $event
    $pd set $destination

    lappend routes [$pe value] [$pd value]
    return
}

proc ::fx::note::IField {p destination} {
    debug.fx/note {}

    variable fields
    # Validate through the hidden parameters.
    $p set $destination

    lappend fields [$p value]
    return
}

proc ::fx::note::route-add {config} {
    debug.fx/note {}
    fossil show-repository-location
    # @to (list), @event, @repository(-db)

    # seen event is internal rep.
    set e [$config @event]

    if {$e eq "all"} {
	set el [event-type all]
    } else {
	# for storage we go back to external rep.
	set el [list [event-type external $e]]
    }

    set watch 0
    foreach e $el {
	set l [event-type label $e]
	if {![RouteAdd \
		  "Event [color name $l]" \
		  fx-aku-note-send2-${e} \
		  [$config @to]]
	} continue
	incr watch
    }

    if {!$watch} return
    WatchMe [$config @repository]
    return
}

proc ::fx::note::route-drop {config} {
    debug.fx/note {}
    fossil show-repository-location
    # @to (list), @event, @repository(-db)

    # seen event is internal rep.
    set e [$config @event]

    if {$e eq "all"} {
	set el [event-type all]
    } else {
	# for storage we go back to external rep.
	set el [list [event-type external $e]]
    }

    set remove 0
    foreach e $el {
	set l [event-type label $e]
	if {![RouteDrop \
		  "Event [color name $l]" \
		  fx-aku-note-send2-$e \
		  [$config @to]]
	} continue
	incr remove
    }

    if {!$remove || [HasRoutes]} return
    RemoveMe [$config @repository]
    return
}

proc ::fx::note::event-list {config} {
    debug.fx/note {}

    fossil show-repository-location
    [table t Event {
	foreach col [lsort -dict [event-type all]] {
	    $t add $col
	}
    }] show
    return
}

proc ::fx::note::field-list {config} {
    debug.fx/note {}

    fossil show-repository-location
    [table t Field {
	foreach col [lsort -dict [fossil ticket-fields]] {
	    # Ignore system columns.
	    if {[string match tkt_* $col]} continue
	    $t add $col
	}
    }] show
    return
}

proc ::fx::note::route-field-add {config} {
    debug.fx/note {}
    # @field (list)

    fossil show-repository-location
    if {![RouteAdd \
	      "Ticket Fields" \
	      fx-aku-note-field \
	      [$config @field]]
    } return

    seen set-watched-fields [Fields]

    WatchMe [$config @repository]
    return
}

proc ::fx::note::route-field-drop {config} {
    debug.fx/note {}
    # @field (list), @repository(-db)

    fossil show-repository-location
    if {![RouteDrop \
	      "Ticket Fields" \
	      fx-aku-note-field \
	      [$config @field]]
    } return

    seen set-watched-fields [Fields]

    if {[HasRoutes]} return
    RemoveMe [$config @repository]
    return
}

# # ## ### ##### ######## ############# ######################
## API. Run over (all) repository/ies and generate notifications
## for all events not yet handled (i.e. not marked as seen).

proc ::fx::note::route-deliver {config} {
    debug.fx/note {}
    # @repository, @global, /... ?? --all how ?

    if {[$config @all]} {
	# TODO: Encapsulate conversions (repo list) ...
	config get-list-global {
	    # name, value, mtime
	    if {![string match fx-aku-note-watch:* $name]} continue
	    # Run single-repository deliver on the named repository.
	    # Recursive call through the cli
	    regsub {^fx-aku-note-watch:} $name {} name
	    [$config context root] do deliver -R $name
	}
	return
    }

    # Delivery for single repository.
    fossil show-repository-location

    # Determine the routes. This gives us (implicitly)
    #   a list of the events we can ignore, too.
    # Determine not-yet-seen events.
    # Per event:
    #   Determine receivers
    #   Generate a mail
    #     Mail content is dependent on event type
    #   Send mail
    #   Remember as seen

    set map [RouteMap $config]
    set mc  [mailer get-config]

    # Other general configuration identical across all notifications.
    set pinfo [ProjectInfo]

    seen forall-pending type id uuid comment {
	# TODO: no mail and such when suspended.
	# TODO: Dry run for testing.
	# TODO: switchable progress animation

        seen touch $id
	lassign [MailCore $uuid $type $map $pinfo] recv m

	if {[llength $recv]} {
	    mailer send $mc $recv [mailgen artifact $m]
	}
    }
    return
}

# # ## ### ##### ######## ############# ######################
## Receiver collection

proc ::fx::note::ProjectInfo {} {
    debug.fx/note {}

    set name [config get-with-default \
		  project-name \
		  [file rootname [file tail [fossil repository-location]]]]

    set location [config get-with-default \
		      fx-aku-note-project-location \
		      [mail-config default-of location]]

    return [dict create project $name location $location]
}

proc ::fx::note::Receivers {routes manifest} {
    debug.fx/note {}

    set recv {}
    # NOTE: The caller made sure that all route lists have unique
    # elements. The expansion here may break this - See dynamic routing.

    if {[dict exists $manifest field]} {
	set field [dict get $manifest field]
    } else {
	set field {}
    }
    #array set ff $field ; parray ff

    set mtime [dict get $manifest epoch]

    if {[dict exists $manifest ticket]} {
	set tuuid [dict get $manifest ticket]
    } elseif {[dict exists $manifest target]} {
	set tuuid [dict get $manifest target]
    } else {
	set tuuid {}
    }

    #puts mtime/ticket=$mtime/$tuuid

    foreach route $routes {
	lassign $route static dest

	# Static route, pass into output, nothing else to do.
	if {$static} {
	    #puts static|$dest
	    +R $dest
	    continue
	}

	#puts dynamic|$dest

	# Dynamic route. Two sources for addresses:
	# - Current value as per the ticket change under consideration
	# - Previous value of the field as per the cached timeseries.
	# Both values can be empty.
	# Note that if the ticket change does not contain the field
	# then the timeseries value is the current one.

	if {[dict exists $field $dest]} {
	    +RX [dict get $field $dest]
	}

	+RX [seen get-field $tuuid $dest $mtime]
    }

    # Dynamic fields may have introduced duplicate destinations.
    # Also, same destinations may different friendly names in them,
    # and still must be collated into one route.

    set recv [mailer dedup-addresses $recv]

    # TODO: Check list against a table of bad addresses and ignore these.
    # Must be noted in a log.

    return $recv
}

proc ::fx::note::+R {addr} {
    debug.fx/note {}
    upvar 1 recv recv
    if {$addr eq {}} return
    if {![mailer good-address $addr]} {
	#puts \trejected_=$addr
	# TODO: Log rejected string
	return
    }
    #puts \tadded____=$addr
    lappend recv $addr
    return
}

proc ::fx::note::+RX {addr} {
    debug.fx/note {}
    upvar 1 recv recv
    # Each level of transformation may introduce an address.
    #puts \tconcealed=$addr
    +R $addr

    set addr [fossil reveal $addr]
    #puts \trevealed_=$addr
    +R $addr

    set addr [fossil user-info $addr]
    #puts \tuserinfo_=$addr
    +R $addr
    return
}

# # ## ### ##### ######## ############# ######################
## Internal helpers: Low level generic route management.

proc ::fx::note::RouteAdd {label prefix destinations} {
    debug.fx/note {}

    # TODO: destinations, pad-right for alignment

    set added 0
    foreach dst $destinations {
	puts -nonewline "  ${label}: Adding [color name $dst] ... "

	set key ${prefix}:$dst
	if {[config has $key]} {
	    puts [color note "Already known"]
	} else {
	    config set-local $key 1
	    puts [color good OK]
	    incr added
	}
    }
    return $added
}

proc ::fx::note::RouteDrop {label prefix destinations} {
    debug.fx/note {}

    # TODO: destinations, pad-right for alignment

    set removed 0
    foreach pattern $destinations {
	puts -nonewline "  ${label}: Dropping [color name $pattern] ... "

	set key ${prefix}:$pattern
	set by  [config unset-glob-local $key]
	if {!$by} {
	    puts [color warning "Ignored, no match"]
	} else {
	    puts [color good "Removed $by"]
	    incr removed $by
	}
    }
    return $removed
}

proc ::fx::note::HasRoutes {} {
    debug.fx/note {}
    return [expr { [config has-glob fx-aku-note-send2-*:*] ||
		   [config has-glob fx-aku-note-field:*]      }]
}

proc ::fx::note::Fields {} {
    debug.fx/note {}
    # TODO: config get-glob (get-keys-glob) ...
    set settings [config get-list]
    set fields {}
    dict for {k __} $settings {
	# dynamic route through ticket field
	if {![string match fx-aku-note-field:* $k]} continue

	regsub {^fx-aku-note-field:} $k {} field
	lappend fields $field
    }
    return $fields
}

proc ::fx::note::RouteMap {config} {
    debug.fx/note {}
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
    # It may be needed for internal use.

    # Anyway, the data we pull out of the repository is validated as
    # it can be manipulated with other tools (anything providing
    # access to the sqlite3 database file).

    set map {}
    dict for {k __} $settings {
	# dynamic route through ticket field
	if {[string match fx-aku-note-field:* $k]} {
	    regsub {^fx-aku-note-field:} $k {} field

	    # Note: We are checking the validity of the field names
	    # found in the route map. The map is stored in a place
	    # where it can be manipulated, accidental or intentional.
	    $config @field set $field

	    dict lappend map ticket [list 0 [$config @field]]
	    continue
	}
	# static route for event
	if {[string match fx-aku-note-send2-*:* $k]} {
	    regexp {^fx-aku-note-send2-([^:]*):(.*)$} $k -> event addr

	    # Note: We are checking the validity of the events and
	    # addresses found in the route map. The map is stored in a
	    # place where it can be manipulated, accidental or
	    # intentional.

	    $config @event    set $event
	    $config @mailaddr set $addr

	    dict lappend map $event [list 1 $addr]
	    continue
	}
	# ignore everything else
    }

    # First reduction pass to weed out the static duplicates, if any.
    dict for {event routes} $map {
	dict set map $event [lsort -unique $routes]
    }

    return $map
}

# # ## ### ##### ######## ############# ######################
## Internal helpers.
## (De)register the repository in the global database, 'deliver all'

proc ::fx::note::WatchMe {r} {
    debug.fx/note {}
    config set-global fx-aku-note-watch:$r 1
    return
}

proc ::fx::note::RemoveMe {r} {
    debug.fx/note {}
    config unset-global fx-aku-note-watch:$r
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::note 0
return
