/**
 * Knack Authentication Service
 * Gets current logged-in user from Knack
 */

export function getKnackUser() {
  // Check if Knack is available
  if (typeof window.Knack === 'undefined') {
    console.warn('[KnackAuth] Knack not available - using test mode')
    return {
      email: 'test@example.com',
      name: 'Test User',
      id: 'test_user_id',
      isTestMode: true
    }
  }

  try {
    const user = window.Knack.getUserAttributes()
    
    if (!user || !user.email) {
      throw new Error('No user logged in')
    }

    return {
      email: user.email,
      name: user.name || user.values?.field_11 || 'Student',
      id: user.id,
      accountId: user.values?.id || user.id,
      isTestMode: false
    }
  } catch (error) {
    console.error('[KnackAuth] Error getting user:', error)
    throw new Error('Unable to identify user. Please make sure you are logged in.')
  }
}

export function isKnackAvailable() {
  return typeof window.Knack !== 'undefined' && window.Knack.getUserAttributes
}

