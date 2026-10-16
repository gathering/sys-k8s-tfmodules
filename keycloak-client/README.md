# Keycloak Client

One OpenID Connect client in an existing Keycloak realm: `PUBLIC` for a CLI or a single-page app, or `CONFIDENTIAL` for a web app with a server side. Call the module once per client.

The client has the authorization code flow only, with PKCE S256 by default. The implicit flow, direct access grants (passwords sent to the token endpoint) and service accounts are off. The device authorization grant can be turned on with `oauth2_device_authorization_grant_enabled`.

The module owns every setting it has an input for: the display name and the URLs are cleared when their input is null, also when they were set in the Keycloak console. Settings it has no input for, such as the client scopes, are left to the realm defaults.

## Groups

The realm at The Gathering has a default client scope `groups` that adds the user's groups to the tokens of every client, so the module adds no mapper of its own by default. Keycloak does not create that scope: in a realm without it, a client gets no `groups` claim, kube-apiserver sees no groups and the cluster-admin binding of the talos module never matches. Set `groups_claim = "groups"` there, or another claim name: the mapper puts the group names in the ID token, the access token, userinfo and token introspection. With the scope there as well, a mapper for the same claim changes nothing.

Either way the names must come without the path (`admins`, not `/admins`) for the binding of `<cluster_name>-cluster-admin` to match: the module's mapper does that, and the mapper of the realm's scope must have *Full group path* off.

## Prerequisites

- The realm named by `realm_name` must exist.
- The `keycloak` provider needs a client of its own that may manage the clients of that realm. See below.

## A client for OpenTofu

OpenTofu logs in to Keycloak with a confidential client that has a service account and nothing else. Create it once, by hand, in the realm whose clients it manages: a client in `master` could manage every realm.

In the admin console of the realm:

1. *Clients* > *Create client*. Client type *OpenID Connect*, client ID `opentofu`. Next.
2. *Client authentication* on. Under *Authentication flow*, tick *Service account roles* only: turn off *Standard flow* and *Direct access grants*. Next, then Save.
3. Tab *Service accounts roles* > *Assign role* > *Client roles*. Pick `manage-clients` of `realm-management`, and nothing else. It lets the client create, change and delete the clients of the realm and their mappers, and nothing outside clients.
4. Tab *Credentials*: copy the client secret.

Or with `kcadm.sh`, logged in as an admin:

```sh
kcadm.sh create clients -r my-realm -s clientId=opentofu -s publicClient=false \
  -s serviceAccountsEnabled=true -s standardFlowEnabled=false -s directAccessGrantsEnabled=false
kcadm.sh add-roles -r my-realm --uusername service-account-opentofu \
  --cclientid realm-management --rolename manage-clients
kcadm.sh get clients -r my-realm -q clientId=opentofu --fields id   # then:
kcadm.sh get clients/<id>/client-secret -r my-realm
```

The provider takes the rest from the environment. The root module only needs `provider "keycloak" {}`:

```sh
export KEYCLOAK_URL=https://sso.example.org   # without /realms/...
export KEYCLOAK_REALM=my-realm                # the realm the opentofu client is in
export KEYCLOAK_CLIENT_ID=opentofu
export KEYCLOAK_CLIENT_SECRET=...
```

With a client ID and secret and no username, the provider logs in with the client credentials grant. The `opentofu` client can then manage the clients of `my-realm` only, so `realm_name` of every module call must be that realm. Without `manage-clients`, the plan fails at once with `error initializing keycloak provider`.

The provider asks Keycloak for its version. If it ever fails to, on a later Keycloak that restricts `/admin/serverinfo`, set `KEYCLOAK_VERSION` to the version that runs (`keycloak_version` in the provider block) rather than give the client more roles.

Treat the secret like an admin password: whoever has it can change the redirect URIs of every client in the realm. Keep it in the secret store of the pipeline, and regenerate it on the *Credentials* tab if it leaks.

Tested on Keycloak 26.4 with provider 5.10: a client with `manage-clients` only creates, imports and updates clients and their mappers, without `KEYCLOAK_VERSION`.

## Usage

The client of the Kubernetes API, for kubelogin:

