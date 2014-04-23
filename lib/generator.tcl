## -*- tcl -*-
# # ## ### ##### ######## ############# ######################

# @@ Meta Begin
# Package fx::mailgen 0
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
package require struct::matrix
package require textutil::adjust
package require clock::iso8601
package require fx::fossil
package require http

namespace eval ::fx {
    namespace export mailgen
    namespace ensemble create
}
namespace eval ::fx::mailgen {
    namespace export test artifact limit
    # manifest types
    # - attachment OK
    # - checkin    OK (to test: branch/changeset extraction)
    # - control    
    # - event      OK
    # - ticket     OK
    # - wiki       OK
    namespace ensemble create

    namespace import ::fx::fossil
}

# # ## ### ##### ######## ############# ######################
## The generator commands match the artifact types, not the
## timeline event types. For attachments we have a context
## which tells the type of change artifact (ticket, wiki, event)
## to configure the mail in detail.

proc ::fx::mailgen::test {} {
    Begin
    Headers \
	Test Test \
	"FX mail configuration test mail" \
	[clock seconds]
    Body
    + "Testing ... 1, 2, 3 ..."
    Done
}

proc ::fx::mailgen::artifact {m} {
    # Dynamic dispatch by artifact type

    # NOT by event type. The event type however can be used by the
    # generator to tweak its out. Example would the handling of
    # attachments, which can occur for tickets, events, and wiki
    # pages, and require different urls to reference this context
    # artifact.

    return [[dict get $m type] $m]
}

