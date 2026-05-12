# Storage "permission denied" for social workers

**Current approach:** Role is enforced via **Auth custom claims**, not Firestore read from Storage.

1. A **Cloud Function** (`functions/syncUserRoleClaim`) runs when `users/{userId}` is created or updated and sets `request.auth.token.role` from the document’s `role` field.
2. **Storage rules** allow write when `request.auth.token.role == 'socialWorker'` (no `firestore.get()`).
3. The app **touches** the user doc when the social worker dashboard appears and **refreshes the ID token** before upload so the claim is present.

You must deploy **both** Functions and Storage rules. See `functions/README.md` for deploy steps. If it still fails after deploy, sign out and sign in once so your token gets the claim.

---

If you were using Firestore-based rules before, note: in Storage rules, reading Firestore must use **`firestore.get()`**, not `get()`. The project now uses custom claims instead.

## 1. Confirm your user document in Firestore

Storage rules read your role from Firestore:

- **Path:** `users/{your-uid}` (replace `{your-uid}` with your Firebase Auth UID).
- **Required field:** `role` (string) with value exactly **`socialWorker`** (lowercase s, camel W, no space).

**How to check:**

1. Firebase Console → **Authentication** → copy your **User UID** (the account you use as social worker).
2. **Firestore Database** → **Data** → open collection **`users`** → open the document whose ID is that UID.
3. Ensure there is a field **`role`** and its value is exactly **`socialWorker`** (not "Social Worker" or "social_worker").

If the document is missing or `role` is different, fix it (e.g. re-run the app’s role selection / profile flow so it creates/updates the `users/{uid}` document with `role: "socialWorker"`).

## 2. Paste the full Storage rules (no extra characters)

In **Storage** → **Rules**, replace everything with this **exact** block (no comments, so nothing breaks on copy-paste):

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /socialPosts/{fileName} {
      allow read: if true;
      allow write: if request.auth != null
        && firestore.get(/databases/(default)/documents/users/$(request.auth.uid)).data.role == 'socialWorker';
    }
  }
}
```

Click **Publish** and wait a short time for the rules to apply.

## 3. Optional: test without the role check

To confirm the failure is due to the `get(...).role == 'socialWorker'` check (and not auth or path):

- Temporarily change the write rule to:  
  `allow write: if request.auth != null;`
- Publish, then try uploading again as the social worker.

- If upload **succeeds**, the problem is the Firestore `get()` or the `users/{uid}` document / `role` value; fix step 1 and restore the full rule.
- If it still **fails**, the problem is elsewhere (e.g. auth, bucket, or a different rule).

Restore the full rule (with the `get(...).role == 'socialWorker'` condition) after testing.
