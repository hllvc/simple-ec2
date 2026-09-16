# Fetches the module from this same repository over SSH, which is the whole
# point of this branch: it proves the runner can resolve a private module
# source without a VCS credential on the workflow.
module "naming" {
  source = "git::ssh://git@github.com/hllvc/simple-ec2.git//modules/naming?ref=tmp/test-ssh-module"

  prefix = "sshtest"
}
