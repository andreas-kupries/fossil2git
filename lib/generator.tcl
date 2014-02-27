## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::mailgen 0
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
package require struct::matrix
package require textutil::adjust
package require clock::iso8601

namespace eval ::fx {
    namespace export mailgen
    namespace ensemble create
}
namespace eval ::fx::mailgen {
    namespace export ticket wiki event checkin
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## TODO: wiki, event, commit, control
## NOTE: Matches the external event types.

proc ::fx::mailgen::ticket {ticket} {

    # Information needed, coming with ticket.
    # - project  : Name of project
    # - location : Project location (repository url -- config)
    # - artifact : artifact uuid    (ticket change)
    # - ticket   : ticket uuid      (ticket itself)
    # - title    : ticket title                    (-- config for source field)
    # - type     : Type of change   (Change or Attachment)
    # - when     : Date of change   (becomes mailing date)
    # - user     : User responsible for the change.
    # - fields   : All changed ticket fields (field -> value dictionary).

    # + TODO sender : Sender of the mails.

    dict with ticket {} ; # => data put into local variables.

    set tshort  [string range $ticket   0 9]
    set ashort  [string range $artifact 0 9]
    set subject "\[$project\] (Ticket $tshort - $type) $title"

    # Trim the subsecond part of the timestamp.
    # Convert into a non-iso timestamp more suitable to mail readers.
    regsub {\.\d+$} $when {} cleaniso
    set maildate [clock format [clock::iso8601::parse_time $cleaniso -gmt 1] -gmt 1]

    if {$type eq "Attachment"} {
	set alink "$location/info/$artifact"
    } else {
	set alink "$location/tinfo?name=$artifact"
    }

    # Headers
    lappend lines "From:    $sender"
    lappend lines "Subject: $subject"
    lappend lines "Date:    $maildate"
    lappend lines "X-Fossil-Ticket-Note: $project"
    lappend lines "X-Tool-Origin:        http://core.tcl.tk/akupries/fx" ; # TODO make this ready

    # Separator Header/Body
    lappend lines ""

    # Body, Intro
    lappend lines "Repository: $location"
    lappend lines ""
    lappend lines "$type Notification For"
    lappend lines "  \[$title\]"
    lappend lines "  Ticket   $location/tktview?name=$ticket"
    lappend lines "  Artifact $alink"
    lappend lines "  On       $cleaniso"
    lappend lines "  By       $user"
    lappend lines ""

    # Body, Table, Changed fields.
    struct::matrix M
    M add columns 2
    foreach f [lsort -dict [dict keys $fields]] {
	set v [dict get $fields $f]
	# Special handling...

	# TODO: make this configurable per ticket fields
	# - SKIP, KEEP (default), FORMAT

	switch -exact -- $f {
	    title   -
	    comment -
	    icomment {
		# keep, reformat.
		set v [Reformat $v]
	    }
	    cmimetype -
	    mimetype {
		# skip field (suppress in output)
		continue
	    }
	    attachment::note {
		# Pseudo field for attachments, description.
		set v [reformat $v]
	    }
	    attachment::id {
		# Pseudo field for attachments, id.
		set v $location/artifact/$v
	    }
	    default  {
		# keep, do nothing
	    }
	}
	M add row [list ${f}: $v]
    }

    if {[M rows]} {
	lappend lines "Changed Fields"
	lappend lines [textutil::adjust::indent \
			   [M format 2string] \
			   {  }]
	lappend lines ""
    }
    M destroy

    return [join $lines \n]

    return
}

# # ## ### ##### ######## ############# ######################


proc  ::fx::mailgen::Reformat {s} {
    # split into paragraphs. may contain sequences of
    # empty paragraphs.
    set paragraphs {}
    set p {}
    foreach l [split $s \n] {
	if {[string trim $l] eq {}} {
	    lappend paragraphs $p
	    set p {}
	} else {
	    append p $l\n
	}
    }
    lappend paragraphs $p

    # format paragraphs, ignoring empty ones.
    set s {}
    foreach p $paragraphs {
	if {$p eq {}} continue
	append s [textutil::adjust::adjust $p \
		      -strictlength 1 \
		      -length       70] \n\n
    }

    # done
    return [string trimright $s]
}

# # ## ### ##### ######## ############# ######################
package provide fx::mailgen 0
return
