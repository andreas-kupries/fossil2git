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

namespace eval ::fx::seen {
    namespace export not touch
    namespace ensemble create
}

# # ## ### ##### ######## ############# ######################

proc ::fx::seen::not {db dbloc script} {
    Init $db
    upvar type type id id manifest manifest

    set fossil [auto_execok fossil]

    $db eval {
	SELECT
	  event.type  AS type,
	  event.objid AS id,
	  blob.uuid   AS uuid
	FROM event, blob
	WHERE event.objid NOT IN (SELECT id
			    FROM fx_aku_watch_seen)
	AND event.objid = blob.rid
    } {
	set manifest [exec {*}$fossil artifact $uuid -R $dbloc]
	uplevel 1 $script
    }
    # NOTE: We are shelling out to fossil to get the artifact
    # contents. This way we avoid having to implement the entire
    # decompression (delta, inflate) ourselves. A 'libfossil' with a
    # proper C API would make this easier.
}

proc ::fx::seen::touch {db id} {
    # TODO dry run

    Init $db

    $db eval {
	INSERT INTO fx_aku_watch_seen
	VALUES ( :id )
    }
    return
}

# # ## ### ##### ######## ############# ######################

proc ::fx::seen::Init {db} {
    $db eval {
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
    proc ::fx::seen::Init {db} {}
    return
}

# # ## ### ##### ######## ############# ######################
package provide fx::seen 0
return
