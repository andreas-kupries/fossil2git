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

namespace eval ::fx::seen {
    namespace export forall-pending \
	mark-notified mark-notified-all \
	mark-pending mark-pending-all \
	get-event
    namespace ensemble create

    namespace import ::fx::fossil
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

proc ::fx::seen::Init {} {
    fossil repository eval {
	CREATE TABLE IF NOT EXISTS
	fx_aku_watch_seen
	(
	  id INTEGER PRIMARY KEY NOT NULL REFERENCES event ( objid )
	)
    }

    # Disable further calls.
    proc ::fx::seen::Init {} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::seen 0
return
