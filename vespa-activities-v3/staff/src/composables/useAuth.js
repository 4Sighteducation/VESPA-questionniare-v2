/**
 * Authentication Composable
 * SIMPLE: Just get user from Knack session (already authenticated!)
 */

import { ref } from 'vue';

// Global state (shared across components)
const isAuthenticated = ref(true); // Always true - if you're on the page, you're authenticated!
const staffContext = ref(null);
const currentUser = ref(null);
const isLoading = ref(false);
const error = ref(null);

export function useAuth() {

  /**
   * Get user info from Knack session and school context from API
   */
  const checkAuth = async () => {
    try {
      // Get user from Knack session
      const user = Knack.session.user;
      const userEmail = user.email || user.values?.field_70?.email || user.values?.email?.email;
      
      console.log('✅ Logged in as:', userEmail);

      // Get profile keys to determine roles
      const profileKeys = user.profile_keys || [];
      const roles = [];
      if (profileKeys.includes('profile_5')) roles.push('staff_admin');
      if (profileKeys.includes('profile_7')) roles.push('tutor');
      if (profileKeys.includes('profile_18')) roles.push('head_of_year');
      if (profileKeys.includes('profile_78')) roles.push('subject_teacher');
      const isSuperUser = profileKeys.includes('profile_21') || userEmail === 'tony@vespa.academy';

      // CRITICAL: Get proper school context from auth check endpoint
      console.log('🔐 Calling auth check endpoint...');
      const authResponse = await fetch(
        `https://vespa-upload-api-07e11c285370.herokuapp.com/api/v3/accounts/auth/check?` +
        `userEmail=${encodeURIComponent(userEmail)}&userId=${user.id}`
      );
      
      if (!authResponse.ok) {
        throw new Error(`Auth check failed: ${authResponse.status}`);
      }
      
      const authData = await authResponse.json();
      
      if (!authData.success) {
        throw new Error('Auth check returned unsuccessful');
      }
      
      console.log('✅ Auth check response:', authData);

      // Store user data
      currentUser.value = {
        email: userEmail,
        userId: user.id,
        profiles: roles,
        isSuperUser: authData.isSuperUser || isSuperUser
      };

      // Get school context from API (has the Supabase UUID!)
      staffContext.value = {
        schoolId: authData.schoolContext?.schoolId || null,  // Supabase UUID!
        customerId: authData.schoolContext?.customerId || null,  // Knack ID
        schoolName: authData.schoolContext?.customerName || 'Unknown School',
        isSuperUser: authData.isSuperUser || isSuperUser,
        roles: roles
      };

      isAuthenticated.value = true;
      console.log('✅ Ready to load data for:', userEmail, 'School:', staffContext.value.schoolName);

    } catch (err) {
      console.error('❌ Error getting auth context:', err);
      isAuthenticated.value = false;
      throw err;
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

