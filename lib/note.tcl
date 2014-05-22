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
package require debug
package require debug::caller
package require interp

package require fx::fossil
package require fx::mailer
package require fx::mailgen
package require fx::manifest
package require fx::mgr::config
package require fx::seen
package require fx::color
package require fx::table
package require fx::util
package require fx::validate::event-type
package require fx::validate::mail-config

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::note {
    namespace export \
	mail-config-show mail-config-set mail-config-unset \
	mail-config-reset mail-config-export mail-config-import \
	route-export route-import route-add route-drop route-list \
	route-field-add route-field-drop watched deliver \
	event-list field-list mark-pending mark-notified \
	show-pending show-notified \
	test-parse test-mail-gen test-mail-config test-mail-receivers

    namespace ensemble create

    namespace import ::fx::color
    namespace import ::fx::fossil
    namespace import ::fx::mailer
    namespace import ::fx::mailgen
    namespace import ::fx::manifest
    namespace import ::fx::mgr::config
    namespace import ::fx::seen
    namespace import ::fx::util
    namespace import ::fx::validate::event-type
    namespace import ::fx::validate::mail-config

    namespace import ::fx::table::do
    rename do table

    # (global) configuration prefix for watched repositories.
    variable g_repo_watch "fx-aku-note-watch"

    # configuration prefix for static routes
    variable g_route_event "fx-aku-note-send2"

    # configuration prefix for dynamic routes
    variable g_route_field "fx-aku-note-field"
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

    if {![$config @extended]} {
	[table t {Id Type UUID Comment} {
	    seen forall-pending type id uuid comment {
		set type [event-type external $type]
		$t add $id $type \
		    [mailgen limit $u $uuid] \
		    [mailgen limit $c [lindex [split $comment \n] 0]]
	    }
	}] show
    } else {
	[table t {Id Type Mtype UUID Comment} {
	    seen forall-pending type id uuid comment {
		set type [event-type external $type]
		set mtype [dict get \
			       [manifest parse \
				    [fossil get-manifest $uuid]] \
			       type]
		$t add $id $type $mtype \
		    [mailgen limit $u $uuid] \
		    [mailgen limit $c [lindex [split $comment \n] 0]]
	    }
	}] show
    }

    fossil show-repository-location
    return
}

proc ::fx::note::show-notified {config} {
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

    if {![$config @extended]} {
	[table t {Id Type UUID Comment} {
	    seen forall-notified type id uuid comment {
		set type [event-type external $type]
		$t add $id $type \
		    [mailgen limit $u $uuid] \
		    [mailgen limit $c [lindex [split $comment \n] 0]]
	    }
	}] show
    } else {
	[table t {Id Type Mtype UUID Comment} {
	    seen forall-notified type id uuid comment {
		set type [event-type external $type]
		set mtype [dict get \
			       [manifest parse \
				    [fossil get-manifest $uuid]] \
			       type]
		$t add $id $type $mtype \
		    [mailgen limit $u $uuid] \
		    [mailgen limit $c [lindex [split $comment \n] 0]]
	    }
	}] show
    }

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
		    $t add $uuid $e
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
	[list [$config @destination]] \
	[mailgen test \
	     [mailer get sender] \
	     [mailer get header] \
	     [mailer get footer]] on
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

		lassign [MailCore $uuid $type $comment $map] recv m
		$t add $uuid [llength $recv] [join [lsort -dict $recv] {, }]
	    }
	}] show

    } else {
	# Single uuid, show in details

	lassign [MailCore $uuid {} {} $map] recv m

	fossil show-repository-location
	[table t [list "Destinations $uuid"] {
	    foreach dest [lsort -dict $recv] {
		$t add $dest
	    }
	}] show
    }
    return
}

