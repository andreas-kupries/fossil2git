## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::mailer 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
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

namespace eval ::fx::mailer {
    namespace export get-config send
    namespace ensemble create

    namespace import ::fx::mgr::config
    namespace import ::fx::validate::mail-config
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailer::get-config {db} {
    foreach {option listify setting} {
	-debug    0 debug
	-usetls   0 tls
	-username 0 user
	-password 0 password
	-servers  1 host
	-ports    0 port
    } {
	lappend config $option [Get $db $listify $setting]
    }

    lappend config -tlspolicy ::fx::mailer::TlsPolicy

    # lappend config -header [list From [Get $db 0 sender] ]
    return $config
}

proc ::fx::mailer::Get {db listify setting} {
    set  v [config get-width-default $db \
		[mail-config internal $setting] \
		[mail-config default  $setting]]
    if {$listify} { set v [list $v] }
    return $v
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailer::send {config receivers corpuscmd} {
    if {[suspended]} return
    if {![llength $receivers]} return

    set corpus [{*}$corpuscmd]

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
