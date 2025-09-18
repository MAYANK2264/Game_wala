# GameWala Repairs - Google Apps Script Backend

This backend provides a JSON REST API on top of Google Sheets. On first owner setup it creates a spreadsheet with sheets: `Repairs`, `HandedOver`, `Employees`, `Products`.

Main sheet `Repairs` columns (exact order):

```
UniqueID | CustomerName | Phone | Product | FaultDescription | FaultVoiceNoteURL | EstimatedTime | DateSubmitted | EmployeeNotes | EmployeeVoiceNotesURL | Status | AssignedEmployee | HandoverDate
```

## Features
- Add repair (auto-generates `UniqueID` per customer name)
- Update status (Received, In Progress, Completed, Handed Over)
- Search by `UniqueID`, `CustomerName`, or `Phone`
- Get all repairs
- Handover: moves the row to `HandedOver` and stamps date
- Employee management by email: requestAccess, approve, remove

## Setup Instructions
1. Open drive.google.com → New → Google Apps Script.
2. Create a file `Code.gs` and paste the contents from `backend/Code.gs`.
3. Save the project.
4. Deploy as a Web App:
   - Click Deploy → New deployment
   - Select type: Web app
   - Description: GameWala Repairs API
   - Execute as: Me (the owner)
   - Who has access: Anyone with the link (or your org as needed)
   - Click Deploy and authorize
5. Copy the Web App URL (e.g., `https://script.google.com/macros/s/AKfycb.../exec`). Use this as `_baseUrl` in the Flutter app.

## API
All requests/responses are JSON. Use `Content-Type: application/json`.

### GET /exec?action=all
Returns all repair entries.

Response:
```json
{ "success": true, "data": [ { "UniqueID": "rahul", "CustomerName": "Rahul" } ] }
```

### GET /exec?action=search&uniqueId=rahul`
Alternatively: `/exec?action=search&customerName=John` or `/exec?action=search&phone=98765`

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
    "FaultDescription": "HDMI not working",
    "EstimatedTime": "2 days",
    "AssignedEmployee": "ravi@example.com",
    "EmployeeNotes": "Urgent"
  }
}
```

Response:
```json
{ "success": true, "uniqueId": "rahul" }
```

### POST /exec { action: "updateStatus", uniqueId, status, notes? }
Allowed statuses: `Received`, `In Progress`, `Completed`, `Handed Over`.

Body:
```json
{
  "action": "updateStatus",
  "uniqueId": "rahul",
  "status": "Completed",
  "notes": "Replaced HDMI IC"
}
```

Response:
```json
{ "success": true, "uniqueId": "rahul", "status": "Completed" }
```

### POST /exec { action: "handover", uniqueId }
Moves record to `HandedOver` sheet, sets `HandoverDate`, status `Handed Over`.

## Tips
- If you change column order or names, update `HEADERS` in `Code.gs`.
- The script ensures headers on first run and bolds the header row.
- `RepairID` is timestamp + random; it is unique for MVP purposes.
