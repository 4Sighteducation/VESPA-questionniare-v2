/**
 * VESPA Score Calculator
 * Uses the production thresholds from reverse_vespa_calculator.py
 * Converts statement scores (1-5) to VESPA scores (1-10)
 */

// Production thresholds from reverse_vespa_calculator.py
const thresholds = {
  VISION: [
    [0, 2.26],      // VESPA 1
    [2.26, 2.7],    // VESPA 2
    [2.7, 3.02],    // VESPA 3
    [3.02, 3.33],   // VESPA 4
    [3.33, 3.52],   // VESPA 5
    [3.52, 3.84],   // VESPA 6
    [3.84, 4.15],   // VESPA 7
    [4.15, 4.47],   // VESPA 8
    [4.47, 4.79],   // VESPA 9
    [4.79, 5.01]    // VESPA 10 (5.01 to catch 5.0)
  ],
  EFFORT: [
    [0, 2.42],      // VESPA 1
    [2.42, 2.73],   // VESPA 2
    [2.73, 3.04],   // VESPA 3
    [3.04, 3.36],   // VESPA 4
    [3.36, 3.67],   // VESPA 5
    [3.67, 3.86],   // VESPA 6
    [3.86, 4.17],   // VESPA 7
    [4.17, 4.48],   // VESPA 8
    [4.48, 4.8],    // VESPA 9
    [4.8, 5.01]     // VESPA 10
  ],
  SYSTEMS: [
    [0, 2.36],      // VESPA 1
    [2.36, 2.76],   // VESPA 2
    [2.76, 3.16],   // VESPA 3
    [3.16, 3.46],   // VESPA 4
    [3.46, 3.75],   // VESPA 5
    [3.75, 4.05],   // VESPA 6
    [4.05, 4.35],   // VESPA 7
    [4.35, 4.64],   // VESPA 8
    [4.64, 4.94],   // VESPA 9
    [4.94, 5.01]    // VESPA 10
  ],
  PRACTICE: [
    [0, 1.74],      // VESPA 1
    [1.74, 2.1],    // VESPA 2
    [2.1, 2.46],    // VESPA 3
    [2.46, 2.74],   // VESPA 4
    [2.74, 3.02],   // VESPA 5
    [3.02, 3.3],    // VESPA 6
    [3.3, 3.66],    // VESPA 7
    [3.66, 3.94],   // VESPA 8
    [3.94, 4.3],    // VESPA 9
    [4.3, 5.01]     // VESPA 10
  ],
  ATTITUDE: [
    [0, 2.31],      // VESPA 1
    [2.31, 2.72],   // VESPA 2
    [2.72, 3.01],   // VESPA 3
    [3.01, 3.3],    // VESPA 4
    [3.3, 3.53],    // VESPA 5
    [3.53, 3.83],   // VESPA 6
    [3.83, 4.06],   // VESPA 7
    [4.06, 4.35],   // VESPA 8
    [4.35, 4.7],    // VESPA 9
    [4.7, 5.01]     // VESPA 10
  ]
}

/**
 * Calculate VESPA score for a category based on average statement score
 */
function calculateCategoryScore(average, category) {
  const categoryThresholds = thresholds[category]
  
  if (!categoryThresholds) {
    console.error(`Unknown category: ${category}`)
    return 1
  }

  // Find which VESPA score (1-10) this average falls into
  for (let i = 0; i < categoryThresholds.length; i++) {
    const [lower, upper] = categoryThresholds[i]
    if (average >= lower && average < upper) {
      return i + 1 // VESPA scores are 1-indexed
    }
  }

  // If we get here, average is >= 5.0, return 10
  return 10
}

/**
 * Calculate all VESPA scores from question responses
 * @param {Object} responses - Object mapping question IDs to response values (1-5)
 * @param {Array} questions - Array of question objects with id, category, etc.
 * @returns {Object} - VESPA scores, averages, and metadata
 */
export function calculateVespaScores(responses, questions) {
  // Group responses by category (excluding OUTCOME questions)
  const categoryResponses = {
    VISION: [],
    EFFORT: [],
    SYSTEMS: [],
    PRACTICE: [],
    ATTITUDE: []
  }

  // Separate outcome responses
  const outcomeResponses = {
    OUTCOME: []
  }

  // Group responses
  questions.forEach(question => {
    const response = responses[question.id]
    if (response !== undefined && response !== null) {
      if (question.category === 'OUTCOME') {
        outcomeResponses.OUTCOME.push(response)
      } else if (categoryResponses[question.category]) {
        categoryResponses[question.category].push(response)
      }
    }
  })

  // Calculate averages for each category
  const categoryAverages = {}
  for (const [category, values] of Object.entries(categoryResponses)) {
    if (values.length > 0) {
      categoryAverages[category] = values.reduce((sum, val) => sum + val, 0) / values.length
    } else {
      categoryAverages[category] = 0
    }
  }

  // Calculate VESPA scores (1-10) from averages
  const vespaScores = {}
  for (const [category, average] of Object.entries(categoryAverages)) {
    vespaScores[category] = calculateCategoryScore(average, category)
  }

  // Calculate overall score (average of all 5 VESPA scores)
  const vespaValues = Object.values(vespaScores)
  const overallScore = vespaValues.length > 0 
    ? Math.round((vespaValues.reduce((sum, val) => sum + val, 0) / vespaValues.length) * 10) / 10
    : 0

  // Calculate outcome average (doesn't affect VESPA scores but we track it)
  const outcomeAverage = outcomeResponses.OUTCOME.length > 0
    ? outcomeResponses.OUTCOME.reduce((sum, val) => sum + val, 0) / outcomeResponses.OUTCOME.length
    : 0

  return {
    vespaScores: {
      ...vespaScores,
      OVERALL: Math.round(overallScore)
    },
    categoryAverages,
    outcomeAverage,
    questionCounts: {
      VISION: categoryResponses.VISION.length,
      EFFORT: categoryResponses.EFFORT.length,
      SYSTEMS: categoryResponses.SYSTEMS.length,
      PRACTICE: categoryResponses.PRACTICE.length,
      ATTITUDE: categoryResponses.ATTITUDE.length,
      OUTCOME: outcomeResponses.OUTCOME.length
    }
  }
}

/**
 * Validate that all required questions are answered
 */
export function validateResponses(responses, questions) {
  const errors = []
  
  // Check that all questions have responses
  const vespaQuestions = questions.filter(q => q.category !== 'OUTCOME')
  const unansweredVespa = vespaQuestions.filter(q => !responses[q.id])
  
  if (unansweredVespa.length > 0) {
    errors.push(`Please answer all VESPA questions (${unansweredVespa.length} remaining)`)
  }

  // Outcome questions are optional but good to have
  const outcomeQuestions = questions.filter(q => q.category === 'OUTCOME')
  const unansweredOutcome = outcomeQuestions.filter(q => !responses[q.id])
  
  if (unansweredOutcome.length > 0) {
    errors.push(`Please answer the outcome questions (${unansweredOutcome.length} remaining)`)
  }

  // Validate response values are in range
  for (const [questionId, value] of Object.entries(responses)) {
    if (value < 1 || value > 5) {
      errors.push(`Invalid response for question ${questionId}: ${value}`)
    }
  }

  return {
    valid: errors.length === 0,
    errors,
    completionRate: (Object.keys(responses).length / questions.length) * 100
  }
}
