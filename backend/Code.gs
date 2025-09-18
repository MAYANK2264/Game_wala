/**
 * GameWala Repairs - Google Apps Script Backend
 * Dynamic Google Sheets creation based on owner email
 * Columns: RepairID | CustomerName | Phone | Product | Issue | Status | EstimatedTime | DateSubmitted | Notes | AssignedTo | VoiceNoteURL
 *
 * Exposes a simple JSON REST API via doGet / doPost.
 */

const SHEET_NAME = 'Repairs';
const ARCHIVE_SHEET = 'HandedOver';
const EMP_SHEET = 'Employees';
const PROD_SHEET = 'Products';
// Main database schema per requirements
const HEADERS = [
	'UniqueID',
	'CustomerName',
	'Phone',
	'Product',
	'FaultDescription',
	'FaultVoiceNoteURL',
	'EstimatedTime',
	'DateSubmitted',
	'EmployeeNotes',
	'EmployeeVoiceNotesURL',
	'Status',
	'AssignedEmployee',
	'HandoverDate'
];
// Employees managed by email and status
const EMP_HEADERS = ['Email', 'Status']; // Status: Pending | Active | Suspended
const PROD_HEADERS = ['Product'];

// Default sheet ID (fallback)
const DEFAULT_SHEET_ID = '11uW2U-W45otppbxwTtevwdVT5EJyR0cY9mKUVA08Ka4';
const VOICE_FOLDER_NAME = 'GameWala_VoiceNotes';

// Store owner email to sheet ID mapping
const OWNER_SHEETS = {
  // Add owner emails and their sheet IDs here
  // 'owner@example.com': 'sheet_id_here'
};

function doGet(e) {
	try {
		const action = (e && e.parameter && e.parameter.action) || 'all';
		const ownerEmail = e && e.parameter && e.parameter.ownerEmail;
		
		switch (action) {
			case 'all':
				return jsonResponse(200, { success: true, data: getAllRepairs(ownerEmail) });
			case 'search':
				return handleSearch(e);
			case 'masters':
				return jsonResponse(200, { success: true, data: getMasters(ownerEmail) });
			case 'employees':
				return jsonResponse(200, { success: true, data: listEmployees(ownerEmail) });
			case 'setup':
				return handleSetup(e);
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
				return handleAdd(body.data, body.role, body.actorEmail);
			case 'updateStatus':
				return handleUpdateStatus(body.uniqueId, body.status, body.notes, body.role, body.actorEmail);
			case 'addMaster':
				return handleAddMaster(body.type, body.value, body.role);
			case 'requestAccess':
				return handleRequestAccess(body.email);
			case 'approveEmployee':
				return handleApproveEmployee(body.email, body.role);
			case 'removeEmployee':
				return handleRemoveEmployee(body.email, body.role);
			case 'handover':
				return handleHandover(body.uniqueId, body.role);
			case 'setup':
				return handleSetup(body);
			default:
				return jsonResponse(400, { success: false, error: 'Invalid action for POST.' });
		}
	} catch (err) {
		return jsonResponse(500, { success: false, error: String(err) });
	}
}

