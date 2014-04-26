## -*- tcl -*-
# # ## ### ##### ######## ############# #####################
## FX - Util - General utilities
## Notes
## - Snarfed from Cmdr.


# @@ Meta Begin
# Package fx::util 0
# Meta author   {Andreas Kupries}
# Meta location https://core.tcl.tk/akupries/fx
# Meta platform tcl
# Meta summary     Internal. General utilities.
# Meta description Internal. General utilities.
# Meta subject {command line}
# Meta require {Tcl 8.5-}
# Meta require textutil::adjust
# Meta require debug
# Meta require debug::caller
# @@ Meta End

# # ## ### ##### ######## ############# #####################
## Requisites

package require Tcl 8.5
package require debug
package require debug::caller

# # ## ### ##### ######## ############# #####################
## Definition

namespace eval ::fx {
    namespace export util
    namespace ensemble create
}

namespace eval ::fx::util {
    namespace export padr padl dictsort reflow indent undent \
	max-length
    namespace ensemble create
}

# # ## ### ##### ######## ############# #####################

debug define fx/util
debug level  fx/util
debug prefix fx/util {[debug caller] | }

# # ## ### ##### ######## ############# #####################

proc ::fx::util::padr {words} {
    debug.fx/util {}
    if {[llength $words] <= 1} {
	return $words
    }
    set maxl [max-length $words]
    set res {}
    foreach str $words { lappend res [format "%-*s" $maxl $str] }
    return $res
}

proc ::fx::util::padl {words} {
    debug.fx/util {}
    if {[llength $words] <= 1} {
	return $words
    }
    set maxl [max-length $words]
    set res {}
    foreach str $words { lappend res [format "%*s" $maxl $str] }
    return $res
}

proc ::fx::util::dictsort {dict} {
    debug.fx/util {}

    set r {}
    foreach k [lsort -dict [dict keys $dict]] {
	lappend r $k [dict get $dict $k]
    }
    return $r
}

proc ::fx::util::reflow {text {prefix {    }}} {
    return [indent [undent [string trim $text \n]] $prefix]
}

proc ::fx::util::indent {text prefix} {
    set text [string trimright $text]
    set res {}
    foreach line [split $text \n] {
	if {[string trim $line] eq {}} {
	    lappend res {}
	} else {
	    lappend res $prefix[string trimright $line]
	}
    }
    return [join $res \n]
}

proc ::fx::util::undent {text} {
    if {$text eq {}} { return {} }

    set lines [split $text \n]
    set ne {}
    foreach l $lines {
	if {[string length [string trim $l]] == 0} continue
	lappend ne $l
    }

    set lcp [LCP $ne]
    if {$lcp eq {}} { return $text }

    regexp "^(\[\t \]*)" $lcp -> lcp
    if {$lcp eq {}} { return $text }

    set len [string length $lcp]

    set res {}
    foreach l $lines {
	if {[string trim $l] eq {}} {
	    lappend res {}
	} else {
	    lappend res [string range $l $len end]
	}
    }
    return [join $res \n]
}

# # ## ### ##### ######## ############# #####################

proc ::fx::util::max-length {words} {
    ::set max 0 
    foreach w $words {
	set l [string length $w]
	if {$l <= $max} continue
	set max $l
    }
    return $max
}

proc ::fx::util::LCP {list} {
    if {[llength $list] <= 1} {
	return [lindex $list 0]
    }

    set list [lsort $list]
    set min [lindex $list 0]
    set max [lindex $list end]

    # Min and max are the two strings which are most different. If
    # they have a common prefix, it will also be the common prefix for
    # all of them.

    # Fast bailouts for common cases.

    set n [string length $min]
    if {$n == 0}      { return "" }
    if {$min eq $max} { return $min }

    set prefix ""
    set i 0
    while {[string index $min $i] eq [string index $max $i]} {
	append prefix [string index $min $i]
	if {[incr i] > $n} {break}
    }
    return $prefix
}

# # ## ### ##### ######## ############# #####################
## Ready
package provide fx::util 0
