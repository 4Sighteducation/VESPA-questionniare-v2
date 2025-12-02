/**
 * Activities Composable
 * Handles activity catalog, assignment, and management
 */

import { ref } from 'vue';
import supabase from '../supabaseClient';

// Store state on window to bypass IIFE scoping completely
if (!window.__VESPAActivitiesState) {
  window.__VESPAActivitiesState = {
    allActivities: ref([]),
    isLoadingActivities: ref(false)
  };
}
const state = window.__VESPAActivitiesState;

/**
 * Mark activity as complete (staff override)
 */
const markActivityComplete = async (responseId, studentEmail, activityId, staffEmail) => {
  try {
    const { data, error } = await supabase
      .from('activity_responses')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        updated_at: new Date().toISOString()
      })
      .eq('id', responseId)
      .select()
      .single();

    if (error) throw error;

    // Log action
    await supabase
      .from('activity_history')
      .insert({
        student_email: studentEmail,
        activity_id: activityId,
        action: 'marked_complete',
        triggered_by: 'staff',
        triggered_by_email: staffEmail,
        metadata: { note: 'Staff override - marked complete' }
      });

    console.log('✅ Activity marked complete by staff:', responseId);
    return data;

  } catch (err) {
    console.error('Failed to mark activity complete:', err);
    throw err;
  }
};

/**
 * Mark activity as incomplete (staff override)
 */
const markActivityIncomplete = async (responseId, studentEmail, activityId, staffEmail) => {
  try {
    const { data, error } = await supabase
      .from('activity_responses')
      .update({
        status: 'in_progress', // Changed from 'assigned'
        completed_at: null,
        updated_at: new Date().toISOString()
      })
      .eq('id', responseId)
      .select()
      .single();

    if (error) throw error;

    // Log action
    await supabase
      .from('activity_history')
      .insert({
        student_email: studentEmail,
        activity_id: activityId,
        action: 'marked_incomplete',
        triggered_by: 'staff',
        triggered_by_email: staffEmail,
        metadata: { note: 'Staff override - marked incomplete' }
      });

    console.log('✅ Activity marked incomplete by staff:', responseId);
    return data;

  } catch (err) {
    console.error('Failed to mark activity incomplete:', err);
    throw err;
  }
};

