/**
 * API Service for VESPA Questionnaire
 * Handles all communication with the Dashboard backend
 */

const API_BASE_URL = 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com'

/**
 * Validate if student can take the questionnaire
 */
export async function validateQuestionnaireAccess(email, accountId) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/vespa/questionnaire/validate?email=${encodeURIComponent(email)}&accountId=${encodeURIComponent(accountId)}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.message || 'Validation failed')
    }

    return await response.json()
  } catch (error) {
    console.error('[API] Validation error:', error)
    throw error
  }
}

/**
 * Submit questionnaire responses
 */
export async function submitQuestionnaire(data) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/vespa/questionnaire/submit`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(data)
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.message || 'Submission failed')
    }

    return await response.json()
  } catch (error) {
    console.error('[API] Submission error:', error)
    throw error
  }
}

/**
 * Get student's current status
 */
export async function getStudentStatus(email) {
  try {
    const response = await fetch(`${API_BASE_URL}/api/vespa/questionnaire/status?email=${encodeURIComponent(email)}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json'
      }
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.message || 'Status check failed')
    }

    return await response.json()
  } catch (error) {
    console.error('[API] Status check error:', error)
    throw error
  }
}

