## -*- tcl -*-
# # ## ### ##### ######## ############# ######################
## Management of the "seen" events.

# @@ Meta Begin
# Package fx::seen 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fx
# Meta platform    tcl
# Meta subject     fossil
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require cmdr::color

package require fx::fossil
package require fx::manifest
package require fx::mgr::state

debug level  fx/seen
debug prefix fx/seen {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::seen {
    namespace export \
	get-event num-pending forall-pending forall-notified \
	mark-notified mark-notified-all mark-pending mark-pending-all \
	set-watched-fields get-watched-fields \
	set-progress get-field get-field-all \
	regenerate-series
    namespace ensemble create

    namespace import ::cmdr::color
    namespace import ::fx::fossil
    namespace import ::fx::manifest
    namespace import ::fx::mgr::state

    # Progress callback for the timeseries calculations.
    variable progress {}
}

namespace eval ::fx {
    namespace export seen
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::fx::seen::get-event {uuid} {
    debug.fx/seen {}
    fossil repository eval {
	SELECT event.type  AS type,
	       event.objid AS id,
	       blob.uuid   AS uuid,
	       coalesce (event.ecomment, event.comment) AS comment
	FROM  event, blob
	WHERE blob.uuid = :uuid
	AND   event.objid = blob.rid
    } {
	return [dict create type $type id $id uuid $uuid comment $comment]
    }
    # NOTE: We will be shelling out to fossil to get the artifact
    # contents. This way we avoid having to implement the entire
    # decompression (delta, inflate) ourselves. A 'libfossil' with a
    # proper C API would make this easier.
    return
}

proc ::fx::seen::num-pending {} {
    debug.fx/seen {}
    Init
    return [fossil repository onecolumn {
	    SELECT count(*)
	    FROM  event, blob
	    WHERE event.objid NOT IN (SELECT id
				      FROM fx_aku_watch_seen)
	    AND   event.objid = blob.rid
    }]
}

proc ::fx::seen::forall-pending {tv iv uv cv script} {
    debug.fx/seen {}
    Init
    FillSeries

    upvar 1 $tv type $iv id $uv uuid $cv comment

    fossil repository transaction {
	fossil repository eval {
	    SELECT
	    event.type  AS type,
	    event.objid AS id,
	    blob.uuid   AS uuid,
	    coalesce (event.ecomment, event.comment) AS comment
	    FROM  event, blob
	    WHERE event.objid NOT IN (SELECT id
				      FROM fx_aku_watch_seen)
	    AND   event.objid = blob.rid
	    ORDER BY event.objid
	} {
	    uplevel 1 $script
	    # TODO? handle break, continue
	}
    }
    # NOTE: We will be shelling out to fossil to get the artifact
    # contents. This way we avoid having to implement the entire
    # decompression (delta, inflate) ourselves. A 'libfossil' with a
    # proper C API would make this easier.
    return
}

proc ::fx::seen::forall-notified {tv iv uv cv script} {
    debug.fx/seen {}
    Init
    FillSeries

    upvar 1 $tv type $iv id $uv uuid $cv comment

    fossil repository transaction {
	fossil repository eval {
	    SELECT
	    event.type  AS type,
	    event.objid AS id,
	    blob.uuid   AS uuid,
	    coalesce (event.ecomment, event.comment) AS comment
	    FROM  event, blob
	    WHERE event.objid IN (SELECT id
				  FROM fx_aku_watch_seen)
	    AND   event.objid = blob.rid
	    ORDER BY event.objid
	} {
	    uplevel 1 $script
	    # TODO? handle break, continue
	}
    }
    # NOTE: We will be shelling out to fossil to get the artifact
    # contents. This way we avoid having to implement the entire
    # decompression (delta, inflate) ourselves. A 'libfossil' with a
    # proper C API would make this easier.
    return
}

proc ::fx::seen::mark-notified {uuid} {
    debug.fx/seen {}
    Init
    fossil repository eval {
	INSERT OR IGNORE INTO fx_aku_watch_seen
	  SELECT blob.rid
	  FROM   blob
	  WHERE  blob.uuid = :uuid
    }
    return
}

proc ::fx::seen::mark-notified-all {} {
    debug.fx/seen {}
    Init
    fossil repository eval {
	INSERT OR IGNORE INTO fx_aku_watch_seen
	  SELECT event.objid
	  FROM   event
    }
    return
}

proc ::fx::seen::mark-pending {uuid} {
    debug.fx/seen {}
    Init
    fossil repository eval {
	DELETE FROM fx_aku_watch_seen
	WHERE id IN (SELECT blob.rid
		     FROM   blob
		     WHERE  blob.uuid = :uuid)
    }
    return
}

proc ::fx::seen::mark-pending-all {} {
    debug.fx/seen {}
    Init
    fossil repository eval {
	DELETE FROM fx_aku_watch_seen
    }
    return
}

# # ## ### ##### ######## ############# ######################
## Management of a cache for the time series of all ticket fields of
## interest, i.e. used to compute the dynamically derived notes.

proc ::fx::seen::regenerate-series {config} {
    debug.fx/seen {}
    fossil show-repository-location

    if {[$config @clear]} {
	Clear
    }

    set fields [map-watched-fields]
    if {![dict size $fields]} {
	puts [color warning "No fields watched, history not required"]
	return
    }
    set num [Unprocessed]
    if {!$num} {
	puts [color warning "No pending changes"]
	return
    }

    puts "Watched fields:  [color note [dict keys $fields]]"
    puts "Pending changes: [color note $num]"

    FillSeries
    return
}

proc ::fx::seen::get-watched-fields {} {
    debug.fx/seen {}
    return [fossil repository eval {
	SELECT name
	FROM   fx_aku_watch_tktfield
    }]
}

proc ::fx::seen::map-watched-fields {} {
    # Return the field => id mapping.
    debug.fx/seen {}
    return [fossil repository eval {
	SELECT name, id
	FROM   fx_aku_watch_tktfield
    }]
}

proc ::fx::seen::set-watched-fields {fields} {
    debug.fx/seen {}
    Clear

    set flist \"[join $fields "\",\""]\"
    set alist \"[join $fields "\"), (NULL, \""]\"

    debug.fx/seen {F = |$flist|}
    debug.fx/seen {A = |$alist|}

    # Drop all fields not in the list anymore. Then add all fields,
    # ignoring the existing ones. Skip that part if there is nothing
    # to add.
    fossil repository transaction {
	fossil repository eval [subst {
	    DELETE
	    FROM fx_aku_watch_tktfield
	    WHERE name NOT IN ($flist)
	}]
	if {[llength $fields]} {
	    fossil repository eval [subst {
		INSERT OR IGNORE
		INTO fx_aku_watch_tktfield
		VALUES (NULL, $alist)
	    }]
	}
    }
    return
}