export function useActivities() {
  /**
   * Load all available activities from catalog
   */
  const loadAllActivities = async () => {
    if (state.allActivities.value.length > 0) {
      return state.allActivities.value; // Already loaded
    }

    state.isLoadingActivities.value = true;

    try {
      const { data, error } = await supabase
        .from('activities')
        .select('*')
        .eq('is_active', true)
        .order('vespa_category, level, display_order');

      if (error) throw error;

      state.allActivities.value = data || [];
      console.log(`✅ Loaded ${state.allActivities.value.length} activities`);
      
      return state.allActivities.value;

    } catch (err) {
      console.error('Failed to load activities:', err);
      throw err;
    } finally {
      state.isLoadingActivities.value = false;
    }
  };

  /**
   * Assign activity to student (uses Flask API to create notifications)
   */
  const assignActivity = async (studentEmail, activityId, staffEmail, cycleNumber = 1, schoolId) => {
    try {
      console.log('📝 Assigning activity:', { studentEmail, activityId, staffEmail, schoolId, cycleNumber });
      
      // Use Flask API endpoint (creates notifications!)
      const API_BASE_URL = import.meta.env.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';
      
      const response = await fetch(`${API_BASE_URL}/api/staff/assign-activity`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          staffEmail: staffEmail,
          studentEmail: studentEmail,
          activityIds: [activityId],
          cycle: cycleNumber,
          reason: 'Staff assigned'
        })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to assign activity');
      }

      const data = await response.json();
      console.log('✅ Activity assigned successfully (via API):', data);
      
      // Return the first assigned activity
      return data.assigned?.[0] || data;

    } catch (err) {
      console.error('❌ Failed to assign activity:', err);
      throw err;
    }
  };

  /**
   * Bulk assign activities to multiple students
   * Uses single assignment RPC in loop (more reliable than bulk RPC)
   */
  const bulkAssignActivities = async (studentEmails, activityIds, staffEmail, schoolId, cycleNumber = 1) => {
    try {
      console.log('📝 Bulk assigning:', { studentEmails, activityIds, staffEmail, schoolId });
      
      let successCount = 0;
      let errorCount = 0;
      
      // Use single assignment RPC for each combination
      for (const studentEmail of studentEmails) {
        for (const activityId of activityIds) {
          try {
            await assignActivity(studentEmail, activityId, staffEmail, cycleNumber, schoolId);
            successCount++;
          } catch (err) {
            console.warn(`Failed to assign ${activityId} to ${studentEmail}:`, err.message);
            errorCount++;
          }
        }
      }

      console.log(`✅ Bulk assignment complete: ${successCount} successful, ${errorCount} failed`);
      
      if (errorCount > 0 && successCount === 0) {
        throw new Error(`All ${errorCount} assignments failed`);
      }
      
      return successCount;

    } catch (err) {
      console.error('❌ Failed to bulk assign:', err);
      throw err;
    }
  };

  /**
   * Remove activity from student
   */
  const removeActivity = async (studentEmail, activityId, cycleNumber, staffEmail, schoolId) => {
    try {
      console.log('🗑️ Removing activity via RPC (preserves responses):', { studentEmail, activityId, cycleNumber, staffEmail, schoolId });
      
      // Use RPC to bypass RLS (just like assignment)
      const { data, error } = await supabase.rpc('remove_activity_from_student', {
        p_student_email: studentEmail,
        p_activity_id: activityId,
        p_cycle_number: cycleNumber,
        p_staff_email: staffEmail,
        p_school_id: schoolId
      });

      if (error) {
        console.error('❌ RPC error:', error);
        console.error('❌ Make sure remove_activity_from_student RPC function exists in Supabase');
        throw error;
      }

      console.log('✅ Activity marked as removed via RPC (data preserved):', data);

      // Log the removal action
      try {
        await supabase
          .from('activity_history')
          .insert({
            student_email: studentEmail,
            activity_id: activityId,
            action: 'removed',
            triggered_by: 'staff',
            triggered_by_email: staffEmail,
            cycle_number: cycleNumber,
            metadata: { school_id: schoolId }
          });
      } catch (historyError) {
        console.warn('⚠️ Failed to log removal to history (non-critical):', historyError);
      }

      return data;

    } catch (err) {
      console.error('❌ Failed to remove activity:', err);
      throw err;
    }
  };

  /**
   * LEGACY: Direct update method (blocked by RLS)
   */
  const removeActivityDirect = async (studentEmail, activityId, cycleNumber, staffEmail) => {
    try {
      console.log('🗑️ Removing activity (direct):', { studentEmail, activityId, cycleNumber });
      
      // Update status to 'removed'
      const { data, error } = await supabase
        .from('activity_responses')
        .update({ status: 'removed', updated_at: new Date().toISOString() })
        .eq('student_email', studentEmail)
        .eq('activity_id', activityId)
        .eq('cycle_number', cycleNumber)
        .select();

      if (error) {
        console.error('❌ Supabase update error:', error);
        throw error;
      }

      console.log('✅ Database updated:', data);

      // Log action
      const { error: historyError } = await supabase
        .from('activity_history')
        .insert({
          student_email: studentEmail,
          activity_id: activityId,
          action: 'removed',
          triggered_by: 'staff',
          triggered_by_email: staffEmail,
          cycle_number: cycleNumber
        });

      console.log('✅ Activity removed:', { studentEmail, activityId });

    } catch (err) {
      console.error('Failed to remove activity:', err);
      throw err;
    }
  };

  /**
   * Load activity questions
   */
  const loadActivityQuestions = async (activityId) => {
    try {
      const { data, error } = await supabase
        .from('activity_questions')
        .select('*')
        .eq('activity_id', activityId)
        .eq('is_active', true)
        .eq('show_in_final_questions', false) // Exclude rating questions
        .order('display_order');

      if (error) throw error;

      console.log(`📋 Loaded ${data?.length || 0} questions for activity ${activityId}`);
      return data || [];

    } catch (err) {
      console.error('Failed to load questions:', err);
      return [];
    }
  };

  /**
   * Get activities grouped by category
   */
  const getActivitiesByCategory = () => {
    const categories = ['Vision', 'Effort', 'Systems', 'Practice', 'Attitude'];
    const grouped = {};

    categories.forEach(cat => {
      grouped[cat] = state.allActivities.value.filter(a => a.vespa_category === cat);
    });

    return grouped;
  };

  /**
   * Filter activities by search term, category, level
   */
  const filterActivities = (filters = {}) => {
    let filtered = state.allActivities.value;

    if (filters.search) {
      const term = filters.search.toLowerCase();
      filtered = filtered.filter(a => 
        a.name.toLowerCase().includes(term) ||
        a.curriculum_tags?.some(tag => tag.toLowerCase().includes(term))
      );
    }

    if (filters.category && filters.category !== 'all') {
      filtered = filtered.filter(a => a.vespa_category === filters.category);
    }

    if (filters.level && filters.level !== 'all') {
      filtered = filtered.filter(a => a.level === filters.level);
    }

    return filtered;
  };

  /**
   * Permanently delete activity response (deletes all data!)
   */
  const deleteActivityPermanently = async (studentEmail, activityId, cycleNumber, staffEmail, schoolId) => {
    try {
      console.log('🗑️ PERMANENTLY DELETING activity via RPC:', { studentEmail, activityId, cycleNumber, staffEmail, schoolId });
      
      // Use RPC to bypass RLS
      const { data, error } = await supabase.rpc('delete_activity_permanently', {
        p_student_email: studentEmail,
        p_activity_id: activityId,
        p_cycle_number: cycleNumber,
        p_staff_email: staffEmail,
        p_school_id: schoolId
      });

      if (error) {
        console.error('❌ RPC error deleting:', error);
        throw error;
      }

      console.log('✅ Activity permanently deleted via RPC:', data);
      return data;

    } catch (err) {
      console.error('❌ Failed to delete activity:', err);
      throw err;
    }
  };

  return {
    allActivities: state.allActivities,
    isLoadingActivities: state.isLoadingActivities,
    loadAllActivities,
    assignActivity,
    bulkAssignActivities,
    removeActivity,
    deleteActivityPermanently,
    loadActivityQuestions,
    getActivitiesByCategory,
    filterActivities,
    markActivityComplete,
    markActivityIncomplete
  };
}

// Export individual functions that were referenced in useFeedback
export { markActivityComplete, markActivityIncomplete };

