## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::user 0
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
package require fx::fossil
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export user
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: user (blobs)

namespace eval ::fx::validate::user {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil
    namespace import ::cmdr::validate::common::fail-unknown-thing
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::user::default  {p}   { return {} }
proc ::fx::validate::user::release  {p x} { return }
proc ::fx::validate::user::validate {p x} {
    if {$x in [Values $p]} {
	return $x
    }
    fail-unknown-thing $p USER "A user" $x
}

proc ::fx::validate::user::complete {p} {
    complete-user [Values $p] 1 $x
}

proc ::fx::validate::user::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fossil users]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::user 0
return
