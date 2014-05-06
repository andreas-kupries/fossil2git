
The key to the solution demonstrated here is to transform the case
from remote access to local access.

At that point most of [term [vset T_EX_TKT_LOCAL]] can be applied,
with some modifications which ensure that all relevant pieces of the
local repository are kept up to date.

[para] First choose a directory D to work in, then create a local
clone C of the project repository R in D.

[para] As we are not a superuser we cannot get the configuration areas required
for dynamic routing (see section [sectref Routing]).

[para] As the last steps make a backup copy of the clone. It is always
a good idea to have a backup.

[para] Here it means that problems in the coming section only require
copying the backup back into place instead of having to perform
another (expensive) clone operation over the network.

All of the above in a generalized example:

[example {
    cd /the/chosen/directory
    USER=your-account
    PASS=your-password
    REMOTE="http://${USER}:${PASS}@remote-host/path/to/project"

    fossil clone $REMOTE source.fossil

    cp source.fossil source.fossil.bak
}]
