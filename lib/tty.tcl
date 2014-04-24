## -*- tcl -*-
# # ## ### ##### ######## #############

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
