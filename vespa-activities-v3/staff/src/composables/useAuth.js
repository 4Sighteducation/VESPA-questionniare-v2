/**
 * Authentication Composable
 * Handles Knack authentication check and staff context
 */

import { ref, computed } from 'vue';

const ACCOUNT_API_URL = import.meta.env.VITE_ACCOUNT_API_URL || 'https://vespa-upload-api-07e11c285370.herokuapp.com';

// Global state (shared across components)
const isAuthenticated = ref(false);
const staffContext = ref(null);
const currentUser = ref(null);

export function useAuth() {
  const isLoading = ref(false);
  const error = ref(null);

  /**
   * Check authentication with Knack
   * Gets user info from Knack session and validates with Account Management API
   */
  const checkAuth = async () => {
    isLoading.value = true;
    error.value = null;

    try {
      // Check if Knack is available
      if (typeof Knack === 'undefined' || !Knack.session || !Knack.session.user) {
        throw new Error('Not logged into Knack. Please log in first.');
      }

      const user = Knack.session.user;
      const userEmail = user.email || user.values?.field_70?.email || user.values?.email?.email;
      const userId = user.id;

      if (!userEmail) {
        throw new Error('Could not extract email from Knack session');
      }

      console.log('🔐 Checking auth for:', userEmail);

      // Call Account Management API to get staff context
      const response = await fetch(
        `${ACCOUNT_API_URL}/api/v3/accounts/auth/check?userEmail=${encodeURIComponent(userEmail)}&userId=${encodeURIComponent(userId)}`
      );

      if (!response.ok) {
        throw new Error('Failed to verify authentication');
      }

      const authData = await response.json();
      console.log('Auth response:', authData);

      // Check if user is staff (has appropriate profiles)
      const isStaff = authData.profiles && (
        authData.profiles.includes('staff_admin') ||
        authData.profiles.includes('tutor') ||
        authData.profiles.includes('head_of_year') ||
        authData.profiles.includes('subject_teacher') ||
        authData.isSuperUser
      );

      if (!isStaff) {
        throw new Error('Access denied. This dashboard is for staff members only.');
      }

      // Store auth data
      currentUser.value = {
        email: userEmail,
        userId: userId,
        profiles: authData.profiles || [],
        isSuperUser: authData.isSuperUser || false
      };

      staffContext.value = {
        schoolId: authData.schoolContext?.schoolId,
        schoolName: authData.schoolContext?.customerName,
        customerId: authData.schoolContext?.customerId,
        isSuperUser: authData.isSuperUser || false,
        roles: authData.profiles || []
      };

      isAuthenticated.value = true;
      
      console.log('✅ Authentication successful:', {
        email: userEmail,
        school: staffContext.value.schoolName,
        roles: staffContext.value.roles
      });

    } catch (err) {
      console.error('❌ Authentication error:', err);
      error.value = err.message;
      isAuthenticated.value = false;
      throw err;
    } finally {
      isLoading.value = false;
    }
  };

  /**
   * Check if user has specific role
   */
  const hasRole = (role) => {
    return staffContext.value?.roles?.includes(role) || staffContext.value?.isSuperUser;
  };

  /**
   * Get current staff member's email
   */
  const getStaffEmail = () => {
    return currentUser.value?.email;
  };

  return {
    isAuthenticated,
    isLoading,
    error,
    staffContext,
    currentUser,
    checkAuth,
    hasRole,
    getStaffEmail
  };
}

