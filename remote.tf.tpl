terraform {
  cloud {
    hostname     = ""
    organization = ""

    workspaces {
      name = "wfgrps:${wfgrp}:wfs:${wfs}"
    }
  }
}
