# Import OCR payload into the app localStorage

This workspace already contains the validated payload in `app_db_payload.json`.

## Browser import method

1. Open the CKD lab tracker page in the browser.
2. Open Developer Tools.
3. Paste the contents of `import_app_payload_to_localstorage.js` into the Console.
4. If the app is served from a static folder, the script will automatically load `app_db_payload.json` from the same directory.
5. If the app is opened as a local file and the JSON is not served, set this before running the script:

```js
window.__OCR_IMPORT_PAYLOAD__ = JSON.parse(`PASTE_THE_JSON_HERE`);
```

Then run the script again.

## Result

The script merges the imported OCR data into the existing `DB`, `LABS`, and `GROUPS` localStorage keys without overwriting the original app logic.

## Notes

- The original HTML app is left untouched.
- New records are appended only if their `id` is not already present.
- The payload was generated from the OCR review data and follows the app contract already used by the tracker.
