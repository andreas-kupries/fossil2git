## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::validate::mail-config 0
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
package require fx::mgr::config

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate {
    namespace export mail-config
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## Custom validation type, legal validateuration mail-configs

namespace eval ::fx::validate::mail-config {
    namespace export release validate default complete \
	internal external all default-of
    namespace ensemble create

    namespace import ::cmdr::validate::common::fail
    namespace import ::cmdr::validate::common::complete-enum
    namespace import ::fx::mgr::config
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

proc ::fx::validate::mail-config::default-of {x} {
    variable default

    if {$x eq "location"} {
	if {[config has-local last-sync-url]} {
	    # Special casing: The location defaults to the last synced
	    # remote url, if we have any.
	    set r [config get-local last-sync-url]
	    # Strip any user:password information out of the url
	    regsub {//([^@]+)@} $r {//} r
	    return $r
	}
	# TODO: future - when we have mirroring information,
	# i.e. peers, the primary peer will be our location, except if
	# overridden.
    }

    return [dict get $default $x]
}

proc ::fx::validate::mail-config::all {} {
    variable legal
    return  $legal
}

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::validate::mail-config {
    # # ##
    # footer   text. inserted into the generated mails
    # header   text. inserted into the generated mails
    # location url. repository location, for links in the generated mail.
    # sender   string. mail address of the nominal sender, inserted into the generated mails.

    # debug     boolean, low-level smtp-debugging yes/no
    # tls       boolean. (can|must) use TLS to secure smtp yes/no.
    # host      string. name of mail-relay host
    # password  string. password for smtp transaction
    # user      string. user for smtp  transaction.
    # port      integer. port on mail-relay host accepting smtp.

    # limit     number of mails the system is allowed to send in a block.
    # suspended boolean, delivery disabled no/yes.

    variable map {
	debug     fx-aku-note-mail-debug
	footer    fx-aku-note-project-footer
	header    fx-aku-note-project-header
	host 	  fx-aku-note-mail-host
	limit     fx-aku-note-mail-limit
	location  fx-aku-note-project-location
	password  fx-aku-note-mail-password
	port 	  fx-aku-note-mail-port
	sender    fx-aku-note-mail-sender
	suspended fx-aku-note-mail-suspended
	tls       fx-aku-note-mail-tls
	user      fx-aku-note-mail-user
    }

    variable default {
	debug     0
	footer    {}
	header    {Automated mail by @cmd@, on behalf of @sender@}
	host 	  localhost
	limit     10
	location  {*Undefined* Please set.}
	password  {}
	port 	  25
	sender    {*Undefined* Please set.}
	suspended 0
	tls       0
	user      {}
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
