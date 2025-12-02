// === SCORECARD DEBUGGER ===
// Copy and paste this ENTIRE block into console while on student workspace

(function debugScorecard() {
  console.clear();
  console.log("%c🔍 SCORECARD DEBUGGER", "color: cyan; font-size: 20px; font-weight: bold; background: black; padding: 10px");
  
  // Find elements
  const header = document.querySelector('.workspace-header-compact');
  const row1 = document.querySelector('.header-row-1');
  const row2 = document.querySelector('.header-row-2');
  const scorecard = document.querySelector('.scorecard');
  const studentName = document.querySelector('.student-name-large');
  
  console.log("\n%c📦 ELEMENT CHECK:", "color: yellow; font-size: 16px; font-weight: bold");
  console.table({
    'Header': header ? '✅ FOUND' : '❌ Missing',
    'Row 1': row1 ? '✅ FOUND' : '❌ Missing',
    'Row 2': row2 ? '✅ FOUND' : '❌ Missing',
    'Scorecard': scorecard ? '✅ FOUND' : '❌ Missing',
    'Student Name': studentName ? '✅ FOUND' : '❌ Missing'
  });
  
  // If header exists
  if (header) {
    const headerStyles = getComputedStyle(header);
    console.log("\n%c📋 HEADER DETAILS:", "color: lightblue; font-size: 14px; font-weight: bold");
    console.table({
      'Display': headerStyles.display,
      'Flex Direction': headerStyles.flexDirection,
      'Gap': headerStyles.gap,
      'Width': header.offsetWidth + 'px',
      'Height': header.offsetHeight + 'px',
      'Children Count': header.children.length
    });
    
    console.log("%cHeader children:", "color: lightblue");
    Array.from(header.children).forEach((child, i) => {
      console.log(`  ${i + 1}. ${child.className} (${child.tagName})`);
    });
    
    header.style.outline = '3px solid blue';
  }
  
  // If row2 exists
  if (row2) {
    const row2Styles = getComputedStyle(row2);
    console.log("\n%c📊 ROW 2 DETAILS:", "color: orange; font-size: 14px; font-weight: bold");
    console.table({
      'Display': row2Styles.display,
      'Width': row2.offsetWidth + 'px',
      'Height': row2.offsetHeight + 'px',
      'Children Count': row2.children.length
    });
    
    console.log("%cRow 2 children:", "color: orange");
    Array.from(row2.children).forEach((child, i) => {
      console.log(`  ${i + 1}. ${child.className} (${child.tagName})`);
      if (child.classList.contains('scorecard')) {
        console.log(`     ✅ SCORECARD FOUND AS CHILD ${i + 1}!`);
      }
    });
    
    row2.style.outline = '3px solid orange';
  }
  
  // If scorecard exists
  if (scorecard) {
    const scorecardStyles = getComputedStyle(scorecard);
    console.log("\n%c💳 SCORECARD DETAILS:", "color: lime; font-size: 14px; font-weight: bold");
    console.table({
      'Display': scorecardStyles.display,
      'Visibility': scorecardStyles.visibility,
      'Opacity': scorecardStyles.opacity,
      'Width': scorecard.offsetWidth + 'px',
      'Height': scorecard.offsetHeight + 'px',
      'Background': scorecardStyles.background,
      'Position': scorecardStyles.position
    });
    
    const rect = scorecard.getBoundingClientRect();
    console.log("\n%cScorecard Position:", "color: lime");
    console.table({
      'Top': rect.top + 'px',
      'Left': rect.left + 'px',
      'Right': rect.right + 'px',
      'Bottom': rect.bottom + 'px',
      'Visible in viewport': (rect.top >= 0 && rect.left >= 0 && rect.bottom <= window.innerHeight && rect.right <= window.innerWidth) ? '✅ YES' : '❌ NO'
    });
    
    console.log("\n%cScorecard innerHTML preview:", "color: lime");
    console.log(scorecard.innerHTML.substring(0, 200) + '...');
    
    scorecard.style.outline = '5px solid lime';
    scorecard.style.outlineOffset = '2px';
    console.log("%c🟢 Lime outline added to scorecard", "color: lime; font-weight: bold");
  } else {
    console.log("\n%c❌ SCORECARD NOT FOUND!", "color: red; font-size: 16px; font-weight: bold");
    console.log("Checking for any elements with 'score' in className...");
    
    const scoreElements = document.querySelectorAll('[class*="score"]');
    console.log(`Found ${scoreElements.length} elements with 'score' in className:`);
    scoreElements.forEach((el, i) => {
      console.log(`  ${i + 1}. ${el.className} (${el.tagName})`);
    });
  }
  
  // Check for Vue component errors
  console.log("\n%c⚠️ CHECKING FOR ERRORS:", "color: red; font-size: 14px; font-weight: bold");
  const errors = document.querySelectorAll('[data-v-error], .error');
  if (errors.length > 0) {
    console.log(`Found ${errors.length} error elements:`);
    errors.forEach((err, i) => {
      console.log(`  ${i + 1}.`, err);
    });
  } else {
    console.log("No obvious error elements found");
  }
  
  console.log("\n%c✅ Debug complete! Check outlines on page.", "color: lime; font-size: 14px; font-weight: bold");
  console.log("%cLook for: 🔵 Blue (header) | 🟠 Orange (row 2) | 🟢 Lime (scorecard)", "color: white");
})();

