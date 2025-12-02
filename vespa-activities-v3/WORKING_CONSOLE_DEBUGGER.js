// === WORKING MODAL POSITIONING DEBUGGER ===
// Copy and paste this ENTIRE block into console

(function debugModal() {
  console.clear();
  console.log("%c🔍 MODAL POSITIONING DEBUGGER", "color: cyan; font-size: 20px; font-weight: bold; background: black; padding: 10px");
  
  // Find elements
  const modal = document.querySelector('.modal-overlay');
  const modalContent = document.querySelector('.modal-large');
  const pdfModal = document.querySelector('.pdf-modal-overlay');
  const workspace = document.querySelector('.student-workspace');
  const header = document.querySelector('.workspace-header-compact');
  const knackHeader = document.getElementById('knack-dist_1');
  
  console.log("\n%c📦 ELEMENTS STATUS:", "color: yellow; font-size: 16px; font-weight: bold");
  const elements = {
    'Modal Overlay': modal ? '✅ FOUND' : '❌ Not open',
    'Modal Content': modalContent ? '✅ FOUND' : '❌ Not open',
    'PDF Modal': pdfModal ? '✅ FOUND' : '❌ Not open',
    'Workspace': workspace ? '✅ FOUND' : '❌ Missing',
    'Workspace Header': header ? '✅ FOUND' : '❌ Missing',
    'Knack Header': knackHeader ? '✅ FOUND' : '❌ Missing'
  };
  console.table(elements);
  
  // Screen info
  console.log("\n%c📐 SCREEN INFO:", "color: lightblue; font-size: 14px; font-weight: bold");
  console.table({
    'Window Width': window.innerWidth + 'px',
    'Window Height': window.innerHeight + 'px',
    'Scroll Y': window.scrollY + 'px'
  });
  
  // If modal is open, analyze it
  if (modal) {
    const modalRect = modal.getBoundingClientRect();
    const modalStyles = getComputedStyle(modal);
    
    console.log("\n%c🪟 MODAL OVERLAY DETAILS:", "color: magenta; font-size: 14px; font-weight: bold");
    console.table({
      'Position': modalStyles.position,
      'Top': modalStyles.top,
      'Left': modalStyles.left,
      'Width': modalRect.width + 'px',
      'Height': modalRect.height + 'px',
      'Z-Index': modalStyles.zIndex,
      'Display': modalStyles.display,
      'Rect Top': modalRect.top + 'px',
      'Rect Bottom': modalRect.bottom + 'px'
    });
    
    // Highlight modal
    modal.style.outline = '5px solid magenta';
    console.log("%c💗 Magenta outline added to modal overlay", "color: magenta; font-weight: bold");
  }
  
  // If modal content exists
  if (modalContent) {
    const contentRect = modalContent.getBoundingClientRect();
    const contentStyles = getComputedStyle(modalContent);
    
    console.log("\n%c📄 MODAL CONTENT DETAILS:", "color: orange; font-size: 14px; font-weight: bold");
    console.table({
      'Width': contentRect.width + 'px',
      'Height': contentRect.height + 'px',
      'Top': contentRect.top + 'px',
      'Bottom': contentRect.bottom + 'px',
      'Visible Top': contentRect.top >= 0 ? '✅ YES' : '❌ HIDDEN ABOVE',
      'Max Height': contentStyles.maxHeight,
      'Overflow': contentStyles.overflow
    });
    
    modalContent.style.outline = '5px solid orange';
    console.log("%c🟠 Orange outline added to modal content", "color: orange; font-weight: bold");
  }
  
  // Knack header check
  if (knackHeader) {
    const knackRect = knackHeader.getBoundingClientRect();
    const knackStyles = getComputedStyle(knackHeader);
    
    console.log("\n%c🎩 KNACK HEADER DETAILS:", "color: yellow; font-size: 14px; font-weight: bold");
    console.table({
      'Height': knackRect.height + 'px',
      'Bottom': knackRect.bottom + 'px',
      'Position': knackStyles.position,
      'Z-Index': knackStyles.zIndex
    });
    
    knackHeader.style.outline = '5px solid yellow';
    console.log("%c🟡 Yellow outline added to Knack header", "color: yellow; font-weight: bold");
  }
  
  // Workspace header check
  if (header) {
    const headerRect = header.getBoundingClientRect();
    const headerStyles = getComputedStyle(header);
    
    console.log("\n%c📋 WORKSPACE HEADER:", "color: lightgreen; font-size: 14px; font-weight: bold");
    console.table({
      'Margin Top': headerStyles.marginTop,
      'Top': headerRect.top + 'px',
      'Z-Index': headerStyles.zIndex,
      'Visible': headerRect.top >= 0 && headerRect.top < window.innerHeight ? '✅ YES' : '❌ NO'
    });
    
    header.style.outline = '5px solid lime';
    console.log("%c🟢 Lime outline added to workspace header", "color: lime; font-weight: bold");
  }
  
  // Calculate overlaps
  if (modal && knackHeader) {
    const modalTop = modal.getBoundingClientRect().top;
    const knackBottom = knackHeader.getBoundingClientRect().bottom;
    const knackZIndex = parseInt(getComputedStyle(knackHeader).zIndex) || 0;
    const modalZIndex = parseInt(getComputedStyle(modal).zIndex) || 0;
    
    console.log("\n%c⚠️ OVERLAP ANALYSIS:", "color: red; font-size: 16px; font-weight: bold");
    console.table({
      'Knack Bottom': knackBottom + 'px',
      'Modal Top': modalTop + 'px',
      'Knack Z-Index': knackZIndex,
      'Modal Z-Index': modalZIndex,
      'Modal Above Knack?': modalZIndex > knackZIndex ? '✅ YES' : '❌ NO - PROBLEM!',
      'Physical Overlap': modalTop < knackBottom ? '❌ YES - OVERLAPPING!' : '✅ No overlap'
    });
  }
  
  console.log("\n%c✅ Debug complete! Check colored outlines on page.", "color: lime; font-size: 14px; font-weight: bold");
  console.log("%cLook for: 💗 Magenta (modal) | 🟠 Orange (content) | 🟡 Yellow (Knack) | 🟢 Lime (workspace)", "color: white");
})();

