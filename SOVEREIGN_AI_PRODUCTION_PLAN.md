# Production Readiness & Security Hardening Plan

This document outlines the transition from local/development AI extraction to a production-grade, identity-sovereign AI service.

---

## 🔒 1. Immediate Security Remediation (Key Rotation)
To prevent compromise from any keys exposed during development, follow these steps immediately:

1.  **Revoke Service Account Keys:** Go to [GCP Console > IAM & Admin > Service Accounts](https://console.cloud.google.com/iam-admin/serviceaccounts).
    *   Locate `gym-ops@fitnearn-devops.iam.gserviceaccount.com`.
    *   Delete the key with ID ending in `dbc9d25d078` (or any keys created today).
2.  **Generate a Production Key:** Create a new JSON key.
3.  **Rotate .env:** Update the `GCP_SA_KEY` in your production environment.
    *   **Pro Tip:** In production (GCP/AWS/Heroku), DO NOT use a `.env` file. Use the platform's native Secret Management tool.

---

## 🛠️ 2. Backend Hardening (aiService.js)
The current implementation is functional but needs "Production Polish":

- [ ] **Remove Hardcoded IDs:** Replace `129404364493` with `process.env.GCP_PROJECT_NUMBER`.
- [ ] **Structured Logging:** Remove `console.log` statements that output partial image headers or sensitive tokens. Use a library like `winston` or `pino`.
- [ ] **Request Limiting:** Implement rate limiting specifically for the `/ai/scan-book` route to prevent API bill spikes from malicious use.
- [ ] **Image Validation:** Add a middleware to check file size (max 5MB) and MIME type *before* the request hits the AI logic.

---

## 🌐 3. Infrastructure & IAM (Vertex AI)
Ensure the "Sovereign" identity has the minimum permissions needed (Principle of Least Privilege):

1.  **IAM Role:** Ensure the Service Account has **ONLY** the `Vertex AI User` role. Avoid `Editor` or `Owner`.
2.  **Quotas:** Set a daily spend alert in the Google Cloud Billing console to prevent unexpected AI costs.
3.  **CORS:** In your backend `app.js`, ensure the `cors` middleware is restricted to your production domain (e.g., `https://admin.fitnearn.com`) instead of `*`.

---

## 📱 4. Flutter Integration
- [ ] **Environment Switching:** Ensure Flutter points to `https://api.fitnearn.com` in production instead of `localhost`.
- [ ] **Secure Storage:** If any AI results are cached on the phone, use `flutter_secure_storage`.

---

## 🚀 5. Deployment Workflow
1.  **CI/CD:** Add a step in your pipeline to verify that no `.env` files are accidentally committed to GitHub.
2.  **Health Checks:** Use the `GET /api/ai/test` route we created as a "Readiness Probe" in your load balancer to ensure AI connectivity before the app goes live.

---

> [!IMPORTANT]
> **COMPROMISE CHECKLIST:**
> - [ ] Has `.env` been added to `.gitignore`?
> - [ ] Are all `.js` files in `tmp/` deleted?
> - [ ] Is the Service Account restricted to a single project?
> - [ ] Have you enabled Multi-Factor Authentication (MFA) on the GCP Owner account?
