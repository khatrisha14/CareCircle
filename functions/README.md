# CareCircle Cloud Functions

## syncUserRoleClaim

When a document in `users/{userId}` is **created or updated**, this function sets the same `role` as a Firebase Auth **custom claim** on that user. Storage rules then allow uploads with `request.auth.token.role == 'socialWorker'` (no Firestore read from Storage).

### Deploy

From the **project root** (where `firebase.json` is):

```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### First-time setup

- You need the **Blaze** plan to use Cloud Functions.
- If you haven’t used Functions before: `firebase login` and `firebase use <project-id>`.

### After deploy

1. Deploy Storage rules: `firebase deploy --only storage`
2. Open the app as a social worker. The dashboard “touch” updates your user doc and triggers the function so your token gets the `role` claim.
3. If upload still fails, **sign out and sign in once** so your ID token is refreshed with the new claim, then try creating a post with an image again.
