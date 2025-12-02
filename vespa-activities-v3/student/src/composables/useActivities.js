/**
 * useActivities Composable
 * Manages activity state and operations
 */

import { ref, computed } from 'vue';
import ActivityService from '../services/activityService';

export function useActivities(studentEmail) {
  // State
  const recommendedActivities = ref([]);
  const myActivities = ref([]);
  const allActivities = ref([]);
  const loading = ref(false);
  const error = ref(null);
  
  // Computed
  const myActivityIds = computed(() => {
    return myActivities.value.map(a => a.activity_id || a.id);
  });
  
  const completedActivityIds = computed(() => {
    return myActivities.value
      .filter(a => a.progress?.status === 'completed')
      .map(a => a.activity_id || a.id);
  });
  
  const inProgressActivityIds = computed(() => {
    return myActivities.value
      .filter(a => a.progress?.status === 'in_progress')
      .map(a => a.activity_id || a.id);
  });
  
  // Methods
  const fetchRecommendedActivities = async (cycle = 1) => {
    try {
      loading.value = true;
      error.value = null;
      
      const data = await ActivityService.getRecommendedActivities(studentEmail, cycle);
      recommendedActivities.value = data.recommended || [];
      
      console.log('[useActivities] Fetched recommended activities:', recommendedActivities.value.length);
    } catch (err) {
      console.error('[useActivities] Error fetching recommended:', err);
      error.value = err.message;
      throw err;
    } finally {
      loading.value = false;
    }
  };
  
  const fetchMyActivities = async (cycle = 1) => {
    try {
      loading.value = true;
      error.value = null;
      
      const assignments = await ActivityService.getMyActivities(studentEmail, cycle);
      myActivities.value = assignments || [];
      
      console.log('[useActivities] Fetched my activities:', myActivities.value.length);
    } catch (err) {
      console.error('[useActivities] Error fetching my activities:', err);
      error.value = err.message;
      throw err;
    } finally {
      loading.value = false;
    }
  };
  
  const fetchAllActivities = async (filters = {}) => {
    try {
      loading.value = true;
      error.value = null;
      
      const activities = await ActivityService.getAllActivities(filters);
      allActivities.value = activities || [];
      
      console.log('[useActivities] Fetched all activities:', allActivities.value.length);
    } catch (err) {
      console.error('[useActivities] Error fetching all activities:', err);
      error.value = err.message;
      throw err;
    } finally {
      loading.value = false;
    }
  };
  
  const addActivity = async (activityId, selectedVia = 'student_choice', cycle = 1) => {
    try {
      console.log('[useActivities] Adding activity to dashboard:', activityId);
      
      await ActivityService.startActivity(studentEmail, activityId, selectedVia, cycle);
      
      // Refresh my activities
      await fetchMyActivities(cycle);
      
      console.log('[useActivities] ✅ Activity added successfully');
    } catch (err) {
      console.error('[useActivities] Error adding activity:', err);
      throw err;
    }
  };
  
  const removeActivity = async (activityId, cycle = 1) => {
    try {
      console.log('[useActivities] Removing activity from dashboard:', activityId);
      
      // Call API to mark as removed (soft delete)
      await ActivityService.removeActivity(studentEmail, activityId, cycle);
      
      // Refresh my activities
      await fetchMyActivities(cycle);
      
      console.log('[useActivities] ✅ Activity removed successfully');
    } catch (err) {
      console.error('[useActivities] Error removing activity:', err);
      throw err;
    }
  };
  
  const isActivityInDashboard = (activityId) => {
    return myActivityIds.value.includes(activityId);
  };
  
  const isActivityCompleted = (activityId) => {
    return completedActivityIds.value.includes(activityId);
  };
  
  const isActivityInProgress = (activityId) => {
    return inProgressActivityIds.value.includes(activityId);
  };
  
  return {
    // State
    recommendedActivities,
    myActivities,
    allActivities,
    loading,
    error,
    
    // Computed
    myActivityIds,
    completedActivityIds,
    inProgressActivityIds,
    
    // Methods
    fetchRecommendedActivities,
    fetchMyActivities,
    fetchAllActivities,
    addActivity,
    removeActivity,
    isActivityInDashboard,
    isActivityCompleted,
    isActivityInProgress
  };
}

export default useActivities;


