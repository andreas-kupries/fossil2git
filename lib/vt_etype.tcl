## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::event-type 0
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
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export event-type
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration event-types

namespace eval ::fx::validate::event-type {
    namespace export release validate default complete \
	external all
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::event-type::release  {p x} { return }
proc ::fx::validate::event-type::validate {p x} {
    variable legal
    set cx [string tolower $x]
    if {$cx in $legal} {
    variable map
	return [dict get $map $cx]
    }
    fail $p EVENT-TYPE "a repository event-type" $x
}

proc ::fx::validate::event-type::default  {p} { return {} }
proc ::fx::validate::event-type::complete {p} {
    variable legal
    complete-enum $legal 1 $x
}

proc ::fx::validate::event-type::external {x} {
    variable imap
    return [dict get $imap $x]
}

proc ::fx::validate::event-type::all {} {
    variable legal
    return  $legal
}

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate::event-type {
    variable map {
	commit	ci
	control	g
	wiki	w
	event	e
	ticket	t
    }
}

# Generate back-conversion internal to external.
::apply {{} {
    variable legal
    variable imap
    variable map
    foreach {k v} $map {
	dict set imap $v $k
	lappend legal $k
    }
} ::fx::validate::event-type}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::event-type 0
return
