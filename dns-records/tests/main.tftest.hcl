# The record sets and their names, with the provider mocked.

mock_provider "poweradmin" {
  mock_data "poweradmin_zone" {
    defaults = {
      id = "42"
    }
  }
}

variables {
  zone_name = "gathering.systems"
  records_by_key = {
    api = {
      name   = "api.k8s.gathering.systems"
      values = ["2001:db8:ffff::10"]
    }
  }
}

run "defaults" {
  command = apply

  assert {
    condition     = data.poweradmin_zone.this.name == "gathering.systems"
    error_message = "The zone must be looked up by zone_name."
  }

  assert {
    condition = alltrue([
      poweradmin_rrset.this["api"].zone_id == 42,
      poweradmin_rrset.this["api"].name == "api.k8s",
      poweradmin_rrset.this["api"].type == "AAAA",
      poweradmin_rrset.this["api"].ttl == 300,
      poweradmin_rrset.this["api"].records == toset([{ content = "2001:db8:ffff::10", disabled = false, priority = 0 }]),
    ])
    error_message = "A record with the defaults must be an AAAA record set with TTL 300, named relative to the zone."
  }

  assert {
    condition = alltrue([
      output.zone_id == 42,
      output.records_by_key["api"].name == "api.k8s.gathering.systems",
      output.records_by_key["api"].type == "AAAA",
      output.records_by_key["api"].ttl == 300,
      output.records_by_key["api"].values == tolist(["2001:db8:ffff::10"]),
    ])
    error_message = "An output no longer carries the value its name says."
  }
}

run "names_are_normalized" {
  command = plan

  variables {
    zone_name = "Gathering.Systems."
    records_by_key = {
      apex     = { name = "gathering.systems.", values = ["2001:db8::1"] }
      node     = { name = "K8S-CP-A.gathering.systems", values = ["2001:db8::2"] }
      wildcard = { name = "*.apps.gathering.systems", values = ["2001:db8::3"] }
    }
  }

  assert {
    condition = alltrue([
      data.poweradmin_zone.this.name == "gathering.systems",
      poweradmin_rrset.this["apex"].name == "@",
      poweradmin_rrset.this["node"].name == "k8s-cp-a",
      poweradmin_rrset.this["wildcard"].name == "*.apps",
      output.records_by_key["node"].name == "k8s-cp-a.gathering.systems",
    ])
    error_message = "Names must be lower case and relative to the zone, @ for the zone itself, with or without trailing dots."
  }
}

run "several_values_and_types" {
  command = plan

  variables {
    ttl = 600
    records_by_key = {
      ingress = {
        name   = "ingress.k8s.gathering.systems"
        ttl    = 60
        values = ["2001:db8:0:1::10", "2001:DB8:0:1:0:0:0:11"]
      }
      grafana = {
        name   = "grafana.gathering.systems"
        type   = "cname"
        values = ["ingress.k8s.gathering.systems."]
      }
    }
  }

  assert {
    condition = alltrue([
      poweradmin_rrset.this["ingress"].ttl == 60,
      poweradmin_rrset.this["ingress"].records == toset([
        { content = "2001:db8:0:1::10", disabled = false, priority = 0 },
        { content = "2001:db8:0:1::11", disabled = false, priority = 0 },
      ]),
    ])
    error_message = "A record set must get every value, AAAA values in canonical form, and its own TTL."
  }

  assert {
    condition = alltrue([
      poweradmin_rrset.this["grafana"].type == "CNAME",
      poweradmin_rrset.this["grafana"].ttl == 600,
      poweradmin_rrset.this["grafana"].records == toset([{ content = "ingress.k8s.gathering.systems.", disabled = false, priority = 0 }]),
    ])
    error_message = "Another type must be upper case, keep its values as given and get the module TTL."
  }
}

run "no_records" {
  command = plan

  variables {
    records_by_key = {}
  }

  assert {
    condition     = length(poweradmin_rrset.this) == 0 && length(output.records_by_key) == 0
    error_message = "No records must create no record sets."
  }
}

run "name_outside_the_zone" {
  command = plan

  variables {
    records_by_key = {
      other = { name = "api.example.org", values = ["2001:db8::1"] }
      # Ends in the zone name, but is not inside the zone
      lookalike = { name = "notgathering.systems", values = ["2001:db8::2"] }
    }
  }

  expect_failures = [
    poweradmin_rrset.this,
  ]
}

run "same_name_and_type_twice" {
  command = plan

  variables {
    records_by_key = {
      a = { name = "api.gathering.systems", values = ["2001:db8::1"] }
      b = { name = "API.gathering.systems.", values = ["2001:db8::2"] }
    }
  }

  expect_failures = [
    poweradmin_rrset.this,
  ]
}

run "invalid_inputs" {
  command = plan

  variables {
    zone_name = "not a zone"
    ttl       = 0
    records_by_key = {
      bad_name  = { name = "not a name", values = ["2001:db8::1"] }
      bad_type  = { name = "a.gathering.systems", type = "", values = ["x"] }
      bad_ttl   = { name = "b.gathering.systems", ttl = 0, values = ["2001:db8::1"] }
      no_values = { name = "c.gathering.systems", values = [] }
      ipv4      = { name = "d.gathering.systems", values = ["192.0.2.1"] }
      prefix    = { name = "e.gathering.systems", values = ["2001:db8::1/64"] }
    }
  }

  expect_failures = [
    var.zone_name,
    var.ttl,
    var.records_by_key,
  ]
}
