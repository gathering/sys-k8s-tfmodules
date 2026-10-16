# The client and its groups mapper, with the provider mocked.

mock_provider "keycloak" {
  mock_resource "keycloak_openid_client" {
    defaults = {
      id            = "0b8d2c3e-1f4a-4c5b-9d6e-7f8a9b0c1d2e"
      client_secret = "mock-secret"
    }
  }
}

variables {
  realm_name          = "test"
  name                = "test-kubernetes"
  access_type         = "PUBLIC"
  valid_redirect_uris = ["http://localhost:8000", "http://localhost:18000"]
}

run "public_defaults" {
  command = apply

  assert {
    condition = alltrue([
      keycloak_openid_client.this.realm_id == "test",
      keycloak_openid_client.this.client_id == "test-kubernetes",
      keycloak_openid_client.this.access_type == "PUBLIC",
      keycloak_openid_client.this.enabled,
      keycloak_openid_client.this.description == "Managed by OpenTofu",
      keycloak_openid_client.this.name == "",
      keycloak_openid_client.this.root_url == "",
      keycloak_openid_client.this.base_url == "",
      keycloak_openid_client.this.admin_url == "",
    ])
    error_message = "A default no longer gives the expected client."
  }

  assert {
    condition = alltrue([
      keycloak_openid_client.this.standard_flow_enabled,
      !keycloak_openid_client.this.implicit_flow_enabled,
      !keycloak_openid_client.this.direct_access_grants_enabled,
      !keycloak_openid_client.this.service_accounts_enabled,
      !keycloak_openid_client.this.oauth2_device_authorization_grant_enabled,
      keycloak_openid_client.this.pkce_code_challenge_method == "S256",
    ])
    error_message = "Only the authorization code flow, with PKCE S256, must be on by default."
  }

  assert {
    condition = alltrue([
      keycloak_openid_client.this.valid_redirect_uris == toset(["http://localhost:8000", "http://localhost:18000"]),
      length(keycloak_openid_client.this.valid_post_logout_redirect_uris) == 0,
      length(keycloak_openid_client.this.web_origins) == 0,
    ])
    error_message = "The redirect URIs must reach the client, with no logout redirects or web origins by default."
  }

  assert {
    condition     = length(keycloak_openid_group_membership_protocol_mapper.this) == 0
    error_message = "No groups mapper by default: the realm's groups scope adds the claim."
  }

  assert {
    condition     = output.client_id == "test-kubernetes" && output.keycloak_id == "0b8d2c3e-1f4a-4c5b-9d6e-7f8a9b0c1d2e"
    error_message = "The outputs must give the client ID and Keycloak's ID of the client."
  }

  assert {
    condition     = output.client_secret == null
    error_message = "A public client has no secret."
  }
}

run "groups_mapper" {
  command = apply

  variables {
    groups_claim = "groups"
  }

  assert {
    condition = alltrue([
      length(keycloak_openid_group_membership_protocol_mapper.this) == 1,
      keycloak_openid_group_membership_protocol_mapper.this[0].realm_id == "test",
      keycloak_openid_group_membership_protocol_mapper.this[0].client_id == output.keycloak_id,
      keycloak_openid_group_membership_protocol_mapper.this[0].claim_name == "groups",
      !keycloak_openid_group_membership_protocol_mapper.this[0].full_path,
      keycloak_openid_group_membership_protocol_mapper.this[0].add_to_id_token,
      keycloak_openid_group_membership_protocol_mapper.this[0].add_to_access_token,
      keycloak_openid_group_membership_protocol_mapper.this[0].add_to_userinfo,
      keycloak_openid_group_membership_protocol_mapper.this[0].add_to_token_introspection,
    ])
    error_message = "The groups mapper must put the group names, without the path, in the groups claim of the ID token, the access token, userinfo and token introspection."
  }
}

