# -*- tcl -*-
# # ## ### ##### ######## ############# #####################

# @@ Meta Begin
# Application fx   ?
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
    variable colorize 0

    namespace export {[a-z]*}
    namespace ensemble create

    # TODO: symbolic mapping (error, warning, note, ...)

    ::term::ansi::code::ctrl::import =
    namespace eval = {
	namespace export *
	namespace ensemble create
    }
}

# # ## ### ##### ######## ############# #####################

proc ::fx::color::activate {{flag 1}} {
    variable colorize $flag
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
} {
    interp alias {} ::fx::color::$cmd {} ::fx::color::Apply $color
}

# # ## ### ##### ######## ############# #####################

proc ::fx::color::Apply {code text} {
    variable colorize
    if {!$colorize} {
	return $text
    } else {
	return [= $code]$text[= sda_reset]
    }
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide fx::color 0
