# Sovereign AI Technical Specification (v3 - @google/genai)

This artifact defines the final production infrastructure for the AI extraction service using the **Unified Google Gen AI SDK**.

---

## 🏗️ 1. Google Cloud IAM Configuration
The service account must have the following properties:

### A. Role Assignment
- **Role:** `Vertex AI User`
- **Scope:** `https://www.googleapis.com/auth/cloud-platform`

### B. Required APIs
- [Vertex AI API](https://console.cloud.google.com/apis/library/aiplatform.googleapis.com)

---

## 📜 2. Environment Variable Schema
We use **Base64** for the Service Account key to ensure seamless parsing across all Node.js environments.

| Variable | Example Value | Description |
| :--- | :--- | :--- |
| `GCP_PROJECT_ID` | `fitnearn-devops` | The string Project ID from GCP Console |
| `GCP_LOCATION` | `us-central1` | Regional endpoint for Vertex AI |
| `GCP_SA_KEY` | `ewogICJ0eXBlI...` | **Base64 Encoded** JSON key |

### Key Generation Command:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("key.json"))
```

---

## 🛠️ 3. SDK Architecture (@google/genai)
The system uses the `GoogleGenAI` class in **Vertex Mode**. 

1.  **Auth Discovery:** The system creates a `GoogleAuth` instance from the decoded Base64 buffer.
2.  **SDK Init:** 
    ```javascript
    new GoogleGenAI({
      vertexai: true,
      project: projectId,
      location: location,
      googleAuthOptions: { authClient: await auth.getClient() }
    });
    ```

---

## 🛑 4. Troubleshooting SDK Errors
- **`AI_GATEWAY_TIMEOUT`**: Usually means the `GCP_PROJECT_ID` is incorrect or the `generateContent` call timed out.
- **`AUTH_INITIALIZATION_FAILED`**: The Base64 string is malformed or invalid JSON.
- **`AI_OFFLINE`**: Connectivity issue or the `Vertex AI User` role is missing from the Service Account.
