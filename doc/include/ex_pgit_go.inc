[include ex_peer_go.inc]
[para]

[para] A few things to remember however:

[list_begin enumerated]
[enum] cron is notoriously fiddly with regard to the environment
       variables provided to the jobs. Make sure that:

[enum] Your [variable PATH] provides access to 
  [list_begin itemized]
  [item][syscmd fossil],
  [item][syscmd git],
  [item][syscmd awk],
  [item][syscmd sed],
  [item][syscmd ssh].
	This last is required if and only if you have git destination
	repositories which are accessed through [term ssh] urls. In
	that case you will aslo have to make sure that [syscmd ssh]
	has access to an [syscmd ssh-agent] loaded with all the
	necessary keys so that it can run without having to
	interactively ask for passwords.
  [list_end]

[enum] That a proper [variable USER] variable is set for fossil to
       pick up.
[list_end]
