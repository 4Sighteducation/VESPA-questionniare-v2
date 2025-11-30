/**
 * Activities Composable
 * Handles activity catalog, assignment, and management
 */

import { ref } from 'vue';
import supabase from '../supabaseClient';

const allActivities = ref([]);
const isLoadingActivities = ref(false);

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
    if (allActivities.value.length > 0) {
      return allActivities.value; // Already loaded
    }

    isLoadingActivities.value = true;

    try {
      const { data, error } = await supabase
        .from('activities')
        .select('*')
        .eq('is_active', true)
        .order('vespa_category, level, display_order');

      if (error) throw error;

      allActivities.value = data || [];
      console.log(`✅ Loaded ${allActivities.value.length} activities`);
      
      return allActivities.value;

    } catch (err) {
      console.error('Failed to load activities:', err);
      throw err;
    } finally {
      isLoadingActivities.value = false;
    }
  };

  /**
   * Assign activity to student
   */
  const assignActivity = async (studentEmail, activityId, staffEmail, cycleNumber = 1) => {
    try {
      // Get current academic year (you might want to make this dynamic)
      const academicYear = '2025/2026';

      // Insert or update activity_responses
      const { data, error } = await supabase
        .from('activity_responses')
        .upsert({
          student_email: studentEmail,
          activity_id: activityId,
          cycle_number: cycleNumber,
          academic_year: academicYear,
          status: 'in_progress', // Changed from 'assigned' - constraint only allows 'in_progress' or 'completed'
          selected_via: 'staff_assigned',
          responses: {},
          started_at: new Date().toISOString()
        }, {
          onConflict: 'student_email,activity_id,cycle_number',
          ignoreDuplicates: false
        })
        .select()
        .single();

      if (error) throw error;

      // Log to activity_history
      await supabase
        .from('activity_history')
        .insert({
          student_email: studentEmail,
          activity_id: activityId,
          action: 'assigned',
          triggered_by: 'staff',
          triggered_by_email: staffEmail,
          cycle_number: cycleNumber,
          academic_year: academicYear,
          metadata: { assigned_via: 'staff_dashboard' }
        });

      console.log('✅ Activity assigned:', { studentEmail, activityId });
      return data;

    } catch (err) {
      console.error('Failed to assign activity:', err);
      throw err;
    }
  };

  /**
   * Bulk assign activities to multiple students
   */
  const bulkAssignActivities = async (studentEmails, activityIds, staffEmail, cycleNumber = 1) => {
    try {
      const academicYear = '2025/2026';
      const assignments = [];
      const historyEntries = [];

      // Build all assignment records
      for (const studentEmail of studentEmails) {
        for (const activityId of activityIds) {
          assignments.push({
            student_email: studentEmail,
            activity_id: activityId,
            cycle_number: cycleNumber,
            academic_year: academicYear,
            status: 'in_progress', // Changed from 'assigned'
            selected_via: 'staff_assigned',
            responses: {},
            started_at: new Date().toISOString()
          });

          historyEntries.push({
            student_email: studentEmail,
            activity_id: activityId,
            action: 'assigned',
            triggered_by: 'staff',
            triggered_by_email: staffEmail,
            cycle_number: cycleNumber,
            academic_year: academicYear
          });
        }
      }

      // Bulk insert (upsert to handle conflicts)
      const { error: assignError } = await supabase
        .from('activity_responses')
        .upsert(assignments, {
          onConflict: 'student_email,activity_id,cycle_number',
          ignoreDuplicates: true
        });

      if (assignError) throw assignError;

      // Log history
      const { error: historyError } = await supabase
        .from('activity_history')
        .insert(historyEntries);

      if (historyError) console.warn('Failed to log history:', historyError);

      console.log(`✅ Bulk assigned ${activityIds.length} activities to ${studentEmails.length} students`);

    } catch (err) {
      console.error('Failed to bulk assign:', err);
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
        .order('display_order');

      if (error) throw error;

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
      grouped[cat] = allActivities.value.filter(a => a.vespa_category === cat);
    });

    return grouped;
  };

  /**
   * Filter activities by search term, category, level
   */
  const filterActivities = (filters = {}) => {
    let filtered = allActivities.value;

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
    allActivities,
    isLoadingActivities,
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

