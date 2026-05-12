# Firebase rules deployment

- **Firestore:** `firebase deploy --only firestore` (uses `firestore.rules`)
- **Storage:** `firebase deploy --only storage` (uses `storage.rules`)

If social workers get "permission denied" when uploading post images, deploy Storage rules and ensure you’re in the correct Firebase project (`firebase use`).
