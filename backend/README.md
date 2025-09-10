# GameWala Repairs - Google Apps Script Backend

This backend provides a JSON REST API on top of a Google Sheet named `GameWala_Repairs`.

Columns (exact order):

```
RepairID | CustomerName | Phone | Product | Issue | Status | EstimatedTime | DateSubmitted | Notes | AssignedTo
```

## Features
- Add new repair entry (auto-generates `RepairID`)
- Update repair status by `RepairID`
- Fetch all repair entries
- Search repairs by `RepairID` or `CustomerName`

## Setup Instructions
1. Create a Google Sheet named `GameWala_Repairs` (empty is fine; the script will ensure headers).
2. Open Extensions → Apps Script.
3. Create a file `Code.gs` and paste the contents from `backend/Code.gs`.
4. Save the project.
5. Deploy as a Web App:
   - Click Deploy → New deployment
   - Select type: Web app
   - Description: GameWala Repairs API
   - Execute as: Me (the owner)
   - Who has access: Anyone with the link (or your org as needed)
   - Click Deploy and authorize
6. Copy the Web App URL (e.g., `https://script.google.com/macros/s/AKfycb.../exec`). Use this as `BASE_URL` in the Flutter app.

## API
All requests/responses are JSON. Use `Content-Type: application/json`.

### GET /exec?action=all
Returns all repair entries.

Response:
```json
{ "success": true, "data": [ { "RepairID": "GW-...", "CustomerName": "..." } ] }
```

### GET /exec?action=search&repairId=GW-...
Search by `RepairID` (exact match). Alternatively:

GET `/exec?action=search&customerName=John`

Response:
```json
{ "success": true, "data": [ { ... }, ... ] }
```

### POST /exec { action: "add", data: { ... } }
Body:
```json
{
  "action": "add",
  "data": {
    "CustomerName": "John Doe",
    "Phone": "9876543210",
    "Product": "PlayStation 5",
    "Issue": "HDMI not working",
    "EstimatedTime": "2 days",
    "AssignedTo": "Ravi",
    "Notes": "Urgent"
  }
}
```

Response:
```json
{ "success": true, "repairId": "GW-20250910-101530-123" }
```

### POST /exec { action: "updateStatus", repairId, status, notes? }
Allowed statuses: `Received`, `In Progress`, `Completed`, `Delivered`.

Body:
```json
{
  "action": "updateStatus",
  "repairId": "GW-20250910-101530-123",
  "status": "Completed",
  "notes": "Replaced HDMI IC"
}
```

Response:
```json
{ "success": true, "repairId": "GW-...", "status": "Completed" }
```

## Tips
- If you change column order or names, update `HEADERS` in `Code.gs`.
- The script ensures headers on first run and bolds the header row.
- `RepairID` is timestamp + random; it is unique for MVP purposes.
