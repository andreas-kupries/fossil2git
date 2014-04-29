
[subsection Sqlite3]

The framework uses the [package sqlite3] package in its implementation.

[para] Out of the many possibilites for getting Sqlite3 (OS vendor,
os-independent vendor, building from sources) use whatever you are
comfortable with.

[para] For myself, I am most comfortable with using
[uri http://www.activestate.com ActiveState's]
ActiveTcl distribution and TEApot.

[para] See the previous section ([sectref Tcl]) for disclosure and
information on how to get it.

[para] Assuming that ActiveTcl got installed running the command

[example {
    teacup install sqlite3
}]

will install the package for your platform, if you have not done the
more inclusive

[example {
    teacup update
}]

to get everything and the kitchensink.

[para] For those wishing to build and install sqlite3 on their own,
the relevant sources (of a TEA-based Tcl extension) can be found at
[uri http://sqlite.org/download.html] together with the necessary
instructions on how to build it.

[para] If there are problems with building, installing, or using Sqlite3
and its packages please file a bug against Sqlite3, or the vendor of
your distribution, and not [package [vset PROJECT]].
