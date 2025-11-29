/**
 * Notifications Composable
 * Real-time notification system using Supabase subscriptions
 */

import { ref, onUnmounted } from 'vue';
import supabase from '../supabaseClient';

export function useNotifications() {
  const notifications = ref([]);
  const unreadCount = ref(0);
  const subscription = ref(null);

  /**
   * Subscribe to real-time updates for staff feedback
   */
  const subscribeToFeedbackUpdates = (studentEmails = []) => {
    if (subscription.value) {
      console.log('⚠️ Already subscribed to notifications');
      return;
    }

    console.log('🔔 Subscribing to feedback updates for students:', studentEmails.length);

    subscription.value = supabase
      .channel('staff-feedback-updates')
      .on('postgres_changes',
        {
          event: 'UPDATE',
          schema: 'public',
          table: 'activity_responses',
          filter: studentEmails.length > 0 ? 
            `student_email=in.(${studentEmails.join(',')})` : 
            undefined
        },
        (payload) => {
          console.log('🔔 Feedback update received:', payload);
          
          // Check if this is feedback being read by student
          if (payload.new.feedback_read_by_student && 
              !payload.old.feedback_read_by_student) {
            
            // Student read the feedback - update UI
            notifications.value = notifications.value.filter(
              n => n.responseId !== payload.new.id
            );
            unreadCount.value = Math.max(0, unreadCount.value - 1);
            
            console.log('✅ Student read feedback, notification cleared');
          }
        }
      )
      .subscribe();
  };

  /**
   * Load unread feedback notifications
   */
  const loadUnreadFeedback = async (studentEmails = [], schoolId = null) => {
    try {
      let query = supabase
        .from('activity_responses')
        .select(`
          id,
          student_email,
          activity_id,
          staff_feedback_at,
          activities (name, vespa_category)
        `)
        .not('staff_feedback', 'is', null)
        .eq('feedback_read_by_student', false);

      if (studentEmails.length > 0) {
        query = query.in('student_email', studentEmails);
      }

      const { data, error } = await query;

      if (error) throw error;

      notifications.value = (data || []).map(n => ({
        responseId: n.id,
        studentEmail: n.student_email,
        activityId: n.activity_id,
        activityName: n.activities?.name,
        category: n.activities?.vespa_category,
        feedbackGivenAt: n.staff_feedback_at,
        type: 'feedback_awaiting_read'
      }));

      unreadCount.value = notifications.value.length;

      console.log(`📬 Loaded ${unreadCount.value} unread feedback notifications`);

    } catch (err) {
      console.error('Failed to load notifications:', err);
    }
  };

  /**
   * Unsubscribe from real-time updates
   */
  const unsubscribe = () => {
    if (subscription.value) {
      subscription.value.unsubscribe();
      subscription.value = null;
      console.log('🔕 Unsubscribed from notifications');
    }
  };

  // Cleanup on component unmount
  onUnmounted(() => {
    unsubscribe();
  });

  return {
    notifications,
    unreadCount,
    subscribeToFeedbackUpdates,
    loadUnreadFeedback,
    unsubscribe
  };
}