proc ::fx::mailgen::limit {n text} {
    if {($n > 0) && ([string length $text]) > $n} {
	set text [string range $text 0 $n]...
    }
    return $text
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailgen::attachment {m} {
    # Possible etypes: ticket, event, wiki

    # Fields:           Source     Notes
    # ------            ------     -----
    #   attachment,op   Manifest   Added/Removed
    #   attachment,path Manifest   Filename of the attachment
    #   attachment,uuid Manifest   uuid of attachment data blob
    #   comment         Manifest   Attachment description
    #   ecomment        EVENT      Timeline text
    #   epoch           (when)     Unix epoch of commit timestamp
    #   etype           EVENT      ASSERT {event, ticket, wiki}
    #   location        sys config Project repository web location
    #   project         sys config Project name
    #   self            system     Manifest uuid
    #   target          Manifest   Reference to holder of attachment.
    #   type            Manifest   Fixed "attachment"
    #   user            Manifest   Committer
    #   when            Manifest   Commit timestamp
    # ------            ------     -----

    dict with m {}
    if {$etype ni {event ticket wiki}} {
	error "Unexpected etype \"$etype\" for attachment"
    }

    set op [string totitle ${attachment,op}]
    if {$op eq "Added"} {
	set verb To
    } else {
	set verb From
    }

    Begin
    Headers $project $location [Subject] $epoch
    Body
    + "$op Attachment \[${attachment,uuid}\]"
    + "  \[${attachment,path}\]"
    + $verb
    +T [InfoText $etype] [InfoLink $etype $target]
    +T By       $user
    +T For      "$project"
    +T On       $when
    +T Details  [InfoLink attachment $self]
    +T Contents [InfoLink blob ${attachment,uuid}]
    =T

    + ""
    + Description
    +T "" [Reformat $comment]
    =T

    Done
}

proc ::fx::mailgen::checkin {m} {
    # Fields:     Source     Notes
    # ------      ------     -----
    #   comment   Manifest   Commit message
    #   ecomment  EVENT      Timeline text (= comment, 1st line)
    #   epoch     (when)     Unix epoch of commit timestamp
    #   etype     EVENT      Fixed "commit" ASSERT
    #   location  sys config Project repository web location
    #   project   sys config Project name
    #   self      system     Manifest uuid
    #   type      Manifest   Fixed "checkin"
    #   user      Manifest   Committer
    #   when      Manifest   Commit timestamp
    # ------      ------     -----

    dict with m {}
    if {$etype ne "commit"} { error "Unexpected etype \"$etype\" for checkin" }

    set changes [fossil changeset $self]
    set branch  [fossil branch-of $self]
    if {$branch eq ""} { set branch <unknown> }

    Begin
    Headers $project $location [Subject "Commit by $user - "] $epoch
    Body
    + "Commit \[$self\]"
    +T By      $user
    +T For     "$project (branch: $branch)"
    +T On      $when
    +T Details [InfoLink checkin $self]
    =T

    + ""
    + Description
    +T "" [Reformat $ecomment]
    =T

    + ""
    + "Changed Files"

    if {![dict size $changes]} {
	+T "" <unknown>
    } else {
	foreach action [lsort -dict [dict keys $changes]] {
	    +T $action ""
	    foreach path [lsort -dict [dict get $changes $action]] {
		+T "" $path
	    }
	}
    }
    =T

    Done
}

proc ::fx::mailgen::control {m} {
    # Possible etypes: control (checkin, event)

    # Fields:     Source         Notes
    # ------      ------         -----
    #   ecomment    EVENT        Timeline text
    #   epoch       (when)       Unix epoch of commit timestamp
    #   etype       EVENT        ASSERT {checkin, event}
    #   location    sys config   Project repository web location
    #   project     sys config   Project name
    #   self        system       Manifest uuid
    #   tags        Manifest     Dictionary of event tag settings/changes
    #   type        Manifest     Fixed "event"
    #   user        Manifest     Committer
    #   when        Manifest     Commit timestamp
    # ------      ------         -----

    dict with m {}
    if {$etype ne "control"} {
	error "Unexpected etype \"$etype\" for control"
    }

    Begin
    Headers $project $location [Subject] $epoch
    Body
    +T By      $user
    +T For     "$project"
    +T On      $when

    # Rewrite tags :: dict( name -> (ref, action, ?value?) )
    # into    map  :: dict( ref -> list( (name, action, ?value? )))
    # for iteration and display per referenced artifact.

    dict for {tag data} $tags {
	set ref [lindex $data 0]
	dict lappend map $ref [lreplace $data 0 0 $tag]
    }

    # Show tag information per modified artifact.
    foreach ref [lsort -dict [dict keys $map]] {
	+ "$ref"
	# TODO: pull artifact, determine type, display proper link

	foreach taginfo [dict get $map $ref] {
	    lassign $taginfo tag action value

	    if {$action eq "="} {
		+T "Tag $tag" [Reformat $value]
	    } else {
		+T "Tag $tag" ""
	    }
	}
    }

    =T
    Done
}

proc ::fx::mailgen::event {m} {
    # Fields:       Source       Notes
    # ------        ------       -----
    #   comment     Manifest     Event description
    #   ecomment    EVENT        Timeline text
    #   epoch       (when)       Unix epoch of commit timestamp
    #   epoch-event (when-event) Unix epoch of event occurence
    #   etype       EVENT        Fixed "event" ASSERT
    #   eventid     Manifest     Uuid of the event (page)
    #   location    sys config   Project repository web location
    #   project     sys config   Project name
    #   self        system       Manifest uuid
    #   tags        Manifest     Dictionary of event tag settings/changes
    #   text        Manifest     Text of the event page.
    #   type        Manifest     Fixed "event"
    #   user        Manifest     Committer
    #   when        Manifest     Commit timestamp
    #   when-event  Manifest     Event occurence
    # ------        ------       -----

    dict with m {}
    if {$etype ne "event"} { error "Unexpected etype \"$etype\" for event change" }

    Begin
    Headers $project $location [Subject] $epoch
    Body
    + "Event Change \[$self\]"
    +T By         $user
    +T For        $project
    +T On         $when
    +T Details    [InfoLink event $eventid]
    +T "To occur" ${when-event}

    foreach tag [lsort -dict [dict keys $tags]] {
	lassign [dict get $tags $tag] _ action value
	if {$action eq "="} {
	    +T "Tag $tag" $value
	} else {
	    +T "Tag $tag" ""
	}
    }
    =T

    # Text of event left out. Follow the "Details" link.
    Done
}

proc ::fx::mailgen::ticket {m} {
    # Fields:     Source     Notes
    # ------      ------     -----
    #   ecomment  EVENT      Timeline text
    #   epoch     (when)     Unix epoch of commit timestamp
    #   etype     EVENT      Fixed "ticket" ASSERT
    #   field     Manifest   Dictionary of the changed fields and their new values.
    #   location  sys config Project repository web location
    #   project   sys config Project name
    #   self      system     Manifest uuid
    #   ticket    Manifest   Ticket uuid, of the changed ticket
    #   type      Manifest   Fixed "ticket"
    #   user      Manifest   Committer
    #   when      Manifest   Commit timestamp
    # ------      ------     -----

    dict with m {} ; # => data put into local variables.
    if {$etype ne "ticket"} { error "Unexpected etype \"$etype\" for ticket change" }

    Begin
    Headers $project $location [Subject] $epoch
    Body
    # Body, Intro

    + "Ticket Change \[$self\]"
    + "  \[$ecomment\]"
    +T By      $user
    +T For     $project
    +T On      $when
    +T Details [InfoLink tktchange $self]
    +T Ticket  [InfoLink ticket $ticket]
    =T

    + ""
    + "Changed Fields"
    foreach f [lsort -dict [dict keys $field]] {
	set v [dict get $field $f]
	# Special handling...

	# TODO: make this configurable per ticket fields - SKIP, KEEP
	# (default), FORMAT

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
	    default  {
		# keep, do nothing
	    }
	}
	+T ${f}: $v
    }
    =T

    Done
}

