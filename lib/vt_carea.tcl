## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::config-area 0
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
    namespace export config-area
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration config-areas

namespace eval ::fx::validate::config-area {
    namespace export release validate default complete legal
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::config-area::release  {p x} { return }
proc ::fx::validate::config-area::validate {p x} {
    set cx [string tolower $x]
    if {$cx in [legal]} { return $cx }
    fail $p CONFIG-AREA "a configuration area" $x
}

proc ::fx::validate::config-area::default  {p} { return all }
proc ::fx::validate::config-area::complete {p} {
    complete-enum [legal] 1 $x
}

# # ## ### ##### ######## ############# ######################

proc ::fx::validate::config-area::legal {} {
    return {all content email project shun skin ticket user}
    # Note: content is not a regular configuration area.
    # However by adding it we can simplify the cli interface
    # for fossil peers, subsuming normal content as a special
    # type of configuration we can exchange.
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::config-area 0
return
