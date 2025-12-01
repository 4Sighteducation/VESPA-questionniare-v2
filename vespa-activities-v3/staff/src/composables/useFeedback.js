/**
 * Feedback Composable
 * Handles staff feedback on student activities
 */

import { ref } from 'vue';
import supabase from '../supabaseClient';

export function useFeedback() {

  /**
   * Save feedback on a completed activity
   */
  const saveFeedback = async (responseId, feedbackText, staffEmail) => {
    try {
      if (!feedbackText || !feedbackText.trim()) {
        throw new Error('Feedback text is required');
      }

      const { data, error } = await supabase
        .from('activity_responses')
        .update({
          staff_feedback: feedbackText.trim(),
          staff_feedback_by: staffEmail,
          staff_feedback_at: new Date().toISOString(),
          feedback_read_by_student: false, // Mark as unread (triggers notification!)
          updated_at: new Date().toISOString()
        })
        .eq('id', responseId)
        .select()
        .single();

      if (error) throw error;

      // Log to history
      await supabase
        .from('activity_history')
        .insert({
          student_email: data.student_email,
          activity_id: data.activity_id,
          action: 'feedback_given',
          triggered_by: 'staff',
          triggered_by_email: staffEmail,
          cycle_number: data.cycle_number,
          metadata: { feedback_length: feedbackText.length }
        });

      // TODO: Send email notification to student
      // This would typically call a Supabase Edge Function or external API:
      // await supabase.functions.invoke('send-feedback-email', {
      //   body: {
      //     studentEmail: data.student_email,
      //     activityId: data.activity_id,
      //     staffEmail: staffEmail,
      //     feedbackPreview: feedbackText.substring(0, 100)
      //   }
      // });

      console.log('✅ Feedback saved:', { responseId, feedbackLength: feedbackText.length });
      console.log('📧 Student will see notification on next login');
      return data;

    } catch (err) {
      console.error('Failed to save feedback:', err);
      throw err;
    }
  };

  /**
   * Get unread feedback count for a student
   */
  const getUnreadFeedbackCount = async (studentEmail) => {
    try {
      const { count, error } = await supabase
        .from('activity_responses')
        .select('*', { count: 'exact', head: true })
        .eq('student_email', studentEmail)
        .not('staff_feedback', 'is', null)
        .eq('feedback_read_by_student', false);

      if (error) throw error;

      return count || 0;

    } catch (err) {
      console.error('Failed to get unread feedback count:', err);
      return 0;
    }
  };

  /**
   * Get all students with unread feedback (for staff notifications)
   */
  const getStudentsAwaitingFeedbackRead = async (schoolId) => {
    try {
      const { data, error } = await supabase
        .from('vespa_students')
        .select(`
          id,
          email,
          full_name,
          current_year_group,
          activity_responses!inner (
            id,
            staff_feedback,
            feedback_read_by_student,
            staff_feedback_at
          )
        `)
        .eq('school_id', schoolId)
        .not('activity_responses.staff_feedback', 'is', null)
        .eq('activity_responses.feedback_read_by_student', false);

      if (error) throw error;

      // Process to count unread per student
      const studentMap = new Map();
      
      (data || []).forEach(student => {
        if (!studentMap.has(student.id)) {
          studentMap.set(student.id, {
            ...student,
            unreadFeedbackCount: 0
          });
        }
        studentMap.get(student.id).unreadFeedbackCount += student.activity_responses.length;
      });

      return Array.from(studentMap.values());

    } catch (err) {
      console.error('Failed to get students awaiting feedback read:', err);
      return [];
    }
  };

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
          status: 'assigned',
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

  return {
    saveFeedback,
    getUnreadFeedbackCount,
    getStudentsAwaitingFeedbackRead,
    markActivityComplete,
    markActivityIncomplete
  };
}

