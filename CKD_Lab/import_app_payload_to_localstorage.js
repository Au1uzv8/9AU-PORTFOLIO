(async function () {
  const payloadUrl = 'app_db_payload.json';

  let payload;
  try {
    const response = await fetch(payloadUrl, { cache: 'no-store' });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    payload = await response.json();
  } catch (error) {
    if (typeof window.__OCR_IMPORT_PAYLOAD__ !== 'undefined') {
      payload = window.__OCR_IMPORT_PAYLOAD__;
    } else {
      console.error('Could not load app_db_payload.json. Put the file beside the app or assign window.__OCR_IMPORT_PAYLOAD__ before running this script.');
      throw error;
    }
  }

  const safeArray = (value, fallback = []) => {
    if (Array.isArray(value)) return value;
    if (value && Array.isArray(value.records)) return value.records;
    return fallback;
  };

  const getItem = (key, fallback) => {
    try {
      const raw = localStorage.getItem(key);
      if (!raw) return fallback;
      const parsed = JSON.parse(raw);
      return parsed;
    } catch (error) {
      return fallback;
    }
  };

  const dbPrevious = getItem('DB', { records: [] });
  const labsPrevious = getItem('LABS', []);
  const groupsPrevious = getItem('GROUPS', []);

  const dbRecords = safeArray(dbPrevious, []);
  const labsRecords = safeArray(labsPrevious, []);
  const groups = safeArray(groupsPrevious, []);

  const incomingDb = safeArray(payload?.DB, []);
  const incomingLabs = safeArray(payload?.LABS, []);
  const incomingGroups = safeArray(payload?.GROUPS, []);

  const dbMap = new Map(dbRecords.map((record) => [record.id, record]));
  for (const record of incomingDb) {
    if (record && record.id && !dbMap.has(record.id)) {
      dbMap.set(record.id, record);
    }
  }

  const labsMap = new Map(labsRecords.map((record) => [record.id, record]));
  for (const record of incomingLabs) {
    if (record && record.id && !labsMap.has(record.id)) {
      labsMap.set(record.id, record);
    }
  }

  const groupsMap = new Map();
  for (const group of groups) {
    const key = group.group_key || `${group.dept || 'unknown'}:${group.date || ''}`;
    groupsMap.set(key, {
      ...group,
      records: Array.isArray(group.records) ? [...group.records] : [],
    });
  }

  for (const group of incomingGroups) {
    const key = group.group_key || `${group.dept || 'unknown'}:${group.date || ''}`;
    const existing = groupsMap.get(key) || {
      group_key: key,
      dept: group.dept,
      date: group.date,
      records: [],
    };

    existing.group_key = existing.group_key || key;
    existing.dept = group.dept || existing.dept;
    existing.date = group.date || existing.date;
    existing.records = Array.from(new Set([...(existing.records || []), ...(group.records || [])]));
    groupsMap.set(key, existing);
  }

  const dbFinal = [...dbMap.values()];
  const labsFinal = [...labsMap.values()];
  const groupsFinal = [...groupsMap.values()];

  localStorage.setItem('DB', JSON.stringify({ records: dbFinal }));
  localStorage.setItem('LABS', JSON.stringify(labsFinal));
  localStorage.setItem('GROUPS', JSON.stringify(groupsFinal));

  console.log(JSON.stringify({
    imported: true,
    db_records: dbFinal.length,
    labs_records: labsFinal.length,
    groups_count: groupsFinal.length,
    source: payloadUrl,
  }, null, 2));
})();
