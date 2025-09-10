/**
 * GameWala Repairs - Google Apps Script Backend
 * Sheet: GameWala_Repairs
 * Columns: RepairID | CustomerName | Phone | Product | Issue | Status | EstimatedTime | DateSubmitted | Notes | AssignedTo | VoiceNoteURL
 *
 * Exposes a simple JSON REST API via doGet / doPost.
 */

const SHEET_NAME = 'GameWala_Repairs';
const EMP_SHEET = 'Employees';
const PROD_SHEET = 'Products';
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
	'AssignedTo',
	'VoiceNoteURL'
];
const EMP_HEADERS = ['Name', 'Phone', 'Status']; // Status: Pending | Active | Suspended
const PROD_HEADERS = ['Product'];

// Bind explicitly to the provided Google Sheet ID to work as a standalone Web App
const SHEET_ID = '11uW2U-W45otppbxwTtevwdVT5EJyR0cY9mKUVA08Ka4';
const VOICE_FOLDER_NAME = 'GameWala_VoiceNotes';

function doGet(e) {
	try {
		const action = (e && e.parameter && e.parameter.action) || 'all';
		switch (action) {
			case 'all':
				return jsonResponse(200, { success: true, data: getAllRepairs() });
			case 'search':
				return handleSearch(e);
			case 'masters':
				return jsonResponse(200, { success: true, data: getMasters() });
			case 'employees':
				return jsonResponse(200, { success: true, data: listEmployees() });
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
				return handleAdd(body.data, body.role, body.actorName, body.actorPhone);
			case 'updateStatus':
				return handleUpdateStatus(body.repairId, body.status, body.notes, body.role, body.actorName, body.actorPhone);
			case 'addMaster':
				return handleAddMaster(body.type, body.value, body.role);
			case 'requestAccess':
				return handleRequestAccess(body.name, body.phone);
			case 'approveEmployee':
				return handleApproveEmployee(body.name, body.phone, body.role);
			default:
				return jsonResponse(400, { success: false, error: 'Invalid action for POST.' });
		}
	} catch (err) {
		return jsonResponse(500, { success: false, error: String(err) });
	}
}

function handleAdd(data, role, actorName, actorPhone) {
	if (!data) {
		return jsonResponse(400, { success: false, error: 'Missing data for add.' });
	}
	// If employee is adding, require Active
	if (String(role || '').toLowerCase() === 'employee') {
		if (!isEmployeeActive(actorName, actorPhone)) {
			return jsonResponse(403, { success: false, error: 'Employee not authorized. Ask owner to approve.' });
		}
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
	const repairId = generateSimpleRepairId(String(data.CustomerName), String(data.Phone));
	const nowIso = new Date().toISOString();

	// Optional voice note upload (base64)
	var voiceUrl = '';
	if (data.VoiceNoteBase64 && data.VoiceNoteFilename) {
		try {
			voiceUrl = saveVoiceNote(data.VoiceNoteBase64, String(data.VoiceNoteFilename));
		} catch (e) {
			// Non-fatal
		}
	}

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
		String(data.AssignedTo).trim(),
		voiceUrl
	];
	appendRow(sheet, row);
	return jsonResponse(201, { success: true, repairId: repairId, voiceNoteUrl: voiceUrl });
}