proc ::fx::seen::set-progress {cmdprefix} {
    debug.fx/seen {}
    variable progress $cmdprefix
    return
}

proc ::fx::seen::get-field {uuid field before} {
    debug.fx/seen {}
    FillSeries
    return [fossil repository onecolumn {
	SELECT S.val
	FROM fx_aku_watch_tktseries S,
	     fx_aku_watch_tkt       T,
	     fx_aku_watch_tktfield  F
	WHERE T.uuid = :uuid
	AND   F.name = :field
	AND   S.tid   = T.id
	AND   S.fid   = F.id
	AND   S.mtime < :before
	ORDER BY S.mtime
	LIMIT 1
    }]
}

proc ::fx::seen::get-field-all {uuid field before} {
    debug.fx/seen {}
    FillSeries
    return [fossil repository eval {
	SELECT S.val
	FROM fx_aku_watch_tktseries S,
	     fx_aku_watch_tkt       T,
	     fx_aku_watch_tktfield  F
	WHERE T.uuid = :uuid
	AND   F.name = :field
	AND   S.tid   = T.id
	AND   S.fid   = F.id
	AND   S.mtime < :before
	ORDER BY S.mtime
    }]
}

proc ::fx::seen::Clear {} {
    debug.fx/seen {}
    Init
    fossil repository transaction {
	fossil repository eval {
	    DELETE FROM fx_aku_watch_tkt;
	    DELETE FROM fx_aku_watch_tktseries;
	    DELETE FROM fx_aku_watch_tktseen;
	}
    }
    debug.fx/seen {done}
    return
}