```hcl
module "kubernetes_client" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//keycloak-client?ref=v0.6.0"

  realm_name          = "my-realm"
  name                = "my-cluster-cli"
  display_name        = "my-cluster - Kubernetes API"
  access_type         = "PUBLIC"
  valid_redirect_uris = ["http://localhost:8000", "http://localhost:18000"]
}

module "controlplane" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//talos?ref=v0.6.0"

  oidc = {
    issuer_url = "https://sso.example.org/realms/my-realm"
    client_id  = module.kubernetes_client.client_id
    # Clients whose tokens are passed on to the API server, such as a dashboard
    audiences = [module.headlamp_client.client_id]
  }
  # ...
}
```

The ID token's audience is the client ID, which kube-apiserver checks against `oidc.client_id` and `oidc.audiences`. With the groups claim and the `oidc:` prefix of the talos module, members of the Keycloak group `<cluster_name>-cluster-admin` are cluster admin.

kubelogin listens on `http://localhost:8000`, and on `http://localhost:18000` when that port is taken. To log in from a machine without a browser, add `urn:ietf:wg:oauth:2.0:oob` for `--grant-type=authcode-keyboard`.

`--grant-type=device-code` needs a client with PKCE off: Keycloak requires the client's PKCE method on the device request as well, and kubelogin sends no PKCE there, so the login fails with `Missing parameter: code_challenge_method`. Give it a client of its own, so that browser logins keep PKCE:

```hcl
module "kubernetes_device_client" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//keycloak-client?ref=v0.6.0"

  realm_name                                = "my-realm"
  name                                      = "my-cluster-device"
  display_name                              = "my-cluster - Kubernetes API (device login)"
  access_type                               = "PUBLIC"
  valid_redirect_uris                       = []
  oauth2_device_authorization_grant_enabled = true
  pkce_code_challenge_method                = ""
}
```

Without redirect URIs the client has the device grant only. Its client ID then goes in `oidc.audiences` of the talos module.

Keycloak matches a redirect URI of `http://localhost/<path>` on any port, for a CLI that picks a free port. Do not use `*` in redirect URIs or web origins: list the exact URIs.

A web app:

```hcl
module "grafana_client" {
  source = "git::https://github.com/gathering/sys-k8s-tfmodules.git//keycloak-client?ref=v0.6.0"

  realm_name          = "my-realm"
  name                = "my-cluster-grafana"
  display_name        = "my-cluster - Grafana"
  access_type         = "CONFIDENTIAL"
  root_url            = "https://grafana.example.org"
  base_url            = "/"
  valid_redirect_uris = ["https://grafana.example.org/login/generic_oauth"]
}
```

Keycloak generates the secret of a `CONFIDENTIAL` client. The `client_secret` output gives it, and it is stored in the state in plain text like every other secret there.

PKCE is on by default, and Keycloak then refuses a login without it. Turn it on in the application before the client is created or imported, such as `use_pkce = true` in the `generic_oauth` section of Grafana, or set `pkce_code_challenge_method = ""`.

## Importing a client

An existing client is imported by the realm and Keycloak's ID of the client (the UUID in the console URL, not the client ID). The secret is kept:

```hcl
import {
  to = module.grafana_client.keycloak_openid_client.this
  id = "my-realm/b3cfedc9-ff74-430a-b3f8-09a0a35cdbe3"
}
```

The first plan shows the client changed in place: settings that differ from the module call, the description `Managed by OpenTofu` when none is given, and `use_refresh_tokens` going from `false` to `true` on a client whose JSON never had it set, which is what Keycloak did already. Every plan that updates the client also shows `client_secret_wo` as a write-only attribute; the module does not set it, and the secret does not change. A plan that replaces the client would make a new secret: stop and check the import ID.

Settings without an input keep the value they had, so an imported client can differ from one the module created: an imported client keeps front-channel logout on and its login theme, while the provider creates new clients with front-channel logout off.

## Tests

