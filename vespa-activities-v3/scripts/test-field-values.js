/**
 * Quick test to see what field_3546 contains
 */

const KNACK_APP_ID = '5ee90912c38ae7001510c1a9';
const KNACK_API_KEY = '8f733aa5-dd35-4464-8348-64824d1f5f0d';

async function test() {
  const url = `https://api.knack.com/v1/objects/object_126/records?page=1&rows_per_page=10&format=raw`;
  
  const response = await fetch(url, {
    headers: {
      'X-Knack-Application-Id': KNACK_APP_ID,
      'X-Knack-REST-API-Key': KNACK_API_KEY
    }
  });
  
  const data = await response.json();
  
  console.log('First 3 records with field_3546:');
  data.records.slice(0, 3).forEach((rec, i) => {
    console.log(`\nRecord #${i+1} (${rec.id}):`);
    console.log('  field_3536 (student):', JSON.stringify(rec.field_3536));
    console.log('  field_3537 (activity):', JSON.stringify(rec.field_3537));
    console.log('  field_3543 (status):', rec.field_3543);
    console.log('  field_3546 (selected_via):', rec.field_3546);
  });
}

test();

