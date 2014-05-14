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
package require fx::manifest
package require http

debug level  fx/mailgen
debug prefix fx/mailgen {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval ::fx {
    namespace export mailgen
    namespace ensemble create
}
namespace eval ::fx::mailgen {
    namespace export test artifact limit for-error
    # manifest types
    # - attachment OK
    # - checkin    OK (to test: branch/changeset extraction)
    # - control    OK
    # - event      OK
    # - ticket     OK
    # - wiki       OK
    namespace ensemble create

    namespace import ::fx::fossil
    namespace import ::fx::manifest

    # Limit for table fields in generated mail, and
    # Limit marker to use when truncating.
    # TODO: Make them configurable
    variable flimit   2048
    variable flsuffix "\n...((truncated))"
}

# # ## ### ##### ######## ############# ######################
## The generator commands match the artifact types, not the
## timeline event types. For attachments we have a context
## which tells the type of change artifact (ticket, wiki, event)
## to configure the mail in detail.

proc ::fx::mailgen::for-error {stacktrace} {
    Begin
    Headers \
	FX \
	http://core.tcl.tk/akupries/fx \
	"FX Internal Error" [clock seconds]
    Body {} {}
    + Context
    + ""
    + StackTrace
    +T "" $stacktrace
    =T
    Done {} {}
}

proc ::fx::mailgen::test {sender header footer} {
    debug.fx/mailgen {}
    Begin
    Headers \
	Test Test \
	"FX mail configuration test mail" \
	[clock seconds]
    Body $sender $header
    + "Testing ... 1, 2, 3 ..."
    Done $sender $footer
}

proc ::fx::mailgen::artifact {m} {
    debug.fx/mailgen {}
    # Dynamic dispatch by artifact type

    # NOT by event type. The event type however can be used by the
    # generator to tweak its out. Example would the handling of
    # attachments, which can occur for tickets, events, and wiki
    # pages, and require different urls to reference this context
    # artifact.

    try {
	set text [[dict get $m type] $m]
    } finally {
	catch { TABLE destroy }
    }
    return $text
}

proc ::fx::mailgen::limit {n text {suffix ...}} {
    if {($n > 0) && ([string length $text]) > $n} {
	set text [string range $text 0 $n]$suffix
    }
    return $text
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailgen::attachment {m} {
    debug.fx/mailgen {}
    # Possible etypes: ticket, event, wiki

    # Fields:           Source     Notes
    # ------            ------     -----
    #   attachment,op   Manifest   Added/Removed
    #   attachment,path Manifest   Filename of the attachment
    #   attachment,uuid Manifest   uuid of attachment data blob
    #   comment         Manifest   Attachment description /optional
    #   ecomment        EVENT      Timeline text
    #   epoch           (when)     Unix epoch of commit timestamp
    #   etype           EVENT      ASSERT {event, ticket, wiki}
    #   header          sys config Project-specific mail header
    #   footer          sys config Project-specific mail footer/signature
    #   location        sys config Project repository web location
    #   project         sys config Project name
    #   self            system     Manifest uuid
    #   sender          sys config Mail sender address
    #   target          Manifest   Reference to holder of attachment.
    #   type            Manifest   Fixed "attachment"
    #   user            Manifest   Committer
    #   when            Manifest   Commit timestamp
    # ------            ------     -----

    dict with m {}
    CheckType attachment {event ticket wiki}

    if {![info exists comment]} {
	set comment "<no description given>"
    }

    set op [string totitle ${attachment,op}]
    if {$op eq "Added"} {
	set verb To
    } else {
	set verb From
    }

    Begin
    Headers $project $location [Subject] $epoch
    Body $sender $header
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

    Done $sender $footer
}

proc ::fx::mailgen::checkin {m} {
    debug.fx/mailgen {}
    # Fields:     Source     Notes
    # ------      ------     -----
    #   comment   Manifest   Commit message
    #   ecomment  EVENT      Timeline text (= comment, 1st line)
    #   epoch     (when)     Unix epoch of commit timestamp
    #   etype     EVENT      Fixed "commit" ASSERT
    #   header    sys config Project-specific mail header
    #   footer    sys config Project-specific mail footer/signature
    #   location  sys config Project repository web location
    #   project   sys config Project name
    #   self      system     Manifest uuid
    #   sender    sys config Mail sender address
    #   type      Manifest   Fixed "checkin"
    #   user      Manifest   Committer
    #   when      Manifest   Commit timestamp
    # ------      ------     -----

    dict with m {}
    CheckType checkin commit

    set changes [fossil changeset $self]
    set branch  [fossil branch-of $self]
    if {$branch eq ""} { set branch <unknown> }

    Begin
    Headers $project $location [Subject "Commit by $user - "] $epoch
    Body $sender $header
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

    Done $sender $footer
}

proc ::fx::mailgen::control {m} {
    debug.fx/mailgen {}
    # Possible etypes: control (checkin, event)

    # Fields:     Source         Notes
    # ------      ------         -----
    #   ecomment    EVENT        Timeline text
    #   epoch       (when)       Unix epoch of commit timestamp
    #   etype       EVENT        ASSERT {checkin, event}
    #   header      sys config   Project-specific mail header
    #   footer      sys config   Project-specific mail footer/signature
    #   location    sys config   Project repository web location
    #   project     sys config   Project name
    #   self        system       Manifest uuid
    #   sender      sys config   Mail sender address
    #   tags        Manifest     Dictionary of event tag settings/changes
    #   type        Manifest     Fixed "event"
    #   user        Manifest     Committer
    #   when        Manifest     Commit timestamp
    # ------      ------         -----

    dict with m {}
    CheckType control control

    Begin
    Headers $project $location [Subject] $epoch
    Body $sender $header
    +T By      $user
    +T For     "$project"
    +T On      $when
    =T

    # Rewrite tags :: dict( name -> (ref, action, ?value?) )
    # into    map  :: dict( ref -> list( (name, action, ?value? )))
    # for iteration and display per referenced artifact.

    dict for {tag data} $tags {
	set ref [lindex $data 0]
	dict lappend map $ref [lreplace $data 0 0 $tag]
    }

    # Show tag information per modified artifact.
    foreach ref [lsort -dict [dict keys $map]] {
	if {[catch {
	    set link [InfoLink [dict get [manifest parse [fossil get-manifest $ref]] type] $ref]
	}]} {
	    set link "$ref (unknown artifact)"
	}

	+ ""
	+ "Changed $link"

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
    Done $sender $footer
}

proc ::fx::mailgen::event {m} {
    debug.fx/mailgen {}
    # Fields:       Source       Notes
    # ------        ------       -----
    #   comment     Manifest     Event description
    #   ecomment    EVENT        Timeline text
    #   epoch       (when)       Unix epoch of commit timestamp
    #   epoch-event (when-event) Unix epoch of event occurence
    #   etype       EVENT        Fixed "event" ASSERT
    #   eventid     Manifest     Uuid of the event (page)
    #   header      sys config   Project-specific mail header
    #   footer      sys config   Project-specific mail footer/signature
    #   location    sys config   Project repository web location
    #   project     sys config   Project name
    #   self        system       Manifest uuid
    #   sender      sys config   Mail sender address
    #   tags        Manifest     Dictionary of event tag settings/changes /optional
    #   text        Manifest     Text of the event page.
    #   type        Manifest     Fixed "event"
    #   user        Manifest     Committer
    #   when        Manifest     Commit timestamp
    #   when-event  Manifest     Event occurence
    # ------        ------       -----

    dict with m {}
    CheckType {event change} event

    Begin
    Headers $project $location [Subject] $epoch
    Body $sender $header
    + "Event Change \[$self\]"
    +T By         $user
    +T For        $project
    +T On         $when
    +T Details    [InfoLink event $eventid]
    +T "To occur" ${when-event}

    # Note, tag information is optional.
    if {[info exists tags]} {
	foreach tag [lsort -dict [dict keys $tags]] {
	    lassign [dict get $tags $tag] _ action value
	    if {$action eq "="} {
		+T "Tag $tag" $value
	    } else {
		+T "Tag $tag" ""
	    }
	}
    }
    =T

    # Text of event left out. Follow the "Details" link.
    Done $sender $footer
}

proc ::fx::mailgen::ticket {m} {
    debug.fx/mailgen {}
    # Fields:     Source     Notes
    # ------      ------     -----
    #   ecomment  EVENT      Timeline text
    #   epoch     (when)     Unix epoch of commit timestamp
    #   etype     EVENT      Fixed "ticket" ASSERT
    #   field     Manifest   Dictionary of the changed fields and their new values.
    #   header    sys config Project-specific mail header
    #   footer    sys config Project-specific mail footer/signature
    #   location  sys config Project repository web location
    #   project   sys config Project name
    #   self      system     Manifest uuid
    #   sender    sys config Mail sender address
    #   ticket    Manifest   Ticket uuid, of the changed ticket
    #   type      Manifest   Fixed "ticket"
    #   user      Manifest   Committer
    #   when      Manifest   Commit timestamp
    # ------      ------     -----

    dict with m {}
    CheckType {ticket change} ticket

    Begin
    Headers $project $location [Subject] $epoch
    Body $sender $header
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

	# TODO: make this configurable per ticket fields
	# - SKIP, KEEP (default), FORMAT, DATE

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
	    closedate {
		# sqlite timestamp (fractional julianday)
		set v [fossil date-of $v]
	    }
	    default  {
		# keep, do nothing
	    }
	}
	+T ${f}: $v
    }
    =T
    Done $sender $footer
}

proc ::fx::mailgen::wiki {m} {
    debug.fx/mailgen {}
    # Fields:     Source     Notes
    # ------      ------     -----
    #   ecomment  EVENT      "Changes to wiki page [...]"
    #   epoch     (when)     Unix epoch of commit timestamp
    #   etype     EVENT      Fixed "wiki" ASSERT
    #   header    sys config Project-specific mail header
    #   footer    sys config Project-specific mail footer/signature
    #   location  sys config Project repository web location
    #   project   sys config Project name
    #   self      system     Manifest uuid
    #   sender    sys config Mail sender address
    #   text      Manifest   Text of the wiki page.
    #   title     Manifest   Name of the wiki page.
    #   type      Manifest   Fixed "wiki"
    #   user      Manifest   Committer
    #   when      Manifest   Commit timestamp
    # ------      ------     -----

    dict with m {}
    CheckType {wiki change} wiki

    Begin
    Headers $project $location [Subject] $epoch
    Body $sender $header
    + "Wiki Change \[$self\]"
    +T Page    $title
    +T By      $user
    +T For     $project
    +T On      $when
    +T Details [InfoLink wiki $title]
    =T

    # Text of page left out. Follow the "Details" link.
    Done $sender $footer
}

# # ## ### ##### ######## ############# ######################

proc ::fx::mailgen::CheckType {label legal} {
    upvar 1 etype etype
    if {$etype in $legal} return
    error "Unexpected etype \"$etype\" for $label"
}

proc ::fx::mailgen::InfoText {type} {
    debug.fx/mailgen {}
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
    debug.fx/mailgen {}
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

proc ::fx::mailgen::Done {sender footer} {
    upvar 1 lines lines T T
    catch { $T destroy }

    if {$footer ne {}} {
	# separate footer from mail body
	lappend map @sender@ $sender
	lappend map @sender  $sender
	lappend map @cmd@    [file tail $::argv0]

	+ ""
	+ [string repeat - 60]
	+ [string map $map $footer]
	+ [string repeat - 60]
    }

    + ""
    return -code return [join $lines \n]
}

proc ::fx::mailgen::+T {field value} {
    upvar 1 T T
    variable flimit
    variable flsuffix
    set value [limit $flimit $value $flsuffix]

    if {![info exists T]} {
	# Note: Even without T a TABLE instance may be left over from
	# a previous generator call which failed with an error and
	# thus did not clean up properly.
	catch { TABLE destroy }
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
    set subj [lindex [split $ecomment \n] 0]
    return "\[$project\] $prefix$subj"
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

proc ::fx::mailgen::Body {sender header} {
    upvar 1 lines lines
    + ""
    if {$header ne {}} {
	lappend map @sender@ $sender
	lappend map @sender  $sender
	lappend map @cmd@    [file tail $::argv0]
	+ [string map $map $header]
	+ ""
    }
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
