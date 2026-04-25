# Sovereign AI Key Verification Guide

Follow these steps to ensure your new Service Account key is working correctly with your gym-ops backend.

---

## 1. Prepare the JSON Key
Google provides the key as a multi-line JSON file. For modern web environments, we must format it as a single-line string.

1.  **Minify:** Open your new JSON key. Use a "JSON Minifier" online or just paste it into a single line.
2.  **Escape Newlines:** Ensure the `private_key` field contains actual `\n` characters (e.g., `-----BEGIN PRIVATE KEY-----\n...`).
3.  **Update .env:** In `backend/.env`, update the `GCP_SA_KEY` variable:
    ```env
    GCP_SA_KEY='{"type": "service_account", "project_id": "...", ...}'
    ```
    *Note: Wrap the entire JSON string in single quotes `'` to handle the internal double quotes.*

---

## 2. Boot Verification
Check your `npm run dev` terminal. If the key is formatted correctly, you should see:
```text
info: Sovereign AI Service Initialized {"project":"129404364493","location":"us-central1"}
```
If you see `Sovereign AI Init Failed`, your JSON string is likely malformed or missing a brace.

---

## 3. Fast-Check Endpoint (HTTP 200)
Run this command in any terminal (or open in browser) to test the "Secret Handshake" with Gemini:
```bash
curl http://localhost:5001/api/ai/test
```
**Expected Outcome:**
```json
{
  "success": true,
  "status": "Sovereign AI is ALIVE",
  "aiContent": "ALIVE"
}
```
*If this works, your key has full permissions to use Vertex AI.*

---

## 4. Live Ledger Test (End-to-End)
1.  Open the Flutter app (`http://localhost:8080`).
2.  Navigate to **AI Ledger**.
3.  Upload a photo of a handwritten attendance sheet.
4.  **Gemini** will process it. If it returns names and amounts, your production integration is 100% complete.

---

## 🚨 Troubleshooting
- **403 Forbidden:** The Service Account is missing the `Vertex AI User` role in GCP IAM.
- **404 Not Found:** The Google Project ID or Location in `.env` is incorrect.
- **Unexpected token:** There is a syntax error in your `.env` JSON string.
