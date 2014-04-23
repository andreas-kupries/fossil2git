## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::mailer 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta require     sqlite3
# Meta subject     fossil
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require tls
package require smtp
package require mime
package require fx::mgr::config
package require fx::validate::mail-config

namespace eval ::fx {
    namespace export mailer
    namespace ensemble create
}
namespace eval ::fx::mailer {
    namespace export get-config get-sender send good-address dedup-addresses
    namespace ensemble create

    namespace import ::fx::mgr::config
    namespace import ::fx::validate::mail-config
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailer::dedup-addresses {addrlist} {
    # We assume that all addresses are good.
    # We keep the longest input of each with the same 'address'.

    #puts IN|[join $addrlist "|\n  |"]|

    # Note that we do basic lexical uniqueness first, getting rid of
    # the trivial duplicates.

    set map {}
    foreach a [lsort -unique $addrlist] {
	set route [dict get [lindex [mime::parseaddress $a] 0] address]
	dict lappend map $route $a
    }

    #array set mm $map ; parray mm ; unset mm

    set r {}
    dict for {route alist} $map {
	lappend r [lindex [lsort -command [lambda {a b} {
	    expr {[string length $b] - [string length $a]}
	}] $alist] 0]
    }

    return $r
}

proc ::fx::mailer::good-address {addr} {
    set r [lindex [mime::parseaddress $addr] 0]

    # Drop empty results. Drop results which are not full addresses
    # i.e. have missing or empty local and domain parts.

    if {$r eq {}}                   { return 0 }
    if {![dict exists $r domain]}   { return 0 }
    if {[dict get $r domain] eq {}} { return 0 }
    if {![dict exists $r local]}    { return 0 }
    if {[dict get $r local] eq {}}  { return 0 }

    #puts ======================================================
    #array set aa $r ; parray aa ; unset aa

    # TODO: Filter out addresses with domains matching the local host.

    return 1
}

proc ::fx::mailer::get-sender {} {
    return [Get 0 sender]
}

proc ::fx::mailer::get-config {} {
    foreach {option listify setting} {
	-debug    0 debug
	-usetls   0 tls
	-username 0 user
	-password 0 password
	-servers  1 host
	-ports    0 port
    } {
	lappend config $option [Get $listify $setting]
    }

    lappend config -tlspolicy ::fx::mailer::TlsPolicy
    lappend config -header [list From [Get 0 sender] ]
    return $config
}

proc ::fx::mailer::Get {listify setting} {
    set  v [config get-with-default \
		[mail-config internal $setting] \
		[mail-config default  $setting]]
    if {$listify} { set v [list $v] }
    return $v
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailer::send {config receivers corpus} {
    #if {[suspended]} return
    #if {![llength $receivers]} return

    puts "    ================================================"
    puts [textutil::adjust::indent $corpus {        }]
    puts "    ================================================"

    #return

    set token [mime::initialize -string $corpus]

    foreach dst $receivers {
	puts "    To: $dst"

	# Can the 'From' be configured via -header here ?
	# I.e. config ? Alternate: -originator

	set res [smtp::sendmessage $token \
		     -header [list To $dst] \
		     {*}$config]
	foreach item $res {
	    puts "    ERR $item"
	}
    }

    mime::finalize $token
    puts "    Sent"

    variable mailcounter
    incr     mailcounter
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailer::TlsPolicy {args} {
    puts $args
    return secure
}

# # ## ### ##### ######## ############# ######################
package provide fx::mailer 0
return
