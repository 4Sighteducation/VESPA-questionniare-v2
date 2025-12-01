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
   * Assign activity to student (uses RPC to bypass RLS)
   */
  const assignActivity = async (studentEmail, activityId, staffEmail, cycleNumber = 1, schoolId) => {
    try {
      console.log('📝 Assigning activity:', { studentEmail, activityId, staffEmail, schoolId, cycleNumber });
      
      // Use RPC function to assign (bypasses RLS)
      const { data, error } = await supabase.rpc('assign_activity_to_student', {
        p_student_email: studentEmail,
        p_activity_id: activityId,
        p_staff_email: staffEmail,
        p_school_id: schoolId,
        p_cycle_number: cycleNumber
      });

      if (error) {
        console.error('❌ RPC Error:', error);
        throw error;
      }

      console.log('✅ Activity assigned successfully:', data);
      return data;

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
  const removeActivity = async (studentEmail, activityId, cycleNumber, staffEmail) => {
    try {
      // Update status to 'removed'
      const { error } = await supabase
        .from('activity_responses')
        .update({ status: 'removed', updated_at: new Date().toISOString() })
        .eq('student_email', studentEmail)
        .eq('activity_id', activityId)
        .eq('cycle_number', cycleNumber);

      if (error) throw error;

      // Log action
      await supabase
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

  return {
    allActivities: state.allActivities,
    isLoadingActivities: state.isLoadingActivities,
    loadAllActivities,
    assignActivity,
    bulkAssignActivities,
    removeActivity,
    loadActivityQuestions,
    getActivitiesByCategory,
    filterActivities,
    markActivityComplete,
    markActivityIncomplete
  };
}

// Export individual functions that were referenced in useFeedback
export { markActivityComplete, markActivityIncomplete };

