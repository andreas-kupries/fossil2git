## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::uuid-lexical 0
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
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export uuid-lexical
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: uuid-lexical (blobs)

namespace eval ::fx::validate::uuid-lexical {
    namespace export release validate default complete ok
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
}

proc ::fx::validate::uuid-lexical::default  {p}   { return {} }
proc ::fx::validate::uuid-lexical::release  {p x} { return }
proc ::fx::validate::uuid-lexical::validate {p x} {
    set cx [string tolower $x]
    if {([string length $cx] != 40) ||
	[regexp {[^0-9a-f]} $cx]} {
	fail $p UUID-LEXICAL "A uuid" $x
    }
    return $cx
}

proc ::fx::validate::uuid-lexical::ok {x} {
    set cx [string tolower $x]
    if {([string length $cx] != 40) ||
	[regexp {[^0-9a-f]} $cx]} {
	return 0
    }
    return 1
}

proc ::fx::validate::uuid-lexical::complete {p} { return {} }

# # ## ### ##### ######## ############# ######################
package provide fx::validate::uuid-lexical 0
return
