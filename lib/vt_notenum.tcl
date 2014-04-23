## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::not-enum 0
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
    namespace export enum
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation types: enumerations and items.

namespace eval ::fx::validate::not-enum {
    namespace export release validate default complete
    namespace ensemble create

    namespace import ::fx::fossil::fx-enums
    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::fail-known-thing

    variable illegal "\n!@#$%^&*()={}\"';<>?~`\[\[.\].\]"
    variable pattern "\[$illegal\]"
}

proc ::fx::validate::not-enum::release  {p x} { return }
proc ::fx::validate::not-enum::validate {p x} {
    variable pattern
    # Note 1: enum names are case-insensitive.
    # Note 2: enum names cannot be multi-line,
    #         nor contain many special characters.

    set cx [string tolower $x]

    if {[regexp $pattern $cx]} {
	# Lexical failure.
	variable illegal
	fail $p NOT-ENUM "an enumeration name" $x " (Not allowed: [string map [list \n \\n] $illegal])"
    }

    if {$cx in [Values $p]} {
	fail-known-thing $p NOT-ENUM "enumeration" $x
    }

    # Internal representation is the enum table.
    return fx_aku_enum_$cx
}

proc ::fx::validate::not-enum::default  {p} { return {} }
proc ::fx::validate::not-enum::complete {p} { return {} }

proc ::fx::validate::not-enum::Values {p} {
    # Force parameter, validation can happen
    # before the cmdr completion phase.
    $p config @repository-db
    return [fx-enums]
}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::not-enum 0
return
