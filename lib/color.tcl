# -*- tcl -*-
# # ## ### ##### ######## ############# #####################

# @@ Meta Begin
# Package fx::color   ?
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
package require term::ansi::code::ctrl ; # ANSI terminal control codes

# # ## ### ##### ######## ############# #####################

namespace eval ::fx {
    namespace export color
    namespace ensemble create
}

namespace eval ::fx::color {
    namespace export {[a-z]*}
    namespace ensemble create

    # TODO: symbolic mapping (error, warning, note, ...)

    ::term::ansi::code::ctrl::import =
    namespace export =
    namespace eval = {
	namespace export *
	namespace ensemble create
    }

    # Activation state
    variable active 0

    # Mapping of symbolic codes to color commands
    # TODO: Make this configurable.
    variable symbol {
	confirm red
	error   red
	warning yellow
	note    blue
	good    green
	name    blue
    }
}

# # ## ### ##### ######## ############# #####################

proc ::fx::color::activate {{flag 1}} {
    variable active $flag
    return
}

foreach {cmd color} {
    red       sda_fgred
    green     sda_fggreen
    yellow    sda_fgyellow
    white     sda_fgwhite
    blue      sda_fgblue
    cyan      sda_fgcyan
    black     sda_fgblack
    bg-red    sda_bgred
    bg-green  sda_bggreen
    bg-yellow sda_bgyellow
    bg-white  sda_bgwhite
    bg-blue   sda_bgblue
    bg-cyan   sda_bgcyan
    bg-black  sda_bgblack
    bold      sda_bold
    error     error
    warning   warning
    note      note
    good      good
    name      name
} {
    interp alias {} ::fx::color::$cmd {} ::fx::color::Apply $color
}

# # ## ### ##### ######## ############# #####################

proc ::fx::color::Apply {code text} {
    variable active
    if {$active} {
	variable symbol
	if {[dict exists $symbol $code]} {
	    return [[dict get $symbol $code] $text]
	}
	return [= $code]$text[= sda_reset]
    } else {
	return $text
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide fx::color 0
