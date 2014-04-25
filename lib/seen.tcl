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
package require fx::fossil
package require fx::manifest

debug level  fx/seen
debug prefix fx/seen {[debug caller] | }

# # ## ### ##### ######## ############# ######################

namespace eval ::fx::seen {
    namespace export \
	get-event num-pending forall-pending \
	mark-notified mark-notified-all \
	mark-pending mark-pending-all \
	set-watched-fields get-watched-fields \
	set-progress get-field regenerate-series
    namespace ensemble create

    namespace import ::fx::fossil
    namespace import ::fx::manifest

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
    puts @[fossil repository-location]
    Clear
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

proc ::fx::seen::set-watched-fields {fields} {
    debug.fx/seen {}
    Clear

    set flist \"[join $fields "\",\""]\"
    set alist \"[join $fields "\"), (NULL, \""]\"

    debug.fx/seen {F = |$flist|}
    debug.fx/seen {A = |$alist|}

    # Drop all fields not in the list anymore.
    # Then add all fields, ignoring the existing ones.
    fossil repository transaction {
	fossil repository eval [subst {
	    DELETE
	    FROM fx_aku_watch_tktfield
	    WHERE name NOT IN ($flist)
	    ;
	    INSERT OR IGNORE
	    INTO fx_aku_watch_tktfield
	    VALUES (NULL, $alist)
	    ;
	}]
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

proc ::fx::seen::Clear {} {
    Init
    fossil repository transaction {
	fossil repository eval {
	    DELETE FROM fx_aku_watch_tkt;
	    DELETE FROM fx_aku_watch_tktseries;
	    DELETE FROM fx_aku_watch_tktseen;
	}
    }
    return
}

proc ::fx::seen::FillSeries {} {
    debug.fx/seen {}
    Init
    # Get field => id mapping.

    set fields [fossil repository eval {
	SELECT name, id
	FROM fx_aku_watch_tktfield
    }]

    # Go over all pending ticket events and use them to compute the
    # time series of watched ticket fields. While the initial run has
    # to compute the total information all others are incremental,
    # based on new events. Of course, changes to the set of watched
    # fields clear the series and force a recalculation.

    set num [Unprocessed]
    debug.fx/seen {entries to process: $num}

    # Quick exit if there is nothing to process.
    if {!$num} return

    # TODO: Chunk the processing into shorter transactions so that
    # progress can be made by iterating the core even if one
    # transaction fails (db locked or some such) as long as actual
    # progress is made this way.

    set changes 0
    fossil repository transaction {
	fossil repository eval {
	    SELECT event.type  AS type,
	           event.objid AS id,
	           blob.uuid   AS uuid
	    FROM  event, blob
	    WHERE event.objid NOT IN (SELECT id FROM fx_aku_watch_tktseen)
	    AND   event.objid = blob.rid
	} {
	    # type, id, uuid - Event which has not been handled before.
	    debug.fx/seen {@ $uuid $type $id}
	    incr changes [ProcessChange $type $id $uuid]
	}
    }

    debug.fx/seen {done}
    if {!$changes} return
    Progress "Processed changes: $changes\n"
    return
}

proc ::fx::seen::ProcessChange {type id uuid} {
    upvar 1 changes changes num num

    # type, id, uuid - Event which has not been handled before.
    #Progress $uuid

    # Mark all events as seen, even if not a ticket. This reduces the
    # amount of events we have to inspect on future increments.
    Processed $id

    # Detect and skip non-ticket events.
    if {$type ne "t"} {
	debug.fx/seen {skipped type ($t)}
	return 0
    }

    # Pull and parse the ticket change. 
    debug.fx/seen {get manifest}
    set m [manifest parse [fossil get-manifest $uuid]]

    # Detect and skip non-ticket events associated with a ticket, in
    # other words, attachment changes.
    if {[dict get $m type] eq "attachment"} {
	debug.fx/seen {skip attachment}
	return 0
    }

    # Now we can check if this change modifies one or more of the
    # watched fields. If yes we store the current value, together with
    # the time. Do not forget to translate the ticket uuid into a
    # proper key, and remember the same.

    set mtime [dict get $m epoch]
    set tid   [TicketOf [dict get $m ticket]]

    dict for {fname fid} $fields {
	if {![dict exists $m field $fname]} continue

	#incr changes
	set value [dict get $m field $fname]

	Progress "[format %10d $changes]/$num:[clock format $mtime] ${fname}=$value"

	debug.fx/seen {enter $tid ($fname) $fid $mtime ($value)}
	fossil repository eval {
	    INSERT
	    INTO fx_aku_watch_tktseries
	    VALUES (:tid, :fid, :mtime, :value)
	}
    }

    return 1
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

    set tuuid [dict get $m ticket]

    debug.fx/seen {remember ticket $tuuid}
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
    fossil repository eval {

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

    # Disable further calls.
    proc ::fx::seen::Init {} {}

    debug.fx/seen {done}
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::seen 0
return