`tofu test` in this directory runs the tests in [`tests`](./tests) with the provider mocked, so no credentials are needed.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8 |
| <a name="requirement_keycloak"></a> [keycloak](#requirement\_keycloak) | ~> 5.10 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_keycloak"></a> [keycloak](#provider\_keycloak) | ~> 5.10 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [keycloak_openid_client.this](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs/resources/openid_client) | resource |
| [keycloak_openid_group_membership_protocol_mapper.this](https://registry.terraform.io/providers/keycloak/keycloak/latest/docs/resources/openid_group_membership_protocol_mapper) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_access_type"></a> [access\_type](#input\_access\_type) | `PUBLIC` for a client that cannot keep a secret, such as kubectl with kubelogin. `CONFIDENTIAL` for a web app that logs in with the `client_secret` output | `string` | n/a | yes |
| <a name="input_admin_url"></a> [admin\_url](#input\_admin\_url) | URL Keycloak sends admin requests to the application on, such as a logout of all sessions. Few applications take them. Null clears it | `string` | `null` | no |
| <a name="input_base_url"></a> [base\_url](#input\_base\_url) | URL Keycloak links to the application with, from the account console. Relative to `root_url` when it starts with `/`. Null clears it | `string` | `null` | no |
| <a name="input_description"></a> [description](#input\_description) | Client description: say what the client is for. Defaults to `Managed by OpenTofu` | `string` | `null` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | Name of the client shown to users, on the login page and in the account console. Null shows the client ID | `string` | `null` | no |
| <a name="input_groups_claim"></a> [groups\_claim](#input\_groups\_claim) | Adds a mapper to the client that puts the user's groups in this claim, by name without the path, in the ID token, the access token, userinfo and token introspection. Null, the default, adds none: the realm at The Gathering has a default client scope `groups` that adds the claim to every client. Keycloak does not create that scope: a realm without it needs `"groups"` here | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Client ID: the `client_id` an application logs in with, and `oidc.client_id` of the talos module for the Kubernetes API | `string` | n/a | yes |
| <a name="input_oauth2_device_authorization_grant_enabled"></a> [oauth2\_device\_authorization\_grant\_enabled](#input\_oauth2\_device\_authorization\_grant\_enabled) | Allow the device authorization grant, for a login on a machine without a browser. Keycloak requires PKCE on the device request too, and kubelogin sends none there: for `kubelogin --grant-type=device-code`, set `pkce_code_challenge_method = ""`, best on a client of its own so that browser logins keep PKCE | `bool` | `false` | no |
| <a name="input_pkce_code_challenge_method"></a> [pkce\_code\_challenge\_method](#input\_pkce\_code\_challenge\_method) | PKCE method the client must use: `S256`, `plain`, or `""` for no PKCE. Keycloak refuses a login without it when set. kubelogin, Grafana and Argo CD can all do S256 | `string` | `"S256"` | no |
| <a name="input_realm_name"></a> [realm\_name](#input\_realm\_name) | Keycloak realm the client is created in. The realm must exist | `string` | n/a | yes |
| <a name="input_root_url"></a> [root\_url](#input\_root\_url) | Root URL of the application. Relative URLs of the client, such as `base_url` and the redirect URIs, are resolved against it. Null clears it | `string` | `null` | no |
| <a name="input_valid_post_logout_redirect_uris"></a> [valid\_post\_logout\_redirect\_uris](#input\_valid\_post\_logout\_redirect\_uris) | URIs Keycloak may redirect to after a logout. `+` allows the redirect URIs | `list(string)` | `[]` | no |
| <a name="input_valid_redirect_uris"></a> [valid\_redirect\_uris](#input\_valid\_redirect\_uris) | URIs Keycloak may redirect to after a login. kubelogin listens on `http://localhost:8000` and `http://localhost:18000`. Keycloak matches `http://localhost/<path>` on any port, for a CLI that picks a free one. A `*` matches any path: list exact URIs instead. Only a client with `oauth2_device_authorization_grant_enabled` may have none: it then has the device grant only | `list(string)` | n/a | yes |
| <a name="input_web_origins"></a> [web\_origins](#input\_web\_origins) | Origins allowed to call Keycloak from a browser (CORS). `+` allows the origins of the redirect URIs. Not needed by a CLI or a server-side web app | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_client_id"></a> [client\_id](#output\_client\_id) | Client ID the application logs in with |
| <a name="output_client_secret"></a> [client\_secret](#output\_client\_secret) | Client secret of a `CONFIDENTIAL` client, generated by Keycloak. Null for a `PUBLIC` client |
| <a name="output_keycloak_id"></a> [keycloak\_id](#output\_keycloak\_id) | Keycloak's internal ID of the client, for resources that attach to it, such as more protocol mappers |
<!-- END_TF_DOCS -->
