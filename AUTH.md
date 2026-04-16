# GymOps Authentication — Technical Reference

## How It Works (Web)

Flutter opens Cognito in a popup via `html.window.open`. User authenticates
with Google. Cognito redirects the popup to `localhost:8080/auth/callback`.
`web/index.html` detects the `/auth/callback` path and redirects to
`callback.html`. `callback.html` reads the auth code and sends it to the
parent window via `postMessage`. Flutter's `onMessage` listener receives
the code, exchanges it for tokens via Cognito's `/oauth2/token` endpoint.
Popup closes. Main tab stays alive throughout — no page reload.

## User Flows

| User Type | Flow |
|-----------|------|
| New user | LoginScreen → Google → OnboardingScreen → HomeScreen |
| Returning user | LoginScreen → Google → HomeScreen |
| Session expired | LoginScreen → Google → HomeScreen |

## Registered Callback URLs

| Platform | URL |
|----------|-----|
| Web | `http://localhost:8080/auth/callback` |
| Android | `myapp://callback` |
| Cognito → GCP | `https://ap-south-1fujnjpibc.auth.ap-south-1.amazoncognito.com/oauth2/idpresponse` |

## AWS Cognito Settings

- OAuth scopes: `email`, `openid`, `profile`
- OAuth grant type: Authorization code grant with PKCE
- Identity provider: Google (federated)
- App client: has client secret (required for web token exchange)

## GCP OAuth Client

Authorized redirect URIs must include:
- `https://ap-south-1fujnjpibc.auth.ap-south-1.amazoncognito.com/oauth2/idpresponse`
- `http://localhost:8080/auth/callback`

## Key Files

| File | Purpose |
|------|---------|
| `lib/services/auth_service.dart` | Full OAuth flow, PKCE, token exchange |
| `lib/services/route_guard.dart` | Decides LoginScreen / OnboardingScreen / HomeScreen |
| `web/callback.html` | Receives Cognito redirect, posts code to Flutter |
| `web/index.html` | Intercepts `/auth/callback` path, routes to callback.html |
| `lib/config/api_config.dart` | Cognito domain, client ID, redirect URIs |

## Known Bug Fixed

`_exchangeCodeForToken` was ignoring its `redirectUri` parameter and always
sending `ApiConfig.redirectUri` in the POST body. Fixed by using
`effectiveRedirectUri` instead. This was causing `invalid_grant` errors on
repeated sign-in attempts.

## Production Checklist

- [ ] Deploy backend to real server (Railway / Render / EC2)
- [ ] Update `ApiConfig.baseUrl` for production
- [ ] Add production callback URL to Cognito app client
- [ ] Add production callback URL to GCP OAuth client
- [ ] Replace `myapp://` scheme with your real app package name
- [ ] Set up proper domain for Cognito hosted UI