run "confidential" {
  command = apply

  variables {
    name                            = "test-grafana"
    access_type                     = "CONFIDENTIAL"
    valid_redirect_uris             = ["https://grafana.example.org/login/generic_oauth"]
    valid_post_logout_redirect_uris = ["+"]
    web_origins                     = ["+"]
    display_name                    = "Grafana"
    root_url                        = "https://grafana.example.org"
    base_url                        = "/"
    admin_url                       = "https://grafana.example.org/admin"
    description                     = "Grafana"
  }

  assert {
    condition = alltrue([
      keycloak_openid_client.this.access_type == "CONFIDENTIAL",
      keycloak_openid_client.this.valid_redirect_uris == toset(["https://grafana.example.org/login/generic_oauth"]),
      keycloak_openid_client.this.valid_post_logout_redirect_uris == toset(["+"]),
      keycloak_openid_client.this.web_origins == toset(["+"]),
      keycloak_openid_client.this.name == "Grafana",
      keycloak_openid_client.this.root_url == "https://grafana.example.org",
      keycloak_openid_client.this.base_url == "/",
      keycloak_openid_client.this.admin_url == "https://grafana.example.org/admin",
      keycloak_openid_client.this.description == "Grafana",
    ])
    error_message = "The inputs of a web app must reach the client as given."
  }

  assert {
    condition = alltrue([
      keycloak_openid_client.this.standard_flow_enabled,
      !keycloak_openid_client.this.implicit_flow_enabled,
      !keycloak_openid_client.this.direct_access_grants_enabled,
      !keycloak_openid_client.this.service_accounts_enabled,
      keycloak_openid_client.this.pkce_code_challenge_method == "S256",
    ])
    error_message = "A confidential client must get the same flows and PKCE as a public one."
  }

  assert {
    condition     = output.client_secret == "mock-secret"
    error_message = "A confidential client must output the secret Keycloak generated."
  }
}

run "device_grant_and_no_pkce" {
  command = plan

  variables {
    oauth2_device_authorization_grant_enabled = true
    pkce_code_challenge_method                = ""
  }

  assert {
    condition     = keycloak_openid_client.this.oauth2_device_authorization_grant_enabled && keycloak_openid_client.this.pkce_code_challenge_method == ""
    error_message = "The device grant and PKCE must follow their inputs."
  }
}

run "other_groups_claim" {
  command = plan

  variables {
    groups_claim = "roles"
  }

  assert {
    condition     = keycloak_openid_group_membership_protocol_mapper.this[0].claim_name == "roles"
    error_message = "The groups mapper must use the given claim."
  }
}

run "null_gives_the_default" {
  command = plan

  variables {
    valid_post_logout_redirect_uris           = null
    web_origins                               = null
    pkce_code_challenge_method                = null
    oauth2_device_authorization_grant_enabled = null
  }

  assert {
    condition = alltrue([
      keycloak_openid_client.this.pkce_code_challenge_method == "S256",
      !keycloak_openid_client.this.oauth2_device_authorization_grant_enabled,
      length(keycloak_openid_client.this.web_origins) == 0,
    ])
    error_message = "A null input must give the module default."
  }
}

run "display_name_without_description" {
  command = plan

  variables {
    display_name = "Kubernetes API"
  }

  assert {
    condition     = keycloak_openid_client.this.name == "Kubernetes API" && keycloak_openid_client.this.description == "Managed by OpenTofu"
    error_message = "A display name must not change the default description."
  }
}

run "empty_description_is_kept" {
  command = plan

  variables {
    description = ""
  }

  assert {
    condition     = keycloak_openid_client.this.description == ""
    error_message = "description = \"\" must clear the description, not give the default."
  }
}

# A device-only client needs no redirect URI
run "device_only" {
  command = plan

  variables {
    valid_redirect_uris                       = []
    oauth2_device_authorization_grant_enabled = true
    pkce_code_challenge_method                = ""
  }

  assert {
    condition     = length(keycloak_openid_client.this.valid_redirect_uris) == 0 && !keycloak_openid_client.this.standard_flow_enabled && keycloak_openid_client.this.oauth2_device_authorization_grant_enabled
    error_message = "A client without redirect URIs must have the device grant only: the provider refuses the authorization code flow without a redirect URI."
  }
}

run "redirect_uris_required_for_browser_login" {
  command = plan

  variables {
    valid_redirect_uris = []
  }

  expect_failures = [
    keycloak_openid_client.this,
  ]
}

run "invalid_inputs" {
  command = plan

  variables {
    realm_name                 = ""
    name                       = ""
    access_type                = "BEARER-ONLY"
    valid_redirect_uris        = ["http://localhost:8000", ""]
    pkce_code_challenge_method = "S512"
    groups_claim               = ""
  }

  expect_failures = [
    var.realm_name,
    var.name,
    var.access_type,
    var.valid_redirect_uris,
    var.pkce_code_challenge_method,
    var.groups_claim,
  ]
}
