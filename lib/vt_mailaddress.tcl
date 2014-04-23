## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::mail-address 0
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
package require fx::mailer

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export mail-address
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration mail-addresss

namespace eval ::fx::validate::mail-address {
    namespace export release validate default complete \
	internal external all
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
    namespace import ::fx::mailer
}

proc ::fx::validate::mail-address::release  {p x} { return }
proc ::fx::validate::mail-address::validate {p x} {
    if {[mailer good-address $x]} {
	return $x
    }
    fail $p MAIL-ADDRESS "email address" $x
}

proc ::fx::validate::mail-address::default  {p}   { return {} }
proc ::fx::validate::mail-address::complete {p x} { return {} }

# # ## ### ##### ######## ############# ######################
package provide fx::validate::mail-address 0
return
