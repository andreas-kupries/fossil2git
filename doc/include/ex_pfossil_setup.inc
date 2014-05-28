The main point in setting up the mirroring to other fossil
repositories of the same project is to tell the local repository
(file) where the mirrors are, and what to do with them, i.e. do we
push, pull or sync data, and what areas do we exchange with them.

[para] A few examples:

[example {
	fx peer add push content http://foo
	# push regular (non-configuration) data to the peer given by the url.
	# IOW commits, tickets, wiki pages, etc.

	fx peer add pull skin http://foo
	# push the configuration area 'skin' from the peer

	fx peer add sync email http://foo
	# synchronize the configuration area 'email' with the peer.
}]

[para] Many peers are possible, each with a different set of areas to
exchange and per-area directions.