function handleAdd(data, role, actorEmail) {
	if (!data) {
		return jsonResponse(400, { success: false, error: 'Missing data for add.' });
	}
	// If employee is adding, require Active by email
	if (String(role || '').toLowerCase() === 'employee') {
		if (!isEmployeeActive(actorEmail)) {
			return jsonResponse(403, { success: false, error: 'Employee not authorized. Ask owner to approve.' });
		}
	}
	const required = ['CustomerName', 'Phone', 'Product', 'FaultDescription', 'EstimatedTime'];
	const missing = required.filter(function (k) { return !data[k]; });
	if (missing.length > 0) {
		return jsonResponse(400, { success: false, error: 'Missing fields: ' + missing.join(', ') });
	}
	if (!/^\d{6,15}$/.test(String(data.Phone))) {
		return jsonResponse(400, { success: false, error: 'Phone must be numeric (6-15 digits).' });
	}

	const sheet = getOrCreateSheet();
	ensureHeaders(sheet);
	const uniqueId = generateUniqueId(sheet, String(data.CustomerName));
	const nowIso = new Date().toISOString();

	// Optional voice note upload (base64) for fault
	var faultVoiceUrl = '';
	if (data.FaultVoiceNoteBase64 && data.FaultVoiceNoteFilename) {
		try {
			faultVoiceUrl = saveVoiceNote(data.FaultVoiceNoteBase64, String(data.FaultVoiceNoteFilename));
		} catch (e) {
			// Non-fatal
		}
	}

	const row = [
		uniqueId,
		String(data.CustomerName).trim(),
		String(data.Phone).trim(),
		String(data.Product).trim(),
		String(data.FaultDescription).trim(),
		faultVoiceUrl,
		String(data.EstimatedTime).trim(),
		nowIso,
		data.EmployeeNotes ? String(data.EmployeeNotes).trim() : '',
		data.EmployeeVoiceNotesURL ? String(data.EmployeeVoiceNotesURL).trim() : '',
		'Received',
		String(data.AssignedEmployee || '').trim(),
		''
	];
	appendRow(sheet, row);
	return jsonResponse(201, { success: true, uniqueId: uniqueId, faultVoiceNoteUrl: faultVoiceUrl });
}