proc ::fx::note::MailCore {uuid type comment map {context {}}} {
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
	       ecomment $comment \
	       etype    $extype  \
	       self     $uuid \
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
    fossil show-repository-location

    set useglobal [$config @global]
    set uselocal  [$config @local]

    # Cmdr made sure that we cannot have both set.
    # Leaving 3 possibilities:
    #
    # 1. Global: Export the global defined settings.
    # 2. Local:  Export the locally defined settings.
    # 3. Mix (Default): Collect as the repository sees it, mixing local, and global (but not defaults).

    set data {}
    # Retrieve and assemble semi-table.
    if {$useglobal} {
	foreach k [lsort -dict [mail-config all]] {
	    if {![mailer has-global $k]} continue
	    lappend data [list $k [mailer get-global $k]]
	}
    } elseif {$uselocal} {
	foreach k [lsort -dict [mail-config all]] {
	    if {![mailer has-local $k]} continue
	    lappend data [list $k [mailer get-local $k]]
	}
    } else {
	foreach k [mail-config all] {
	    # NOTE: k :: mail-config external (string) rep.
	    # See mailer::get
	    # Difference! Extended => origin information.
	    # Filter out (i.e. ignore) defaults
	    set v [config get-extended-with-default \
		       [mail-config internal   $k] \
		       {}]
	    lassign $v isglobal mtime v
	    if {$isglobal < 0} continue
	    lappend data [list $k $v]
	}
    }

    if {!$useglobal} {
	fossil show-repository-location
    }

    # Write the assembled configuration
    set chan [open [$config @output] w]
    foreach item $data {
	puts $chan [linsert $item 0 mail-config]
    }
    close $chan
    return
}

proc ::fx::note::mail-config-import {config} {
    debug.fx/note {}
    fossil show-repository-location

    set global [$config @global]

    set input [$config @input]
    set data [read $input]
    $config @input forget

    # Run the import script in a safe interpreter with just the import
    # commands. This generates internal data structures from which we
    # then create the enumerations by looping back through the cmdr
    # hierarchy. This automatically gives us all the validation needed.
    # We catch issues and report them, but do not abort importing.

    variable ikeys   {}
    variable ivalues {}

    set i [interp::createEmpty]
    $i alias mail-config ::fx::note::IMConfig [$config @mailconfig self]
    $i eval $data
    interp delete $i

    # Generate the labels.
    set lkeys {}
    foreach k $ikeys {
	lappend lkeys [mail-config external $k]
    }
    set lvalues {}
    foreach v $ivalues {
	lappend lvalues '$v'
    }
    set lvalues [util padr $lvalues]

    # Do the import.
    foreach key $ikeys lkey [util padr $lkeys] value $ivalues lvalue $lvalues {
	# Note: The key is the internal rep.
	try {
	    # Inlined ConfigSet, to allow for vertical alignment of
	    # the messages with each other.
	    puts -nonewline "Importing [color note $lkey] = $lvalue "
	    flush stdout

	    if {$global} {
		puts -nonewline "(global) ... "
		flush stdout

		config set-global $key $value
		set current [config get-global $key]
	    } else {
		puts -nonewline "... "
		flush stdout

		config set-local $key $value
		set current [config get-local $key]
	    }

	    if {$current ne $value} {
		error "Verification mismatch, got '$current'"
	    }

	    puts [color good OK]
	} on error {e o} {
	    puts [color error $e]
	}
    }
    return
}

proc ::fx::note::IMConfig {p key value} {
    debug.fx/note {}
    variable ikeys
    variable ivalues

    # Validate through the hidden parameter
    $p set $key
    lappend ikeys   [$p value]
    lappend ivalues $value
    return
}

