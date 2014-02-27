## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::mail-config 0
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
    namespace export mail-config
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration mail-configs

namespace eval ::fx::validate::mail-config {
    namespace export release validate default complete \
	internal external all
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
}

proc ::fx::validate::mail-config::release  {p x} { return }
proc ::fx::validate::mail-config::validate {p x} {
    if {[has $x]} {
	return [internal $x]
    }
    fail $p MAIL-CONFIG "an fx notification setting" $x
}

proc ::fx::validate::mail-config::default  {p} { return {} }
proc ::fx::validate::mail-config::complete {p x} {
    variable legal
    complete-enum $legal 1 $x
}

proc ::fx::validate::mail-config::has {x} {
    variable map
    return [dict exists $map [string tolower $x]]
}

proc ::fx::validate::mail-config::external {x} {
    variable imap
    return [dict get $imap $x]
}

proc ::fx::validate::mail-config::internal {x} {
    variable map
    return [dict get $map [string tolower $x]]
}

proc ::fx::validate::mail-config::default {x} {
    variable default
    return [dict get $default $x]
}

proc ::fx::validate::mail-config::all {} {
    variable legal
    return  $legal
}

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate::mail-config {
    variable map {
	debug    fx-aku-note-mail-debug
	tls      fx-aku-note-mail-tls
	user     fx-aku-note-mail-user
	password fx-aku-note-mail-password
	host 	 fx-aku-note-mail-host
	port 	 fx-aku-note-mail-port
	sender   fx-aku-note-mail-sender
	location fx-aku-note-project-location
    }

    variable default {
	debug    0
	tls      0
	user     {}
	password {}
	host 	 localhost
	port 	 22
	sender   {*Undefined* Please set.}
	location {*Undefined* Please set.}
    }

    # Last map: Type validation per setting.
}

# Generate back-conversion internal to external.
::apply {{} {
    variable legal
    variable imap
    variable map
    foreach {k v} $map {
	dict set imap $v $k
	lappend legal $k
    }
} ::fx::validate::mail-config}

# # ## ### ##### ######## ############# ######################
package provide fx::validate::mail-config 0
return
