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
    namespace export test \
	ticket wiki event commit control \
	attachment
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################
## The generator commands match the artifact types, not the
## timeline event types. For attachments we have a context
## which tells the type of change artifact (ticket, wiki, event)
## to configure the mail in detail.
##
## TODO: test, wiki, event, commit, control, attachment.

proc ::fx::mailgen::test {sender} {
    Begin
    Headers \
	$sender \
	"FX mail configuration test mail" \
	[clock format [clock seconds] -gmt 1]
    Body
    # empty body?
    Done
}

proc ::fx::mailgen::artifact {m} {
    # Dynamic dispatch by artifact type
    return [[dict get $m type] $m]
}

proc ::fx::mailgen::event {m} {
    # General
    #  - context == 'event'
    #  - location
    #  - project
    #  - self     -- event change id
    #  - tcomment == card.comment?
    # Cards|Dict
    # C - comment
    # D - when       ==> date of change = notification => maildate
    # E - when-event -- event-date 
    #     eventid    -- event id (over all changes)
    # N - mimetype => optional, for comment
    # P - /
    # T - / - event tags - should have?
    # U - user
    # W - text
    # Z - /

    # Note: self    = uuid of the control artifact describing the event (change).
    #       eventid = uuid of the event itself
    # Same difference like for tickets with ticket change uuid and ticket uuid.

    dict with m {}
    if {![info exists mimetype]} {
	set mimetype text/x-fossil
    }

    # Conversion of x-fossil to plain text ?
    # => tcomment, comment, event text

    Begin
    Headers ?sender \
	"\[$project\] Event $tcomment" \
	[clock format $when -gmt 1]
    + "X-Fossil-FX-Project: $project"
    Body
    # Show: tags?
    + "Notification for $project Event "
    + "  \[$tcomment\]"
    +T Project    $project
    +T Repository $location
    +T Event      $location/event/$$eventid
    +T On         [clock format ${when-event} -gmt 1]
    +T By         $user

    # Text may not exist, artifact may contain only data/tag changes
    # for the event in question.
    if {[info exists $text]} {
	+ ""
	+ [Reformat $text]
    }
    Done
}

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
    Begin
    Headers $sender $subject $maildate
    + "X-Fossil-FX-Project: $project"
    Body
    # Body, Intro
    + "Repository: $location"
    + ""
    + "$type Notification For"
    + "  \[$title\]"
    + "  Ticket   $location/tktview?name=$ticket"
    + "  Artifact $alink"
    + "  On       $cleaniso"
    + "  By       $user"
    + ""

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
	+ "Changed Fields"
	+ [textutil::adjust::indent \
	       [M format 2string] \
	       {  }]
	+ ""
    }
    M destroy

    Done
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailgen::Begin {} {
    upvar 1 lines lines
    set     lines {}
    return
}

proc ::fx::mailgen::Done {} {
    upvar 1 lines lines T T
    catch { $T destroy }
    return -code return [join $lines \n]
}

proc ::fx::mailgen::+T {field value} {
    upvar 1 T T
    if {![info exists T]} {
	set T [struct::matrix TABLE]
	$T add columns 2
    }
    $T add row [list $field $value]
    return
}

proc ::fx::mailgen::+ {line} {
    upvar 1 lines lines
    lappend lines $line
    return
}

proc ::fx::mailgen::Headers {sender subject date} {
    upvar 1 lines lines
    + "From:    $sender"
    + "Subject: $subject"
    + "Date:    $date"
    + "X-Fossil-FX-Note:"
    + "X-Tool-Origin: http://core.tcl.tk/akupries/fx" ; # TODO make this ready
    return
}

proc ::fx::mailgen::Body {} {
    upvar 1 lines lines
    + ""
    return
}

proc ::fx::mailgen::Reformat {s} {
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
