/**
 * Check what status values exist in Object_126
 */

const KNACK_APP_ID = '5ee90912c38ae7001510c1a9';
const KNACK_API_KEY = '8f733aa5-dd35-4464-8348-64824d1f5f0d';

async function check() {
  const url = `https://api.knack.com/v1/objects/object_126/records?page=1&rows_per_page=1000&format=raw`;
  
  const response = await fetch(url, {
    headers: {
      'X-Knack-Application-Id': KNACK_APP_ID,
      'X-Knack-REST-API-Key': KNACK_API_KEY
    }
  });
  
  const data = await response.json();
  
  const statusValues = {};
  data.records.forEach(rec => {
    const status = rec.field_3543;
    statusValues[status] = (statusValues[status] || 0) + 1;
  });
  
  console.log('Status values in Object_126 (field_3543):');
  Object.entries(statusValues).forEach(([status, count]) => {
    console.log(`  "${status}": ${count} records`);
  });
}

check();