proc ::fx::mailgen::wiki {m} {
    # Fields:     Source     Notes
    # ------      ------     -----
    #   ecomment  EVENT      "Changes to wiki page [...]"
    #   epoch     (when)     Unix epoch of commit timestamp
    #   etype     EVENT      Fixed "wiki" ASSERT
    #   location  sys config Project repository web location
    #   project   sys config Project name
    #   self      system     Manifest uuid
    #   text      Manifest   Text of the wiki page.
    #   title     Manifest   Name of the wiki page.
    #   type      Manifest   Fixed "wiki"
    #   user      Manifest   Committer
    #   when      Manifest   Commit timestamp
    # ------      ------     -----

    dict with m {}
    if {$etype ne "wiki"} { error "Unexpected etype \"$etype\" for wiki change" }

    Begin
    Headers $project $location [Subject] $epoch
    Body
    + "Wiki Change \[$self\]"
    +T Page    $title
    +T By      $user
    +T For     $project
    +T On      $when
    +T Details [InfoLink wiki $title]
    =T

    # Text of page left out. Follow the "Details" link.

    Done
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailgen::InfoText {type} {
    # consider a dict for mapping.
    switch -exact $type {
	attachment { return Attachment }
	checkin    { return Commit     }
	event      { return Event      }
	ticket     { return Ticket     }
	wiki       { return Wiki       }
    }
}

proc ::fx::mailgen::InfoLink {type detail} {
    upvar 1 location location
    switch -exact $type {
	attachment { return $location/ainfo/$detail }
	blob       { return $location/artifact/$detail }
	checkin    { return $location/info/$detail		       	 }
	event      { return $location/event/$detail			 }
	ticket     { return $location/tktview/$detail			 }
	tktchange  { return $location/tinfo?name=$detail	       	 }
	wiki       { return $location/wiki?[http::formatQuery name $detail] }
    }
}

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

proc ::fx::mailgen::=T {} {
    upvar 1 T T lines lines
    if {![info exists T]} return

    if {[$T rows]} {
	+ [textutil::adjust::indent [$T format 2string] {  }]
    }
    $T destroy
    unset T
    return
}

proc ::fx::mailgen::+ {line} {
    upvar 1 lines lines
    lappend lines $line
    return
}

proc ::fx::mailgen::Subject {{prefix {}}} {
    upvar 1 project project ecomment ecomment
    # Strip html tags out of the ecomment, bad for the mail.
    regsub -all {<([^>]+)>} $ecomment {} ecomment
    # Reduce to first line.
    set ecomment [lindex [split $ecomment \n] 0]
    return "\[$project\] $prefix$ecomment"
}

proc ::fx::mailgen::Headers {project location subject epoch} {
    set date  [clock format $epoch -gmt 1]

    upvar 1 lines lines
    + "Subject: $subject"
    + "Date:    $date"
    + "X-Fossil-FX-Note:"
    + "X-Tool-Origin: http://core.tcl.tk/akupries/fx" ; # TODO make this ready
    + "X-Fossil-FX-Project-Name: $project"
    + "X-Fossil-FX-Project-Location: $location"
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
