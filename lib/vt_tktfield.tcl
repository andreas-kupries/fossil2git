## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::ticket-field 0
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
package require cmdr::validate::common

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export ticket-field
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration ticket-fields

namespace eval ::fx::validate::ticket-field {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::ticket-field::release  {p x} { return }
proc ::fx::validate::ticket-field::validate {p x} {
    set cx [string tolower $x]
    if {$cx in [Legal $p]} { return $cx }
    fail $p TICKET-FIELD "a repository ticket-field" $x
}

proc ::fx::validate::ticket-field::default  {p} { return {} }
proc ::fx::validate::ticket-field::complete {p} {
    complete-enum [Legal $p] 1 $x
}

# # ## ### ##### ######## ############# ######################

proc ::fx::validate::ticket-field::Legal {p} {
    fossil ticket-fields [$p config @repository-db]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::ticket-field 0
return
