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
    namespace export not-sent mark unmark reset
    namespace ensemble create

    namespace import ::fx::fossil
}

# # ## ### ##### ######## ############# ######################

proc ::fx::seen::not-sent {script} {
    Init
    upvar type type id id uuid uuid comment comment

    fossil repository transaction {
	fossil repository eval {
	    SELECT
	    event.type  AS type,
	    event.objid AS id,
	    blob.uuid   AS uuid
	    coalesce (event.ecomment, event.comment) AS comment
	    FROM event, blob
	    WHERE event.objid NOT IN (SELECT id
				      FROM fx_aku_watch_seen)
	    AND event.objid = blob.rid
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

proc ::fx::seen::mark {id} {
    # TODO dry run

    Init
    fossil repository eval {
	INSERT INTO fx_aku_watch_seen
	VALUES ( :id )
    }
    return
}

proc ::fx::seen::unmark {uuid} {
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

proc ::fx::seen::reset {} {
    # TODO dry run
    fossil repository eval {
	DROP TABLE IF EXISTS fx_aku_watch_seen
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::seen::Init {} {
    fossil repository eval {
	CREATE TABLE IF NOT EXISTS
	fx_aku_watch_seen
	(
	 id
	   INTEGER
	   PRIMARY KEY
	   REFERENCES event ( objid )
	 )
    }

    # Disable further calls.
    proc ::fx::seen::Init {} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::seen 0
return