proc ::fx::note::mail-config-show {config} {
    debug.fx/note {}
    set data {}

    if {[$config @global]} {
	# Show global data without fallbacks.
	[table t {Key Value} {
	    foreach k [lsort -dict [mail-config all]] {
		if {![mailer has-global $k]} continue
		$t add $k [mailer get-global $k]
	    }
	}] show
	return
    }

    if {[$config @local]} {
	# Show repository-specific data without fallbacks.
	[table t {Key Value Last-Changed} {
	    foreach k [lsort -dict [mail-config all]] {
		if {![mailer has-local $k]} continue
		set v [config get-extended-with-default \
			   [mail-config internal $k] {}]
		lassign $v isglobal mtime v
		set mtime [expr {($mtime ne {})
				 ? [clock format $mtime]
				 : "" }]
		$t add $k $v $mtime
	    }

	    fossil show-repository-location
	}] show
	return
    }

    # Show repository-specific data, with origin information.
    # Retrieve and assemble semi-table.
    foreach k [mail-config all] {
	# See mailer::get
	# Difference! Extended data => origin, mtime
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

    # See also "fx::config::set"
    # equivalent with shorter user-visible keys

    set global [$config @global]
    set name   [$config @key]
    set value  [$config @value]

    # TODO: type validation per chosen setting.

    if {$global} {
	fossil show-global-location
    } {
	fossil show-repository-location
    }

    ConfigSet $global $name $value
    return
}

proc ::fx::note::mail-config-unset {config} {
    debug.fx/note {}

    set global [$config @global]

    if {$global} {
	fossil show-global-location
    } {
	fossil show-repository-location
    }
    foreach name [$config @key] {
	puts -nonewline "Unsetting [color note [mail-config external $name]]"
	if {$global} {
	    config unset-global $name
	} else {
	    config unset-local $name
	}
	puts ""
    }
    return
}

proc ::fx::note::mail-config-reset {config} {
    debug.fx/note {}

    if {[$config @global]} {
	fossil show-global-location
	foreach name [mail-config all] {
	    puts -nonewline "Unsetting [color note [mail-config external $name]]"
	    config unset-global $name
	    puts ""
	}
	return
    }

    fossil show-repository-location
    foreach name [mail-config all] {
	puts -nonewline "Unsetting [color note [mail-config external $name]]"
	config unset-local $name
	puts ""
    }
    return
}

proc ::fx::note::ConfigSet {global name value {prefix Setting} {gsuffix OK}} {
    debug.fx/note {}

    puts -nonewline "$prefix [color note [mail-config external $name]] = '$value' "
    flush stdout

    if {$global} {
	puts -nonewline "(global) ... "
	flush stdout

	config set-global $name $value
	set current [config get-global $name]
    } else {
	puts -nonewline "... "
	flush stdout

	config set-local $name $value
	set current [config get-local $name]
    }

    if {$current ne $value} {
	error "Verification mismatch, got '$current'"
    }

    if {$gsuffix ne {}} {
	puts [color good $gsuffix]
    } else {
	puts ""
    }
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
    fossil show-repository-location

    set chan [open [$config @output] w]
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
    close $chan
    return
}

proc ::fx::note::route-import {config} {
    debug.fx/note {}
    fossil show-repository-location

    set extend [$config @extend]

    set input [$config @input]
    set data [read $input]
    $config @input forget

    # Run the import script in a safe interpreter with just the import
    # commands. This generates internal data structures from which we
    # then create the enumerations by looping back through the cmdr
    # hierarchy. This automatically gives us all the validation needed.
    # We catch issues and report them, but do not abort importing.

    variable g_route_event
    variable g_route_field
    variable routes {}
    variable fields {}

    set i [interp::createEmpty]
    $i alias route ::fx::note::IRoute [$config @event self] [$config @mailaddr self]
    $i alias field ::fx::note::IField [$config @field self]

    $i eval $data
    interp delete $i

    set changes 0
    if {!$extend} {
	puts [color warning "Import replaces the existing routing ..."]
	incr changes
	# Inlined drop of all routes and fields.
	RouteDrop "Event *      " ${g_route_event}-* *
	RouteDrop "Ticket Fields" $g_route_field     *	     
    } else {
	puts [color note "Import extends the existing routing ..."]
    }

    if {[dict size $routes]} {
	puts "New routes ..."
	foreach {event destinations} [util dictsort $routes] {
	    # Inlined route-add.
	    set e [event-type external $event]
	    set l [color name [event-type label $event]]
	    if {![RouteAdd \
		      "Event $l" ${g_route_event}-${e} $destinations]
	    } continue
	    WatchMe [$config @repository]
	}
    } else {
	puts [color note {No routes}]
    }

    if {[llength $fields]} {
	puts "New fields ..."
	# Inlined route-field-add.
	if {[RouteAdd \
		 "Ticket Fields" $g_route_field $fields]
	} {
	    incr changes
	    WatchMe [$config @repository]
	}

	if {$changes} {
	    seen set-watched-fields [Fields]
	}
    } else {
	puts [color note {No fields}]
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

    dict lappend routes [$pe value] [$pd value]
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

    variable g_route_event
    set watch 0
    foreach e $el {
	set l [color name [event-type label $e]]
	if {![RouteAdd \
		  "Event $l" ${g_route_event}-${e} [$config @to]]
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

    variable g_route_event
    set remove 0
    foreach e $el {
	set l [color name [event-type label $e]]
	if {![RouteDrop \
		  "Event $l" ${g_route_event}-$e [$config @to]]
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
    variable g_route_field
    if {![RouteAdd \
	      "Ticket Fields" ${g_route_field} [$config @field]]
    } return

    seen set-watched-fields [Fields]
    WatchMe [$config @repository]
    return
}

proc ::fx::note::route-field-drop {config} {
    debug.fx/note {}
    # @field (list), @repository(-db)

    fossil show-repository-location
    variable g_route_field
    if {![RouteDrop \
	      "Ticket Fields" ${g_route_field} [$config @field]]
    } return

    seen set-watched-fields [Fields]

    if {[HasRoutes]} return
    RemoveMe [$config @repository]
    return
}

# # ## ### ##### ######## ############# ######################
## API. Run over (all) repository/ies and generate notifications
## for all events not yet handled (i.e. not marked as seen).

proc ::fx::note::deliver {config} {
    debug.fx/note {}
    # @repository, @all

    if {[$config @all]} {
	# Delivery for all watched repositories.
	foreach path [Watched] {
	    [$config context root] do deliver -R $name
	}
	return
    }

    # Delivery for single repository.
    fossil show-repository-location

    if {[mailer get suspended]} {
	puts [color note {Delivery of notifications is suspended here.}]
	return
    }

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

    set verbose [$config @verbose]
    set changes 0

    set changes [seen num-pending]
    set limit [mailer get limit]
    if {$changes > $limit} {
	puts [color error "Too many changes found: $changes"]
	puts [color error "We may not send more mails than $limit."]

	set admin [lindex [dict get $mc -header] end]
	::fx mailer send $mc [list $admin] \
	    [::fx mailgen for-limit $pinfo $changes $limit] on

	puts [color error "Mail storm blocked, notified admin $admin"]
	exit 1
    }

    seen forall-pending type id uuid comment {
	# TODO: no mail and such when suspended.
	# TODO: Dry run for testing.
	# TODO: switchable progress animation

	incr changes
        seen mark-notified $uuid
	lassign [MailCore $uuid $type $comment $map $pinfo] recv m

	if {[llength $recv]} {
	    puts [color note "Change $uuid :: $comment"]
	    mailer send $mc $recv [mailgen artifact $m] $verbose
	}
    }

    if {$changes} return
    puts [color warning "No changes"]
    return
}

# # ## ### ##### ######## ############# ######################
## Receiver collection

proc ::fx::note::ProjectInfo {} {
    debug.fx/note {}
    return [dict create \
		header   [mailer get header]	  \
		footer   [mailer get footer]	  \
		location [mailer get location]	  \
		project  [mailer get project-name] \
		sender   [mailer get sender]      \
	       ]
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

	if {$dest eq "login"} {
	    #puts special
	    # Special case: Entire history!
	    # This is the set of people who have touched the ticket
	    # over the whole lifetime (before mtime, i.e current
	    # change).  (i.e commented on it, changed something,
	    # etc. We assume here that these are all interested in
	    # further changes.

	    foreach m [seen get-field-all $tuuid $dest $mtime] {
		#puts ++$m
		+RX $m
	    }
	}
    }

    # One thing which is always dynamic, for any change. Destination
    # based on the user who made the change. This destination is
    # excluded, given that the changer knows what s/he did.

    debug.fx/note {user=[dict exists $manifest user]}
    if {[dict exists $manifest user]} {
	-RX [dict get $manifest user]
    }

    # Dynamic fields may have introduced duplicate destinations.
    # Also, same destinations may have different friendly names in
    # them, and still must be collated into one route.

    set recv [mailer dedup-addresses $recv]

    # TODO: Check list against a table of bad addresses and ignore these.
    # Must be noted in a log.

    debug.fx/note {/done}
    return $recv
}

proc ::fx::note::+R {addr} {
    debug.fx/note {}
    upvar 1 recv recv
    if {$addr eq {}} return
    if {![mailer good-address $addr]} {
	debug.fx/note {rejected}
	return
    }
    debug.fx/note {added}
    lappend recv $addr
    return
}

proc ::fx::note::-R {addr} {
    debug.fx/note {}
    upvar 1 recv recv
    if {$addr eq {}} return
    if {![mailer good-address $addr]} {
	debug.fx/note {rejected}
	return
    }
    debug.fx/note {remove}
    set recv [mailer drop-address $addr $recv]
    return
}

proc ::fx::note::+RX {addr} {
    debug.fx/note {}
    upvar 1 recv recv
    # Each level of transformation may introduce an address.
    debug.fx/note {concealed = $addr}
    +R $addr

    set addr [fossil reveal $addr]
    debug.fx/note {revealed  = $addr}
    +R $addr

    set addr [fossil user-info $addr]
    debug.fx/note {contact   = $addr}
    +R $addr
    return
}

proc ::fx::note::-RX {addr} {
    debug.fx/note {}
    upvar 1 recv recv
    # Each level of transformation may introduce an address.
    debug.fx/note {concealed = $addr}
    -R $addr

    set addr [fossil reveal $addr]
    debug.fx/note {revealed  = $addr}
    -R $addr

    set addr [fossil user-info $addr]
    debug.fx/note {contact   = $addr}
    -R $addr
    return
}

# # ## ### ##### ######## ############# ######################
## Internal helpers: Low level generic route management.

proc ::fx::note::RouteAdd {label prefix destinations} {
    debug.fx/note {}

    set added 0
    foreach dst $destinations dl [util padr $destinations] {
	puts -nonewline "  ${label}: Adding [color name $dl] ... "

	set key ${prefix}:$dst
	if {[config has $key]} {
	    puts [color warning "Ignored, already known"]
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

    set removed 0
    foreach pattern $destinations dl [util padr $destinations] {
	puts -nonewline "  ${label}: Dropping [color name $dl] ... "

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
    variable g_route_event
    variable g_route_field
    return [expr { [config has-glob ${g_route_event}-*:*] ||
		   [config has-glob ${g_route_field}:*]      }]
}

proc ::fx::note::Fields {} {
    debug.fx/note {}
    variable g_route_field
    return [util strip-prefix ${g_route_field}: \
		[config names-glob ${g_route_field}:*]]
}

proc ::fx::note::Statics {} {
    debug.fx/note {}
    variable g_route_event
    set map {}
    foreach item [util strip-prefix ${g_route_event}- \
		      [config names-glob ${g_route_event}-*]] {
	regexp {^([^:]*):(.*)$} $item -> event addr
	lappend map $event $addr
    }
    return $map
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

    # Note: The event types in the saved route information is
    # external, therefore conversion is not required for display.
    # It may be needed for internal use.

    # Collect the dynamic routes, i.e. ticket fields, for ticket changes.
    foreach field [Fields] {
	# Note: We are checking the validity of the field names found
	# in the route map. The map is stored in a place where it can
	# be manipulated, accidental or intentional.

	$config @field set $field
	dict lappend map ticket [list 0 [$config @field]]
    }

    # Collect the static routes for all events.
    foreach {event addr} [Statics] {
	# Note: We are checking the validity of the events and
	# addresses found in the route map. The map is stored in a
	# place where it can be manipulated, accidental or
	# intentional.

	$config @event    set $event
	$config @mailaddr set $addr
	dict lappend map $event [list 1 $addr]
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

proc ::fx::note::watched {config} {
    debug.fx/note {}
    # TODO: MAYBE: Show #routes, or route details ?
    [table t {Watching} {
	foreach p [lsort -dict [Watched]] {
	    $t add $p
	}
    }] show
    return
}

proc ::fx::note::Watched {} {
    variable g_repo_watch
    return [util strip-prefix ${g_repo_watch}: \
		[config names-glob-global ${g_repo_watch}:*]]
}

proc ::fx::note::WatchMe {r} {
    debug.fx/note {}
    variable g_repo_watch
    set r [file normalize $r]
    config set-global ${g_repo_watch}:$r 1
    return
}

proc ::fx::note::RemoveMe {r} {
    debug.fx/note {}
    variable g_repo_watch
    set r [file normalize $r]
    config unset-global ${g_repo_watch}:$r
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::note 0
return
