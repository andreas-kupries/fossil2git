The state directory used by the code mirroring fossil to git(hub)
repositories has the structure explained below:

- track

	Configuration file. Contains a Tcl dictionary mapping from
	project names to a list of associated git repositories (urls).

- in/${project}.fossil

	File. Local copy of the fossil repository to mirror.

- out/${project}/

	Directory. Local checkout of the fossil repository to mirror,
	also the local copy of the git repository to mirror into.

- out/${project}/fossil-import-id

	File. The hash of the last fossil revision seen and mirrored
	to the remotes of the project.

- tmp/${user}.${pid}.${now}.${project}

	Temporary bare git directory/repository to export the fossil
	repository into. From there new changes get pushed into the
	local git repository before distribution to the remotes.

- tmp/${project}.lock

	Lock file to prevent multiple instances of the mirroring
	application from accessing the same project at the same time.
