/**
 * KnackAppLoader Integration Config for VESPA Questionnaire V2
 * 
 * Add this to your KnackAppLoader(copy).js in the APPS object
 * Location: Around line 1434 (after curriculumResources)
 */

'questionnaireV2': {
    scenes: ['scene_1282'],
    views: ['view_3247'],
    scriptUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/dist/questionnaire.js',
    cssUrl: 'https://cdn.jsdelivr.net/gh/4Sighteducation/VESPA-questionniare-v2@main/dist/questionnaire.css',
    configBuilder: (baseConfig, sceneKey, viewKey) => ({
        ...baseConfig,
        appType: 'questionnaireV2',
        sceneKey: sceneKey,
        viewKey: viewKey,
        debugMode: false, // Set to true for development
        elementSelector: '#view_3247',
        renderMode: 'replace', // Replace the rich text view content
        hideOriginalView: true,
        // Backend API configuration
        apiUrl: 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com',
        // Knack credentials (already in baseConfig but explicit here)
        knackAppId: '5ee90912c38ae7001510c1a9',
        knackApiKey: '8f733aa5-dd35-4464-8348-64824d1f5f0d'
    }),
    configGlobalVar: 'QUESTIONNAIRE_V2_CONFIG',
    initializerFunctionName: 'initializeQuestionnaireV2'
}

/**
 * USAGE NOTES:
 * 
 * 1. The Vue app will mount in #view_3247 when user navigates to #vespaquestionniare/
 * 
 * 2. Flow:
 *    - User clicks "VESPA Questionnaire" in GeneralHeader
 *    - OR navigates directly to #vespaquestionniare/
 *    - KnackAppLoader loads this app in scene_1282/view_3247
 *    - Vue app takes over: validation → instructions → questions → submit
 * 
 * 3. Dependencies:
 *    - Backend API must be deployed (endpoints in app.py)
 *    - Supabase schema must be updated (run quick_fix_students.sql)
 *    - GitHub repo must have dist/ folder with built files
 * 
 * 4. Testing:
 *    - Navigate to: https://vespaacademy.knack.com/vespa-academy#vespaquestionniare/
 *    - Should load immediately, check eligibility, show instructions or errors
 * 
 * 5. Rollback:
 *    - Set debugMode: true and check console
 *    - OR comment out this entire config block to disable
 *    - Old questionnaire (#add-q) remains untouched as fallback
 */

/**
 * OPTIONAL: Update questionnaireValidator.js
 * 
 * If you want to keep the validator but redirect to new questionnaire:
 * 
 * Line 769 in questionnaireValidator.js:
 * 
 * OLD:
 * const questionnaireUrl = `#add-q/questionnaireqs/${validationResult.userRecord.id}`;
 * 
 * NEW:
 * const questionnaireUrl = `#vespaquestionniare/?userId=${validationResult.userRecord.id}&cycle=${validationResult.cycleNumber}`;
 * 
 * This makes the validator redirect to the new Vue app instead of KSense questionnaire.
 */

/**
 * OPTIONAL: Update GeneralHeader.js Navigation
 * 
 * Line 678 in GeneralHeader.js (student navigation):
 * 
 * OLD:
 * { label: 'VESPA Questionnaire', icon: 'fa-question-circle', href: '#add-q', scene: 'scene_358' },
 * 
 * NEW:
 * { label: 'VESPA Questionnaire', icon: 'fa-question-circle', href: '#vespaquestionniare/', scene: 'scene_1282' },
 * 
 * This makes the header button go directly to new questionnaire.
 */

