## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::event-xtype 0
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
package require fx::validate::event-type

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export event-xtype
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration event-types

namespace eval ::fx::validate::event-xtype {
    namespace export release validate default complete \
	external all
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
    namespace import ::fx::validate::event-type
}

proc ::fx::validate::event-xtype::release  {p x} { return }
proc ::fx::validate::event-xtype::validate {p x} {
    variable legal
    set cx [string tolower $x]
    # Special type "all" => expand into everything.
    if {$cx eq "all"} { return $cx }
    event-type validate $p $x
}

proc ::fx::validate::event-xtype::default  {p} { return {} }
proc ::fx::validate::event-xtype::complete {p} {
    complete-enum [all] 1 $x
}

proc ::fx::validate::event-xtype::external {x} {
    return [event-type external $x]
}

proc ::fx::validate::event-xtype::all {} {
    return [linsert 0 [event-type all] all]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::event-xtype 0
return