proc ::fx::seen::FillSeries {} {
    debug.fx/seen {}
    Init

    set fields [map-watched-fields]

    # Without fields watched, the history is not needed and computing
    # it a waste of time.
    if {![dict size $fields]} return

    # Go over all pending ticket events and use them to compute the
    # time series of watched ticket fields. While the initial run has
    # to compute the total information all others are incremental,
    # based on new events. Of course, changes to the set of watched
    # fields clear the series and force a recalculation.

    set changes 0
    set total   [Unprocessed]
    set pending $total
    while {$pending} {
	debug.fx/seen {entries to process: $pending}
	try {
	    # Inner loop: Process in chunks of 1000
	    # (see the LIMIT clause below).
	    # TODO: Make this configurable ?
	    set progress 0
	    while {$pending} {
		debug.fx/seen {chunk ...}
		fossil repository transaction {
		    fossil repository eval {
			SELECT event.type  AS type,
			event.objid AS id,
			blob.uuid   AS uuid
			FROM  event, blob
			WHERE event.objid NOT IN (SELECT id FROM fx_aku_watch_tktseen)
			AND   event.objid = blob.rid
			LIMIT 1000
		    } {
			# type, id, uuid - Event which has not been handled before.
			debug.fx/seen {@ $uuid $type $id}
			ProcessChange $type $id $uuid $fields
			incr changes
		    }
		}
		# At least one sucessful transaction now = some events handled
		incr progress
		set pending [Unprocessed]
	    }
	} trap {FOSSIL PROCESS LOCKED} {e o} {
	    # Transaction failed because of the get-manifest get
	    # locked out even with re-trials. Swallowing the error now
	    # we restart from the top, i.e. iterate the outer loop.

	    # Except if the inner loop did not do any transaction at
	    # all, i.e. stalled without any progress before getting
	    # locked up. Then we abort as well.

	    if {!$progress} { return {*}$o $e }
	    set pending [Unprocessed]
	}
    }

    debug.fx/seen {done}
    if {!$changes} return
    Progress "Processed changes: $changes\n"
    return
}

proc ::fx::seen::ProcessChange {type id uuid fields} {
    upvar 1 changes changes total total

    # type, id, uuid - Event which has not been handled before.
    Progress "[format %10d $changes]/$total"

    # Mark all events as seen, even if not a ticket. This reduces the
    # amount of events we have to inspect on future increments.
    Processed $id

    # Detect and skip non-ticket events.
    if {$type ne "t"} {
	debug.fx/seen {skipped type ($type)}
	return
    }

    # Pull and parse the ticket change. 
    debug.fx/seen {get manifest}
    set m [manifest parse [fossil get-manifest $uuid]]

    # Detect and skip non-ticket events associated with a ticket, in
    # other words, attachment changes.
    if {[dict get $m type] eq "attachment"} {
	debug.fx/seen {skip attachment}
	return
    }

    # Now we can check if this change modifies one or more of the
    # watched fields. If yes we store the current value, together with
    # the time. Do not forget to translate the ticket uuid into a
    # proper key, and remember the same.

    set mtime [dict get $m epoch]
    set tid   [TicketOf [dict get $m ticket]]

    dict for {fname fid} $fields {
	if {![dict exists $m field $fname]} continue

	set value [dict get $m field $fname]

	Progress "[format %10d $changes]/$total:[clock format $mtime] ${fname}=$value"

	debug.fx/seen {enter $tid ($fname) $fid $mtime ($value)}
	fossil repository eval {
	    INSERT
	    INTO fx_aku_watch_tktseries
	    VALUES (:tid, :fid, :mtime, :value)
	}
    }

    return
}

proc ::fx::seen::Unprocessed {} {
    debug.fx/seen {}
    return [fossil repository onecolumn {
	SELECT count(*)
	FROM  event, blob
	WHERE event.objid NOT IN (SELECT id FROM fx_aku_watch_tktseen)
	AND   event.objid = blob.rid
    }]
}

