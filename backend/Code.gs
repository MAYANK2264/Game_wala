/**
 * GameWala Repairs - Google Apps Script Backend
 * Sheet: GameWala_Repairs
 * Columns: RepairID | CustomerName | Phone | Product | Issue | Status | EstimatedTime | DateSubmitted | Notes | AssignedTo
 *
 * Exposes a simple JSON REST API via doGet / doPost.
 */

const SHEET_NAME = 'GameWala_Repairs';
const HEADERS = [
	'RepairID',
	'CustomerName',
	'Phone',
	'Product',
	'Issue',
	'Status',
	'EstimatedTime',
	'DateSubmitted',
	'Notes',
	'AssignedTo'
];

// Bind explicitly to the provided Google Sheet ID to work as a standalone Web App
const SHEET_ID = '11uW2U-W45otppbxwTtevwdVT5EJyR0cY9mKUVA08Ka4';

function doGet(e) {
	try {
		const action = (e && e.parameter && e.parameter.action) || 'all';
		switch (action) {
			case 'all':
				return jsonResponse(200, { success: true, data: getAllRepairs() });
			case 'search':
				return handleSearch(e);
			default:
				return jsonResponse(400, { success: false, error: 'Invalid action for GET.' });
		}
	} catch (err) {
		return jsonResponse(500, { success: false, error: String(err) });
	}
}

function doPost(e) {
	try {
		const body = safeParseJson(e && e.postData && e.postData.contents);
		if (!body) {
			return jsonResponse(400, { success: false, error: 'Invalid or missing JSON body.' });
		}
		const action = body.action;
		switch (action) {
			case 'add':
				return handleAdd(body.data);
			case 'updateStatus':
				return handleUpdateStatus(body.repairId, body.status, body.notes);
			default:
				return jsonResponse(400, { success: false, error: 'Invalid action for POST.' });
		}
	} catch (err) {
		return jsonResponse(500, { success: false, error: String(err) });
	}
}

function handleAdd(data) {
	if (!data) {
		return jsonResponse(400, { success: false, error: 'Missing data for add.' });
	}
	const required = ['CustomerName', 'Phone', 'Product', 'Issue', 'EstimatedTime', 'AssignedTo'];
	const missing = required.filter(function (k) { return !data[k]; });
	if (missing.length > 0) {
		return jsonResponse(400, { success: false, error: 'Missing fields: ' + missing.join(', ') });
	}
	if (!/^\d{6,15}$/.test(String(data.Phone))) {
		return jsonResponse(400, { success: false, error: 'Phone must be numeric (6-15 digits).' });
	}

	const sheet = getOrCreateSheet();
	ensureHeaders(sheet);
	const repairId = generateRepairId();
	const nowIso = new Date().toISOString();
	const row = [
		repairId,
		String(data.CustomerName).trim(),
		String(data.Phone).trim(),
		String(data.Product).trim(),
		String(data.Issue).trim(),
		'Received',
		String(data.EstimatedTime).trim(),
		nowIso,
		data.Notes ? String(data.Notes).trim() : '',
		String(data.AssignedTo).trim()
	];
	appendRow(sheet, row);
	return jsonResponse(201, { success: true, repairId: repairId });
}

function handleUpdateStatus(repairId, status, notes) {
	if (!repairId || !status) {
		return jsonResponse(400, { success: false, error: 'repairId and status are required.' });
	}
	const normalized = String(status).toLowerCase();
	const allowed = ['received', 'in progress', 'completed', 'delivered'];
	if (allowed.indexOf(normalized) === -1) {
		return jsonResponse(400, { success: false, error: 'Invalid status. Allowed: Received, In Progress, Completed, Delivered' });
	}
	const sheet = getOrCreateSheet();
	ensureHeaders(sheet);
	const values = sheet.getDataRange().getValues();
	if (values.length <= 1) {
		return jsonResponse(404, { success: false, error: 'No records found.' });
	}
	const idColIndex = HEADERS.indexOf('RepairID');
	const statusColIndex = HEADERS.indexOf('Status');
	const notesColIndex = HEADERS.indexOf('Notes');
	for (var r = 1; r < values.length; r++) {
		if (String(values[r][idColIndex]) === String(repairId)) {
			sheet.getRange(r + 1, statusColIndex + 1).setValue(capitalizeStatus(normalized));
			if (typeof notes === 'string' && notesColIndex >= 0) {
				var existing = String(values[r][notesColIndex] || '');
				var newNotes = notes.trim();
				var combined = existing ? (existing + ' | ' + newNotes) : newNotes;
				sheet.getRange(r + 1, notesColIndex + 1).setValue(combined);
			}
			return jsonResponse(200, { success: true, repairId: repairId, status: capitalizeStatus(normalized) });
		}
	}
	return jsonResponse(404, { success: false, error: 'RepairID not found.' });
}

