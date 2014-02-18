The state directory used by the code watching fossil repositories for ticket changes
 has the structure explained below:

- watch.sqlite3

	Configuration file. Sqlite database.
	Map from project names to recipient emails,
	and holds the information about previously seen
	ticket artifacts.

--- XXX --- not used
- watch/${project}.fossil

	File. Local copy of the fossil repository to watch for
	changes.

- tmp/${project}.watch-lock

	Lock file to prevent multiple instances of the watcher
	application from accessing the same project at the same time.
