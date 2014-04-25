## -*- tcl -*-
# # ## ### ##### ######## #############

# @@ Meta Begin
# Package fx::tty  ?
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     fx
# Meta require     {Tcl 8.5-}
# Meta subject     ?
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require Tclx

# # ## ### ##### ######## #############

namespace eval ::fx {
    namespace export tty
    namespace ensemble create
}
namespace eval ::fx::tty {
    namespace export *
    namespace ensemble create
}

# # ## ### ##### ######## #############

if {$::tcl_platform(platform) eq "windows"} {
    proc ::fx::tty::stdout {} { return 0 }
} else {
    proc ::fx::tty::stdout {} { fstat stdout tty }
}

# # ## ### ##### ######## #############
package provide fx::tty 0