function handleUpdateStatus(repairId, status, notes, role, actorName, actorPhone) {
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
	const assignedColIndex = HEADERS.indexOf('AssignedTo');
	for (var r = 1; r < values.length; r++) {
		if (String(values[r][idColIndex]) === String(repairId)) {
			// RBAC: Employees must be Active and assigned
			const isEmployee = String(role || '').toLowerCase() === 'employee';
			if (isEmployee) {
				if (!isEmployeeActive(actorName, actorPhone)) {
					return jsonResponse(403, { success: false, error: 'Employee not authorized. Ask owner to approve.' });
				}
				const assigned = String(values[r][assignedColIndex] || '').trim().toLowerCase();
				const actor = String(actorName || '').trim().toLowerCase();
				if (!actor || assigned !== actor) {
					return jsonResponse(403, { success: false, error: 'Forbidden: Only assigned employee can update this repair.' });
				}
			}

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

function handleAddMaster(type, value, role) {
	if (String(role || '').toLowerCase() !== 'owner') {
		return jsonResponse(403, { success: false, error: 'Only Owner can modify master data.' });
	}
	if (!type || !value) {
		return jsonResponse(400, { success: false, error: 'type and value are required.' });
	}
	const ss = SpreadsheetApp.openById(SHEET_ID);
	const t = String(type).toLowerCase();
	let sheet;
	if (t === 'employee') {
		sheet = ss.getSheetByName(EMP_SHEET) || ss.insertSheet(EMP_SHEET);
		ensureEmpHeaders(sheet);
		// Avoid duplicates by name (case-insensitive)
		const data = sheet.getDataRange().getValues();
		const exists = data.some(function (r, idx) {
			if (idx === 0) return false;
			return String(r[0] || '').toLowerCase() === String(value).trim().toLowerCase();
		});
		if (!exists) sheet.appendRow([String(value).trim(), '', 'Active']);
		return jsonResponse(200, { success: true });
	} else if (t === 'product') {
		sheet = ss.getSheetByName(PROD_SHEET) || ss.insertSheet(PROD_SHEET);
		ensureProdHeaders(sheet);
		const data = sheet.getDataRange().getValues();
		const exists = data.some(function (r, idx) {
			if (idx === 0) return false;
			return String(r[0] || '').toLowerCase() === String(value).trim().toLowerCase();
		});
		if (!exists) sheet.appendRow([String(value).trim()]);
		return jsonResponse(200, { success: true });
	}
	return jsonResponse(400, { success: false, error: 'Invalid master type.' });
}

function handleRequestAccess(name, phone) {
	if (!name || !phone) {
		return jsonResponse(400, { success: false, error: 'name and phone are required.' });
	}
	const ss = SpreadsheetApp.openById(SHEET_ID);
	const sheet = ss.getSheetByName(EMP_SHEET) || ss.insertSheet(EMP_SHEET);
	ensureEmpHeaders(sheet);
	const values = sheet.getDataRange().getValues();
	const nameLc = String(name).trim().toLowerCase();
	const phoneStr = String(phone).replace(/\D/g, '');
	// Update if exists else insert
	const nameIdx = EMP_HEADERS.indexOf('Name');
	const phoneIdx = EMP_HEADERS.indexOf('Phone');
	const statusIdx = EMP_HEADERS.indexOf('Status');
	for (var r = 1; r < values.length; r++) {
		const rowName = String(values[r][nameIdx] || '').trim().toLowerCase();
		const rowPhone = String(values[r][phoneIdx] || '').replace(/\D/g, '');
		if (rowName === nameLc || (rowPhone && rowPhone === phoneStr)) {
			sheet.getRange(r + 1, nameIdx + 1).setValue(name);
			sheet.getRange(r + 1, phoneIdx + 1).setValue(phoneStr);
			sheet.getRange(r + 1, statusIdx + 1).setValue('Pending');
			return jsonResponse(200, { success: true, status: 'Pending' });
		}
	}
	sheet.appendRow([name, phoneStr, 'Pending']);
	return jsonResponse(201, { success: true, status: 'Pending' });
}

function handleApproveEmployee(name, phone, role) {
	if (String(role || '').toLowerCase() !== 'owner') {
		return jsonResponse(403, { success: false, error: 'Only Owner can approve employees.' });
	}
	if (!name && !phone) {
		return jsonResponse(400, { success: false, error: 'Provide name or phone.' });
	}
	const ss = SpreadsheetApp.openById(SHEET_ID);
	const sheet = ss.getSheetByName(EMP_SHEET);
	if (!sheet) return jsonResponse(404, { success: false, error: 'Employees sheet not found.' });
	ensureEmpHeaders(sheet);
	const values = sheet.getDataRange().getValues();
	const nameLc = String(name || '').trim().toLowerCase();
	const phoneStr = String(phone || '').replace(/\D/g, '');
	const nameIdx = EMP_HEADERS.indexOf('Name');
	const phoneIdx = EMP_HEADERS.indexOf('Phone');
	const statusIdx = EMP_HEADERS.indexOf('Status');
	for (var r = 1; r < values.length; r++) {
		const rowName = String(values[r][nameIdx] || '').trim().toLowerCase();
		const rowPhone = String(values[r][phoneIdx] || '').replace(/\D/g, '');
		if ((name && rowName === nameLc) || (phone && rowPhone === phoneStr)) {
			sheet.getRange(r + 1, statusIdx + 1).setValue('Active');
			return jsonResponse(200, { success: true });
		}
	}
	return jsonResponse(404, { success: false, error: 'Employee not found.' });
}

function getMasters() {
	const ss = SpreadsheetApp.openById(SHEET_ID);
	const empSheet = ss.getSheetByName(EMP_SHEET);
	const prodSheet = ss.getSheetByName(PROD_SHEET);
	const employees = empSheet ? empSheet.getDataRange().getValues().map(function (r, i) { return i === 0 ? null : r[0]; }).filter(function (x) { return x; }) : [];
	const products = prodSheet ? prodSheet.getDataRange().getValues().map(function (r, i) { return i === 0 ? null : r[0]; }).filter(function (x) { return x; }) : [];
	return { employees: employees, products: products };
}

function listEmployees() {
	const ss = SpreadsheetApp.openById(SHEET_ID);
	const empSheet = ss.getSheetByName(EMP_SHEET);
	if (!empSheet) return [];
	ensureEmpHeaders(empSheet);
	const values = empSheet.getDataRange().getValues();
	const out = [];
	for (var r = 1; r < values.length; r++) {
		out.push({ Name: values[r][0], Phone: values[r][1], Status: values[r][2] });
	}
	return out;
}

function isEmployeeActive(name, phone) {
	const ss = SpreadsheetApp.openById(SHEET_ID);
	const empSheet = ss.getSheetByName(EMP_SHEET);
	if (!empSheet) return false;
	ensureEmpHeaders(empSheet);
	const values = empSheet.getDataRange().getValues();
	const nameLc = String(name || '').trim().toLowerCase();
	const phoneStr = String(phone || '').replace(/\D/g, '');
	for (var r = 1; r < values.length; r++) {
		const rowName = String(values[r][0] || '').trim().toLowerCase();
		const rowPhone = String(values[r][1] || '').replace(/\D/g, '');
		const status = String(values[r][2] || '');
		if ((name && rowName === nameLc) || (phone && rowPhone === phoneStr)) {
			return status === 'Active';
		}
	}
	return false;
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

function ensureEmpHeaders(sheet) {
	const firstRow = sheet.getRange(1, 1, 1, EMP_HEADERS.length).getValues()[0];
	const needsHeaders = EMP_HEADERS.some(function (h, idx) { return String(firstRow[idx] || '') !== h; });
	if (needsHeaders) {
		sheet.clear();
		sheet.getRange(1, 1, 1, EMP_HEADERS.length).setValues([EMP_HEADERS]);
		sheet.getRange(1, 1, 1, EMP_HEADERS.length).setFontWeight('bold');
	}
}

function ensureProdHeaders(sheet) {
	const firstRow = sheet.getRange(1, 1, 1, PROD_HEADERS.length).getValues()[0];
	const needsHeaders = PROD_HEADERS.some(function (h, idx) { return String(firstRow[idx] || '') !== h; });
	if (needsHeaders) {
		sheet.clear();
		sheet.getRange(1, 1, 1, PROD_HEADERS.length).setValues([PROD_HEADERS]);
		sheet.getRange(1, 1, 1, PROD_HEADERS.length).setFontWeight('bold');
	}
}

function rowToObject(headers, row) {
	const obj = {};
	for (var i = 0; i < headers.length; i++) {
		obj[headers[i]] = row[i];
	}
	return obj;
}

function generateSimpleRepairId(customerName, phone) {
	const cust = String(customerName || '').trim().toUpperCase();
	const initials = cust.replace(/[^A-Z]/g, '').slice(0, 3) || 'CST';
	const last4 = String(phone || '').replace(/\D/g, '').slice(-4) || '0000';
	const now = new Date();
	const mm = ('0' + (now.getMonth() + 1)).slice(-2);
	const ss = ('0' + now.getSeconds()).slice(-2);
	return 'GW-' + initials + '-' + last4 + '-' + mm + ss;
}

function saveVoiceNote(base64, filename) {
	const folder = getOrCreateVoiceFolder();
	const contentType = guessContentType(filename);
	const blob = Utilities.newBlob(Utilities.base64Decode(base64), contentType, filename);
	const file = folder.createFile(blob);
	file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
	return file.getUrl();
}

function getOrCreateVoiceFolder() {
	const root = DriveApp.getRootFolder();
	const it = root.getFoldersByName(VOICE_FOLDER_NAME);
	if (it.hasNext()) return it.next();
	return root.createFolder(VOICE_FOLDER_NAME);
}

function guessContentType(name) {
	const n = String(name || '').toLowerCase();
	if (n.endsWith('.m4a')) return 'audio/m4a';
	if (n.endsWith('.mp3')) return 'audio/mpeg';
	if (n.endsWith('.wav')) return 'audio/wav';
	return 'application/octet-stream';
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
	return out;
}

function safeParseJson(text) {
	try { return text ? JSON.parse(text) : null; } catch (e) { return null; }
}


