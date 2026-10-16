resource "keycloak_openid_client" "this" {
  realm_id    = var.realm_name
  client_id   = var.name
  name        = var.display_name != null ? var.display_name : ""
  description = var.description != null ? var.description : "Managed by OpenTofu"
  enabled     = true
  access_type = var.access_type

  # The authorization code flow only. The implicit flow and passwords sent to the token
  # endpoint are off: neither is needed by a CLI with PKCE or by a web app. A device-only client
  # has no redirect URIs, and the provider refuses the authorization code flow without one
  standard_flow_enabled                     = length(var.valid_redirect_uris) > 0
  implicit_flow_enabled                     = false
  direct_access_grants_enabled              = false
  service_accounts_enabled                  = false
  oauth2_device_authorization_grant_enabled = var.oauth2_device_authorization_grant_enabled
  pkce_code_challenge_method                = var.pkce_code_challenge_method

  valid_redirect_uris             = var.valid_redirect_uris
  valid_post_logout_redirect_uris = var.valid_post_logout_redirect_uris
  web_origins                     = var.web_origins

  # "" for null: the provider leaves a value it is not given alone, so a URL set in the
  # console would stay
  root_url  = var.root_url != null ? var.root_url : ""
  base_url  = var.base_url != null ? var.base_url : ""
  admin_url = var.admin_url != null ? var.admin_url : ""

  lifecycle {
    precondition {
      condition     = length(var.valid_redirect_uris) > 0 || var.oauth2_device_authorization_grant_enabled
      error_message = "valid_redirect_uris needs at least one URI: no browser login can complete without one. Only a client with oauth2_device_authorization_grant_enabled may have none."
    }
  }
}

# Off by default: the realm at The Gathering has a default client scope "groups" that adds the
# claim to every client. Keycloak does not create that scope, so another realm needs this mapper
resource "keycloak_openid_group_membership_protocol_mapper" "this" {
  count = var.groups_claim != null ? 1 : 0

  realm_id   = var.realm_name
  client_id  = keycloak_openid_client.this.id
  name       = "groups"
  claim_name = var.groups_claim

  # The group name without its path: "admins", not "/admins". The talos module binds the
  # group <cluster_name>-cluster-admin by name
  full_path = false

  # kube-apiserver reads the groups from the ID token
  add_to_id_token            = true
  add_to_access_token        = true
  add_to_userinfo            = true
  add_to_token_introspection = true
}