function handleUpdateStatus(uniqueId, status, notes, role, actorEmail) {
    if (!uniqueId || !status) {
		return jsonResponse(400, { success: false, error: 'repairId and status are required.' });
	}
	const normalized = String(status).toLowerCase();
	const allowed = ['received', 'in progress', 'completed', 'handed over'];
	if (allowed.indexOf(normalized) === -1) {
		return jsonResponse(400, { success: false, error: 'Invalid status. Allowed: Received, In Progress, Completed, Handed Over' });
	}
	const sheet = getOrCreateSheet();
	ensureHeaders(sheet);
	const values = sheet.getDataRange().getValues();
	if (values.length <= 1) {
		return jsonResponse(404, { success: false, error: 'No records found.' });
	}
	const idColIndex = HEADERS.indexOf('UniqueID');
	const statusColIndex = HEADERS.indexOf('Status');
	const empNotesColIndex = HEADERS.indexOf('EmployeeNotes');
	const assignedColIndex = HEADERS.indexOf('AssignedEmployee');
	const handoverDateColIndex = HEADERS.indexOf('HandoverDate');
	for (var r = 1; r < values.length; r++) {
		if (String(values[r][idColIndex]) === String(uniqueId)) {
			// RBAC: Employees must be Active and assigned
			const isEmployee = String(role || '').toLowerCase() === 'employee';
			if (isEmployee) {
				if (!isEmployeeActive(actorEmail)) {
					return jsonResponse(403, { success: false, error: 'Employee not authorized. Ask owner to approve.' });
				}
				const assigned = String(values[r][assignedColIndex] || '').trim().toLowerCase();
				const actor = String(actorEmail || '').trim().toLowerCase();
				if (!actor || assigned !== actor) {
					return jsonResponse(403, { success: false, error: 'Forbidden: Only assigned employee can update this repair.' });
				}
			}

			sheet.getRange(r + 1, statusColIndex + 1).setValue(capitalizeStatus(normalized));
			if (typeof notes === 'string' && empNotesColIndex >= 0) {
				var existing = String(values[r][empNotesColIndex] || '');
				var newNotes = notes.trim();
				var combined = existing ? (existing + ' | ' + newNotes) : newNotes;
				sheet.getRange(r + 1, empNotesColIndex + 1).setValue(combined);
			}
			if (normalized === 'handed over') {
				// set handover date now
				sheet.getRange(r + 1, handoverDateColIndex + 1).setValue(new Date().toISOString());
			}
			return jsonResponse(200, { success: true, uniqueId: uniqueId, status: capitalizeStatus(normalized) });
		}
	}
	return jsonResponse(404, { success: false, error: 'UniqueID not found.' });
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
		// Avoid duplicates by email (case-insensitive)
		const data = sheet.getDataRange().getValues();
		const exists = data.some(function (r, idx) {
			if (idx === 0) return false;
			return String(r[0] || '').toLowerCase() === String(value).trim().toLowerCase();
		});
		if (!exists) sheet.appendRow([String(value).trim(), 'Active']);
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

function handleRequestAccess(email) {
    if (!email) {
        return jsonResponse(400, { success: false, error: 'email is required.' });
    }
    const ss = SpreadsheetApp.openById(SHEET_ID);
    const sheet = ss.getSheetByName(EMP_SHEET) || ss.insertSheet(EMP_SHEET);
    ensureEmpHeaders(sheet);
    const values = sheet.getDataRange().getValues();
    const emailLc = String(email).trim().toLowerCase();
    const emailIdx = EMP_HEADERS.indexOf('Email');
    const statusIdx = EMP_HEADERS.indexOf('Status');
    for (var r = 1; r < values.length; r++) {
        const rowEmail = String(values[r][emailIdx] || '').trim().toLowerCase();
        if (rowEmail === emailLc) {
            sheet.getRange(r + 1, statusIdx + 1).setValue('Pending');
            return jsonResponse(200, { success: true, status: 'Pending' });
        }
    }
    sheet.appendRow([emailLc, 'Pending']);
    return jsonResponse(201, { success: true, status: 'Pending' });
}

function handleApproveEmployee(email, role) {
    if (String(role || '').toLowerCase() !== 'owner') {
        return jsonResponse(403, { success: false, error: 'Only Owner can approve employees.' });
    }
    if (!email) {
        return jsonResponse(400, { success: false, error: 'Provide email.' });
    }
    const ss = SpreadsheetApp.openById(SHEET_ID);
    const sheet = ss.getSheetByName(EMP_SHEET);
    if (!sheet) return jsonResponse(404, { success: false, error: 'Employees sheet not found.' });
    ensureEmpHeaders(sheet);
    const values = sheet.getDataRange().getValues();
    const emailLc = String(email || '').trim().toLowerCase();
    const emailIdx = EMP_HEADERS.indexOf('Email');
    const statusIdx = EMP_HEADERS.indexOf('Status');
    for (var r = 1; r < values.length; r++) {
        const rowEmail = String(values[r][emailIdx] || '').trim().toLowerCase();
        if (rowEmail === emailLc) {
            sheet.getRange(r + 1, statusIdx + 1).setValue('Active');
            return jsonResponse(200, { success: true });
        }
    }
    return jsonResponse(404, { success: false, error: 'Employee not found.' });
}

function handleRemoveEmployee(email, role) {
    if (String(role || '').toLowerCase() !== 'owner') {
        return jsonResponse(403, { success: false, error: 'Only Owner can remove employees.' });
    }
    if (!email) {
        return jsonResponse(400, { success: false, error: 'Provide email.' });
    }
    const ss = SpreadsheetApp.openById(SHEET_ID);
    const sheet = ss.getSheetByName(EMP_SHEET);
    if (!sheet) return jsonResponse(404, { success: false, error: 'Employees sheet not found.' });
    ensureEmpHeaders(sheet);
    const values = sheet.getDataRange().getValues();
    const emailLc = String(email || '').trim().toLowerCase();
    const emailIdx = EMP_HEADERS.indexOf('Email');
    for (var r = 1; r < values.length; r++) {
        const rowEmail = String(values[r][emailIdx] || '').trim().toLowerCase();
        if (rowEmail === emailLc) {
            sheet.deleteRow(r + 1);
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
		out.push({ Email: values[r][0], Status: values[r][1] });
	}
	return out;
}

function isEmployeeActive(email) {
	const ss = SpreadsheetApp.openById(SHEET_ID);
	const empSheet = ss.getSheetByName(EMP_SHEET);
	if (!empSheet) return false;
	ensureEmpHeaders(empSheet);
	const values = empSheet.getDataRange().getValues();
	for (var r = 1; r < values.length; r++) {
		const rowEmail = String(values[r][0] || '').trim().toLowerCase();
		const status = String(values[r][1] || '');
		if (String(email || '').trim().toLowerCase() === rowEmail) {
			return status === 'Active';
		}
	}
	return false;
}

function getAllRepairs(ownerEmail) {
	const sheet = getOrCreateSheet(ownerEmail);
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

// Search by UniqueID, CustomerName, or Phone
function handleSearch(e) {
  const params = e && e.parameter ? e.parameter : {};
  const ownerEmail = params.ownerEmail;
  const uniqueId = String(params.uniqueId || '').trim().toLowerCase();
  const customerName = String(params.customerName || '').trim().toLowerCase();
  const phone = String(params.phone || '').replace(/\D/g, '');
  const sheet = getOrCreateSheet(ownerEmail);
  ensureHeaders(sheet);
  const values = sheet.getDataRange().getValues();
  if (values.length <= 1) return jsonResponse(200, { success: true, data: [] });
  const headers = values[0];
  const idIdx = HEADERS.indexOf('UniqueID');
  const nameIdx = HEADERS.indexOf('CustomerName');
  const phoneIdx = HEADERS.indexOf('Phone');
  const out = [];
  for (var r = 1; r < values.length; r++) {
    const row = values[r];
    const idVal = String(row[idIdx] || '').trim().toLowerCase();
    const nameVal = String(row[nameIdx] || '').trim().toLowerCase();
    const phoneVal = String(row[phoneIdx] || '').replace(/\D/g, '');
    if ((uniqueId && idVal.indexOf(uniqueId) !== -1) || (customerName && nameVal.indexOf(customerName) !== -1) || (phone && phoneVal.indexOf(phone) !== -1)) {
      out.push(rowToObject(headers, row));
    }
  }
  return jsonResponse(200, { success: true, data: out });
}

// Helpers
function getOrCreateSheet(ownerEmail) {
	const sheetId = getSheetIdForOwner(ownerEmail);
	const ss = SpreadsheetApp.openById(sheetId);
	let sheet = ss.getSheetByName(SHEET_NAME);
	if (!sheet) {
		sheet = ss.insertSheet(SHEET_NAME);
	}
	// Ensure archive exists
	let arch = ss.getSheetByName(ARCHIVE_SHEET);
	if (!arch) arch = ss.insertSheet(ARCHIVE_SHEET);
	ensureHeaders(arch); // archive uses same headers
	return sheet;
}

function ensureHeaders(sheet) {
	const firstRow = sheet.getRange(1, 1, 1, HEADERS.length).getValues()[0];
	const needsHeaders = HEADERS.some(function (h, idx) { return String(firstRow[idx] || '') !== h; });
	if (needsHeaders) {
		sheet.clear();
		sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
		sheet.getRange(1, 1, 1, HEADERS.length).setFontWeight('bold');
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

// UniqueID: lowercase customer name, no spaces; if duplicate append incrementing number
function generateUniqueId(sheet, customerName) {
  var base = String(customerName || '').trim().toLowerCase().replace(/\s+/g, '');
  if (!base) base = 'customer';
  var existing = sheet.getDataRange().getValues();
  var idIdx = HEADERS.indexOf('UniqueID');
  var taken = {};
  for (var r = 1; r < existing.length; r++) {
    var id = String(existing[r][idIdx] || '').trim().toLowerCase();
    if (id) taken[id] = true;
  }
  if (!taken[base]) return base;
  var i = 1;
  while (taken[base + i]) i++;
  return base + i;
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
		case 'handed over': return 'Handed Over';
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

// Setup function to create Google Sheets for new owners
function handleSetup(data) {
	try {
		const ownerEmail = data.ownerEmail;
		if (!ownerEmail) {
			return jsonResponse(400, { success: false, error: 'Owner email is required.' });
		}
		
		// Check if sheet already exists for this owner
		const existingSheetId = getSheetIdForOwner(ownerEmail);
		if (existingSheetId) {
			return jsonResponse(200, { 
				success: true, 
				message: 'Sheet already exists for this owner.',
				sheetId: existingSheetId,
				sheetUrl: `https://docs.google.com/spreadsheets/d/${existingSheetId}/edit`
			});
		}
		
		// Create new Google Sheet
		const sheetId = createSheetForOwner(ownerEmail);
		if (sheetId) {
			return jsonResponse(200, { 
				success: true, 
				message: 'Sheet created successfully for owner.',
				sheetId: sheetId,
				sheetUrl: `https://docs.google.com/spreadsheets/d/${sheetId}/edit`
			});
		} else {
			return jsonResponse(500, { success: false, error: 'Failed to create sheet.' });
		}
	} catch (err) {
		return jsonResponse(500, { success: false, error: String(err) });
	}
}

// Get sheet ID for owner email
function getSheetIdForOwner(ownerEmail) {
	// Check if we have a mapping for this owner
	if (OWNER_SHEETS[ownerEmail]) {
		return OWNER_SHEETS[ownerEmail];
	}
	
	// For now, use default sheet
	return DEFAULT_SHEET_ID;
}

// Create a new Google Sheet for owner
function createSheetForOwner(ownerEmail) {
	try {
		// Create a new spreadsheet
		const spreadsheet = SpreadsheetApp.create(`GameWala_Repairs_${ownerEmail.replace('@', '_').replace('.', '_')}`);
		
        // Get the main sheet and rename to Repairs
        const sheet = spreadsheet.getActiveSheet();
        sheet.setName(SHEET_NAME);
		
        // Set up headers
		sheet.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
		
		// Create Employees sheet
		const empSheet = spreadsheet.insertSheet(EMP_SHEET);
        empSheet.getRange(1, 1, 1, EMP_HEADERS.length).setValues([EMP_HEADERS]);
		
		// Create Products sheet
		const prodSheet = spreadsheet.insertSheet(PROD_SHEET);
		prodSheet.getRange(1, 1, 1, PROD_HEADERS.length).setValues([PROD_HEADERS]);

        // Create Archive sheet
        const archive = spreadsheet.insertSheet(ARCHIVE_SHEET);
        archive.getRange(1, 1, 1, HEADERS.length).setValues([HEADERS]);
		
		// Add some default products
		const defaultProducts = [
			['PlayStation 5'],
			['PlayStation 4'],
			['Xbox Series X'],
			['Xbox One'],
			['Nintendo Switch'],
			['Gaming Controller'],
			['Headset'],
			['Charging Cable']
		];
		prodSheet.getRange(2, 1, defaultProducts.length, 1).setValues(defaultProducts);
		
		// Share with owner
		spreadsheet.addEditor(ownerEmail);
		
		// Return the sheet ID
		return spreadsheet.getId();
	} catch (err) {
		console.error('Error creating sheet:', err);
		return null;
	}
}

// Helper function to get the correct sheet based on owner email
function getSheet(ownerEmail) {
	const sheetId = getSheetIdForOwner(ownerEmail);
	return SpreadsheetApp.openById(sheetId);
}

// Move record to HandedOver sheet and set status/date
function handleHandover(uniqueId, role) {
  if (!uniqueId) return jsonResponse(400, { success: false, error: 'uniqueId required' });
  const ss = SpreadsheetApp.openById(SHEET_ID);
  const main = ss.getSheetByName(SHEET_NAME) || ss.insertSheet(SHEET_NAME);
  const arch = ss.getSheetByName(ARCHIVE_SHEET) || ss.insertSheet(ARCHIVE_SHEET);
  ensureHeaders(main);
  ensureHeaders(arch);
  const values = main.getDataRange().getValues();
  const idIdx = HEADERS.indexOf('UniqueID');
  const statusIdx = HEADERS.indexOf('Status');
  const handIdx = HEADERS.indexOf('HandoverDate');
  for (var r = 1; r < values.length; r++) {
    if (String(values[r][idIdx]) === String(uniqueId)) {
      // update status/date
      main.getRange(r + 1, statusIdx + 1).setValue('Handed Over');
      const now = new Date().toISOString();
      main.getRange(r + 1, handIdx + 1).setValue(now);
      const row = main.getRange(r + 1, 1, 1, HEADERS.length).getValues()[0];
      appendRow(arch, row);
      return jsonResponse(200, { success: true });
    }
  }
  return jsonResponse(404, { success: false, error: 'UniqueID not found.' });
}

function appendRow(sheet, row) {
  sheet.appendRow(row);
}


