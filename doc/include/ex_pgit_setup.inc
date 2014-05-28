Exporting to git repositories (the only thing we can currently do with
[vset PROJECT]) is nearly as easy to do as setting up a fossil mirror.

[para] Simply run something like:

[example {
	fx peer add-git git@github.com:${user}/${repository}.git
}]

with suitable settings for [var user] and [var repository]. Assuming
that your mirror is on github. To suit other hosting service change
the reference per their instructions.

[para] For multiple git mirrors simply add each separately.

[para] The one non-obvious difference to mirroring to other fossil
repositories is the need for a [term state] directory.

This directory holds a local git repository which is a copy of the
fossil repository in question. New commits found in fossil are first
imported into this copy, and then pushed out from there to the actual
git mirrors.

[para] Hopefully the above makes it clear that we have only one state
directory for the fossil repository, regardless of the number of git
mirrors.  This directory is further only created and initalized if we
have git mirrors at all.

[para] Assuming that the local fossil repository is found at
[list_begin itemized]
[item] [file /path/to/repository/file]
[list_end]

the default location of the state directory is

[list_begin itemized]
[item] [file /path/to/repository/file.peer-state]
[list_end]

I.e. the path of the directory is derived from the repository file by
appending the suffix [file .peer-state].

[para] If that location is not suitable for some reason it is possible
to explicitly set its location to a path of the user choice, using the
command

[example {
	fx peer state /path/to/the/chosen/state/directory
}]

[para] Similary
[example {
	fx peer state
}]
will print the path of the state directory used by the fossil
repository we are working with.

[para][emph ATTENTION]: It is very bad to point multiple fossil
repositories to the same state directory. The files and directories in
the state directory have fixed names, causing the fossil repositories
to fight over they contents. They do not share. Do not do this.
