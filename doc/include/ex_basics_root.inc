
The key to the solution demonstrated here is to transform the case
from remote access to local access.

At that point most of [term [vset T_EX_TKT_LOCAL]] can be applied,
with some modifications which ensure that all relevant pieces of the
local repository are kept up to date.

[para] First choose a directory D to work in, then create a local
clone C of the project repository R in D.

[para] Then pull the configuration areas [term user], [term email] and
[term ticket] into the clone. As a superuser it can be made simpler by
using the area [term all]. This actually makes general sense, as your
local clone now is a proper full backup of the hosted repository, in
both content and configuration.

[para] Note however that during monitoring getting the entire
configuration can take much longer than just what is then needed.

[para] Going forward it is now necessary to [term rebuild] the local
repository. Because:

[list_begin itemized]
[item]	As a basic clone it started out with the standard setup
	for the ticketing system.
[item]	While pulling the [term ticket] area has updated the local
	configuration, it has [emph not] updated the derived tables,
	i.e. TICKET and TICKETCHNG.
[item]	The rebuild takes care of that.
[list_end]

[para] As the last steps make backup copies and exports of
configuration and clone. It is always a good idea to have a backup.

[para] Here it means that problems in the coming section only require
copying the backup back into place instead of having to perform
another (expensive) clone operation over the network.

All of the above in a generalized example:

[example {
    cd /the/chosen/directory
    USER=your-superuser-account
    PASS=your-superuser-password
    REMOTE="http://${USER}:${PASS}@remote-host/path/to/project"

    fossil clone           $REMOTE    source.fossil
    fossil config pull all $REMOTE -R source.fossil

    fossil rebuild                         -R source.fossil
    fossil config export all source.config -R source.fossil

    cp source.fossil source.fossil.bak
}]
