variable "realm_name" {
  description = "Keycloak realm the client is created in. The realm must exist"
  type        = string
  nullable    = false

  validation {
    condition     = var.realm_name != ""
    error_message = "realm_name must not be empty."
  }
}

variable "name" {
  description = "Client ID: the `client_id` an application logs in with, and `oidc.client_id` of the talos module for the Kubernetes API"
  type        = string
  nullable    = false

  validation {
    condition     = var.name != ""
    error_message = "name must not be empty."
  }
}

variable "access_type" {
  description = "`PUBLIC` for a client that cannot keep a secret, such as kubectl with kubelogin. `CONFIDENTIAL` for a web app that logs in with the `client_secret` output"
  type        = string
  nullable    = false

  validation {
    condition     = contains(["PUBLIC", "CONFIDENTIAL"], var.access_type)
    error_message = "access_type must be PUBLIC or CONFIDENTIAL."
  }
}

variable "valid_redirect_uris" {
  description = "URIs Keycloak may redirect to after a login. kubelogin listens on `http://localhost:8000` and `http://localhost:18000`. Keycloak matches `http://localhost/<path>` on any port, for a CLI that picks a free one. A `*` matches any path: list exact URIs instead. Only a client with `oauth2_device_authorization_grant_enabled` may have none: it then has the device grant only"
  type        = list(string)
  nullable    = false

  validation {
    condition     = alltrue([for uri in var.valid_redirect_uris : uri != null && uri != ""])
    error_message = "valid_redirect_uris must not have an empty entry."
  }
}

variable "valid_post_logout_redirect_uris" {
  description = "URIs Keycloak may redirect to after a logout. `+` allows the redirect URIs"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "web_origins" {
  description = "Origins allowed to call Keycloak from a browser (CORS). `+` allows the origins of the redirect URIs. Not needed by a CLI or a server-side web app"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "display_name" {
  description = "Name of the client shown to users, on the login page and in the account console. Null shows the client ID"
  type        = string
  default     = null
}

variable "root_url" {
  description = "Root URL of the application. Relative URLs of the client, such as `base_url` and the redirect URIs, are resolved against it. Null clears it"
  type        = string
  default     = null
}

variable "base_url" {
  description = "URL Keycloak links to the application with, from the account console. Relative to `root_url` when it starts with `/`. Null clears it"
  type        = string
  default     = null
}

variable "admin_url" {
  description = "URL Keycloak sends admin requests to the application on, such as a logout of all sessions. Few applications take them. Null clears it"
  type        = string
  default     = null
}

variable "description" {
  description = "Client description: say what the client is for. Defaults to `Managed by OpenTofu`"
  type        = string
  default     = null
}

variable "pkce_code_challenge_method" {
  description = "PKCE method the client must use: `S256`, `plain`, or `\"\"` for no PKCE. Keycloak refuses a login without it when set. kubelogin, Grafana and Argo CD can all do S256"
  type        = string
  default     = "S256"
  nullable    = false

  validation {
    condition     = contains(["", "S256", "plain"], var.pkce_code_challenge_method)
    error_message = "pkce_code_challenge_method must be S256, plain or \"\"."
  }
}

variable "oauth2_device_authorization_grant_enabled" {
  description = "Allow the device authorization grant, for a login on a machine without a browser. Keycloak requires PKCE on the device request too, and kubelogin sends none there: for `kubelogin --grant-type=device-code`, set `pkce_code_challenge_method = \"\"`, best on a client of its own so that browser logins keep PKCE"
  type        = bool
  default     = false
  nullable    = false
}

variable "groups_claim" {
  description = "Adds a mapper to the client that puts the user's groups in this claim, by name without the path, in the ID token, the access token, userinfo and token introspection. Null, the default, adds none: the realm at The Gathering has a default client scope `groups` that adds the claim to every client. Keycloak does not create that scope: a realm without it needs `\"groups\"` here"
  type        = string
  default     = null

  validation {
    condition     = var.groups_claim != ""
    error_message = "groups_claim must not be empty. Set it to null to add no mapper."
  }
}