function handleSearch(e) {
	const repairId = e && e.parameter && e.parameter.repairId;
	const customerName = e && e.parameter && e.parameter.customerName;
	if (!repairId && !customerName) {
		return jsonResponse(400, { success: false, error: 'Provide repairId or customerName.' });
	}
	const sheet = getOrCreateSheet();
	ensureHeaders(sheet);
	const values = sheet.getDataRange().getValues();
	const results = [];
	const headers = values[0];
	for (var r = 1; r < values.length; r++) {
		var obj = rowToObject(headers, values[r]);
		if (repairId && String(obj.RepairID) === String(repairId)) {
			results.push(obj);
			break; // unique id
		}
		if (!repairId && customerName) {
			var name = String(customerName).toLowerCase();
			if (String(obj.CustomerName).toLowerCase().indexOf(name) !== -1) {
				results.push(obj);
			}
		}
	}
	return jsonResponse(200, { success: true, data: results });
}

function getAllRepairs() {
	const sheet = getOrCreateSheet();
	ensureHeaders(sheet);
	const values = sheet.getDataRange().getValues();
	if (values.length <= 1) {
		return [];
	}
	const headers = values[0];
	const out = [];
	for (var r = 1; r < values.length; r++) {
		out.push(rowToObject(headers, values[r]));
	}
	return out;
}

// Helpers
function getOrCreateSheet() {
	const ss = SpreadsheetApp.openById(SHEET_ID);
	let sheet = ss.getSheetByName(SHEET_NAME);
	if (!sheet) {
		sheet = ss.insertSheet(SHEET_NAME);
	}
	return sheet;
}

function ensureHeaders(sheet) {
	const firstRow = sheet.getRange(1, 1, 1, HEADERS.length).getValues()[0];
	const needsHeaders = HEADERS.some(function (h, idx) { return String(firstRow[idx] || '') !== h; });
	if (needsHeaders) {
		sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
		const range = sheet.getRange(1, 1, 1, HEADERS.length);
		range.setFontWeight('bold');
	}
}

function appendRow(sheet, row) {
	sheet.appendRow(row);
}

function rowToObject(headers, row) {
	const obj = {};
	for (var i = 0; i < headers.length; i++) {
		obj[headers[i]] = row[i];
	}
	return obj;
}

function generateRepairId() {
	const now = new Date();
	const y = now.getFullYear();
	const m = ('0' + (now.getMonth() + 1)).slice(-2);
	const d = ('0' + now.getDate()).slice(-2);
	const h = ('0' + now.getHours()).slice(-2);
	const min = ('0' + now.getMinutes()).slice(-2);
	const s = ('0' + now.getSeconds()).slice(-2);
	const rand = Math.floor(Math.random() * 1000);
	return 'GW-' + y + m + d + '-' + h + min + s + '-' + rand;
}

function capitalizeStatus(s) {
	switch (String(s).toLowerCase()) {
		case 'received': return 'Received';
		case 'in progress': return 'In Progress';
		case 'completed': return 'Completed';
		case 'delivered': return 'Delivered';
		default: return s;
	}
}

function jsonResponse(statusCode, obj) {
	const out = ContentService.createTextOutput(JSON.stringify(obj));
	out.setMimeType(ContentService.MimeType.JSON);
	// Note: Apps Script Web App does not truly support arbitrary status codes, but we include for reference.
	return out;
}

function safeParseJson(text) {
	try { return text ? JSON.parse(text) : null; } catch (e) { return null; }
}