proc ::fx::seen::Processed {id} {
    debug.fx/seen {mark as seen}
    # TODO: animation, progress display
    fossil repository eval {
	INSERT
	INTO fx_aku_watch_tktseen
	VALUES (:id)
    }
    return
}

proc ::fx::seen::TicketOf {tuuid} {
    debug.fx/seen {}
    fossil repository eval {
	INSERT OR IGNORE
	INTO fx_aku_watch_tkt
	VALUES (NULL, :tuuid);
    }

    set tid [fossil repository onecolumn {
	SELECT id
	FROM fx_aku_watch_tkt
	WHERE uuid = :tuuid
    }]

    debug.fx/seen {done =>= $tid}
    return $tid
}

proc ::fx::seen::Progress {text} {
    variable progress
    if {![llength $progress]} return
    uplevel #0 [::list {*}$progress $text]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::seen::Init {} {
    debug.fx/seen {}
    variable createsql

    fossil repository eval $createsql

    # Disable further calls.
    proc ::fx::seen::Init {} {}

    debug.fx/seen {done}
    return
}

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::seen {
    # SQL code for table creation and destruction.
    # The latter is used when dumping state, to clear old state on import.

    variable createsql {

	-- Table holding the set of timeline events we have processed
	-- already, i.e. which do not require the delivery of a
	-- notification.

	CREATE TABLE IF NOT EXISTS
	fx_aku_watch_seen
	(
	  id INTEGER PRIMARY KEY NOT NULL REFERENCES event ( objid )
	);

	-- Construct a full time series of selected ticket fields => Dynamic routing
	-- We must have access to the previous value of a changed
	-- assignment, or simply of the field if it was not changed so
	-- that we can properly route all tickets to notify who lost
	-- an assignment, or who currently has it.

	CREATE TABLE IF NOT EXISTS
	fx_aku_watch_tktfield
	(
	 id   INTEGER PRIMARY KEY AUTOINCREMENT,
	 name TEXT UNIQUE
        );

	CREATE TABLE IF NOT EXISTS
	fx_aku_watch_tkt
	(
	 id   INTEGER PRIMARY KEY NOT NULL,
	 uuid TEXT UNIQUE
        );

	CREATE TABLE IF NOT EXISTS
	fx_aku_watch_tktseries
	(
	 tid   INTEGER NOT NULL REFERENCES fx_aku_watch_tkt      ( id ),
	 fid   INTEGER NOT NULL REFERENCES fx_aku_watch_tktfield ( id ),
	 mtime DATE,
	 val   TEXT,
	 PRIMARY KEY (tid, fid, mtime)
	);

	CREATE TABLE IF NOT EXISTS
	fx_aku_watch_tktseen
	(
	  id INTEGER PRIMARY KEY NOT NULL REFERENCES event ( objid )
	);
    }

    variable dropsql {
	DROP TABLE IF EXISTS fx_aku_watch_seen;
	DROP TABLE IF EXISTS fx_aku_watch_tktfield;
	DROP TABLE IF EXISTS fx_aku_watch_tkt;
	DROP TABLE IF EXISTS fx_aku_watch_tktseries;
	DROP TABLE IF EXISTS fx_aku_watch_tktseen;
    }

    variable dumpsep    "-- [string repeat - 69]"
    variable dumpheader "-- FX State Dump - Module <seen>"
}

# # ## ### ##### ######## ############# ######################
fx::mgr::state::register ::fx::seen::DUMP

proc ::fx::seen::DUMP {} {
    variable dropsql
    variable createsql
    variable dumpheader
    variable dumpsep

    state module seen
    state sql $dropsql
    state sql $createsql
    state sep
    state table? fx_aku_watch_tktfield  {id 0 name 1}
    state table? fx_aku_watch_tkt       {id 0 uuid 1}
    state table? fx_aku_watch_tktseries {tid 0 fid 0 mtime 0 val 1}

    state table-rids? fx_aku_watch_tktseen
    state table-rids? fx_aku_watch_seen
    state sep
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::seen 0
return
