# Performance and image-storage audit

## Completed

- Receipt lists now load all item rows with batched `IN` queries instead of
  issuing one query per receipt. Queries are chunked below SQLite's bind
  variable limit.
- Re-saving a multi-page receipt removes stale page files first. This prevents
  a receipt edited from three pages down to one page from leaking old images.
- Receipt deletion removes the cover image and stored page images after the
  database row is deleted.

## Remaining release decisions

- Images are currently stored using the bytes returned by the camera/scanner.
  Compression should be added only after choosing a maximum image dimension and
  JPEG quality that preserve OCR accuracy. This needs representative receipt
  QA on both platforms.
- A future maintenance action should scan the receipts directory and remove
  files not referenced by either `receipts.imagePath` or `receipt_images`.
  Deletion is currently best-effort and intentionally does not block a user's
  delete action.
