## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::uuid 0
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
    namespace export uuid
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: uuid (blobs)

namespace eval ::fx::validate::uuid {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil
    namespace import ::cmdr::validate::common::fail-unknown-thing
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::uuid::default  {p}   { return {} }
proc ::fx::validate::uuid::release  {p x} { return }
proc ::fx::validate::uuid::validate {p x} {
    set cx [string tolower $x]

    set matches [fossil repository onecolumn {
	SELECT count(*)
	FROM blob
	WHERE uuid = :cx
    }]

    if {$matches == 1} {
	return $cx
    }
    fail-unknown-thing $p UUID "A uuid" $x
}

proc ::fx::validate::uuid::complete {p} {
    complete-uuid [Values $p] 1 $x
}

proc ::fx::validate::uuid::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fossil repository eval {
	SELECT uuid FROM blob
    }]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::uuid 0
return
