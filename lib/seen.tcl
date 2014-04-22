## -*- tcl -*-
# # ## ### ##### ######## ############# ######################
## Management of the "seen" events.

# @@ Meta Begin
# Package fx::seen 0
# Meta author      {Andreas Kupries}
# Meta category    ?
# Meta description ?
# Meta location    http:/core.tcl.tk/akupries/fossil2git
# Meta platform    tcl
# Meta subject     fossil
# Meta summary     ?
# @@ Meta End

package require Tcl 8.5
package require fx::fossil
package require fx::manifest

namespace eval ::fx::seen {
    namespace export \
	get-event forall-pending \
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

proc ::fx::seen::forall-pending {tv iv uv cv script} {
    Init
    upvar 1 $tv type $iv id $uv uuid $cv comment

    FillSeries

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
    # TODO dry run

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
    # TODO dry run

    Init
    fossil repository eval {
	INSERT OR IGNORE INTO fx_aku_watch_seen
	  SELECT event.objid
	  FROM   event
    }
    return
}

proc ::fx::seen::mark-pending {uuid} {
    # TODO dry run

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
    # TODO dry run
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
    puts @[fossil repository-location]
    Clear
    FillSeries
    return
}

proc ::fx::seen::get-watched-fields {} {
    return [fossil repository eval {
	SELECT name
	FROM   fx_aku_watch_tktfield
    }]
}

proc ::fx::seen::set-watched-fields {fields} {
    Clear

    #puts |$fields|
    set flist \"[join $fields "\",\""]\"
    set alist \"[join $fields "\"), (NULL, \""]\"

    #puts F|$flist|
    #puts A|$alist|

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
    variable progress $cmdprefix
    return
}

proc ::fx::seen::get-field {uuid field before} {
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
    # Get field => id mapping.

    set fields [fossil repository eval {
	SELECT name, id
	FROM fx_aku_watch_tktfield
    }]

    # Go over all pending ticket events and use them to compute the
    # time series of watched ticket fields. While the initial run has
    # to compute the total information al others are incremental,
    # based on new events. Of course, changes to the set of watched
    # fields clear the series and force a recalculation.

    fossil repository transaction {
	fossil repository eval {
	    SELECT event.type  AS type,
	           event.objid AS id,
	           blob.uuid   AS uuid
	    FROM  event, blob
	    WHERE event.objid NOT IN (SELECT id FROM fx_aku_watch_tktseen)
	    AND   event.objid = blob.rid
	} {
	    #Progress $uuid

	    # type, id, uuid - Event which has not been handled before.

	    # Mark all events as seen, even if not a ticket. This
	    # reduces the amount of events we have to inspect on
	    # future increments.

	    fossil repository eval {
		INSERT
		INTO fx_aku_watch_tktseen
		VALUES (:id)
	    }

	    # Detect and skip non-ticket events.
	    if {$type ne "t"} continue

	    # Pull and parse the ticket change. 
	    set m [manifest parse [fossil get-manifest $uuid]]

	    # Detect and skip non-ticket events associated with a
	    # ticket, IOW attachment changes.
	    if {[dict get $m type] eq "attachment"} continue

	    # Now we can check if this change modifies one or more of
	    # the watched fields. If yes we store the current value,
	    # together with the time. Do not forget to translate the
	    # ticket uuid into a proper key, and remember the same.

	    #puts |$m|

	    set mtime [dict get $m epoch]
	    set tuuid [dict get $m ticket]

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

	    dict for {fname fid} $fields {
		if {![dict exists $m field $fname]} continue

		set value [dict get $m field $fname]

		Progress +[format %10d $tid]|[format %10d $fid]|[format %15d $mtime]|$fname|$value

		fossil repository eval {
		    INSERT
		    INTO fx_aku_watch_tktseries
		    VALUES (:tid, :fid, :mtime, :value)
		}
	    }
	}
    }
    return
}

proc ::fx::seen::Progress {text} {
    variable progress
    if {![llength $progress]} return
    uplevel #0 [::list {*}$progress $text]
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::seen::Init {} {
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
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::seen 0
return
