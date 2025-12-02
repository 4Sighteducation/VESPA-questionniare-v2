/**
 * useNotifications Composable
 * Manages real-time notifications
 */

import { ref, computed, onMounted, onUnmounted } from 'vue';
import supabase from '../../shared/supabaseClient';

export function useNotifications(userEmail) {
  // State
  const notifications = ref([]);
  const loading = ref(false);
  const showPanel = ref(false);
  let subscription = null;
  
  // Computed
  const unreadNotifications = computed(() => {
    return notifications.value.filter(n => !n.is_read).length;
  });
  
  const unreadCount = computed(() => unreadNotifications.value);
  
  const sortedNotifications = computed(() => {
    return [...notifications.value].sort((a, b) => {
      // Unread first
      if (a.is_read !== b.is_read) {
        return a.is_read ? 1 : -1;
      }
      // Then by date (newest first)
      return new Date(b.created_at) - new Date(a.created_at);
    });
  });
  
  // API Base URL
  const API_BASE_URL = import.meta.env?.VITE_API_URL || 'https://vespa-dashboard-9a1f84ee5341.herokuapp.com';
  
  // Methods
  const fetchNotifications = async (unreadOnly = false) => {
    try {
      loading.value = true;
      
      // Use API endpoint (bypasses RLS)
      const url = `${API_BASE_URL}/api/notifications?email=${encodeURIComponent(userEmail)}${unreadOnly ? '&unread_only=true' : ''}`;
      
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`API error: ${response.status}`);
      }
      
      const data = await response.json();
      notifications.value = data.notifications || [];
      console.log('[useNotifications] Fetched notifications via API:', notifications.value.length);
      
    } catch (err) {
      console.error('[useNotifications] Error fetching:', err);
      // Fallback to Supabase direct query
      try {
        let query = supabase
          .from('notifications')
          .select('*')
          .eq('recipient_email', userEmail);
        
        if (unreadOnly) {
          query = query.eq('is_read', false);
        }
        
        query = query.order('created_at', { ascending: false }).limit(50);
        
        const { data, error } = await query;
        
        if (!error) {
          notifications.value = data || [];
          console.log('[useNotifications] Fetched notifications via Supabase fallback:', notifications.value.length);
        }
      } catch (fallbackErr) {
        console.error('[useNotifications] Fallback also failed:', fallbackErr);
      }
    } finally {
      loading.value = false;
    }
  };
  
  const markRead = async (notificationId) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ 
          is_read: true, 
          read_at: new Date().toISOString() 
        })
        .eq('id', notificationId);
      
      if (error) throw error;
      
      // Update local state
      const notification = notifications.value.find(n => n.id === notificationId);
      if (notification) {
        notification.is_read = true;
        notification.read_at = new Date().toISOString();
      }
      
      console.log('[useNotifications] Marked as read:', notificationId);
      
    } catch (err) {
      console.error('[useNotifications] Error marking read:', err);
    }
  };
  
  const markAllRead = async () => {
    try {
      const unreadIds = notifications.value
        .filter(n => !n.is_read)
        .map(n => n.id);
      
      if (unreadIds.length === 0) return;
      
      const { error } = await supabase
        .from('notifications')
        .update({ 
          is_read: true, 
          read_at: new Date().toISOString() 
        })
        .in('id', unreadIds);
      
      if (error) throw error;
      
      // Update local state
      notifications.value.forEach(n => {
        if (!n.is_read) {
          n.is_read = true;
          n.read_at = new Date().toISOString();
        }
      });
      
      console.log('[useNotifications] Marked all as read');
      
    } catch (err) {
      console.error('[useNotifications] Error marking all read:', err);
    }
  };
  
  const dismissNotification = async (notificationId) => {
    try {
      const { error } = await supabase
        .from('notifications')
        .update({ is_dismissed: true })
        .eq('id', notificationId);
      
      if (error) throw error;
      
      // Remove from local state
      notifications.value = notifications.value.filter(n => n.id !== notificationId);
      
      console.log('[useNotifications] Dismissed:', notificationId);
      
    } catch (err) {
      console.error('[useNotifications] Error dismissing:', err);
    }
  };
  
  const toggleNotifications = () => {
    showPanel.value = !showPanel.value;
  };
  
  const subscribeToRealtime = () => {
    console.log('[useNotifications] Subscribing to real-time updates...');
    
    subscription = supabase
      .channel(`notifications:${userEmail}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `recipient_email=eq.${userEmail}`
        },
        (payload) => {
          console.log('[useNotifications] 🔔 New notification received:', payload.new);
          
          // Add to beginning of array
          notifications.value.unshift(payload.new);
          
          // Show toast notification
          showToast(payload.new);
        }
      )
      .subscribe();
    
    console.log('[useNotifications] ✅ Real-time subscription active');
  };
  
  const unsubscribeFromRealtime = () => {
    if (subscription) {
      subscription.unsubscribe();
      console.log('[useNotifications] Unsubscribed from real-time');
    }
  };
  
  const showToast = (notification) => {
    // Create toast element
    const toast = document.createElement('div');
    toast.className = 'vespa-notification-toast';
    toast.style.cssText = `
      position: fixed;
      top: 100px;
      right: 20px;
      background: white;
      border-left: 4px solid #079baa;
      padding: 16px 20px;
      border-radius: 8px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.15);
      max-width: 350px;
      z-index: 10000;
      animation: slideInRight 0.3s ease-out;
    `;
    
    toast.innerHTML = `
      <div style="display: flex; align-items: start; gap: 12px;">
        <div style="font-size: 24px;">${getNotificationIcon(notification.notification_type)}</div>
        <div style="flex: 1;">
          <div style="font-weight: 600; margin-bottom: 4px;">${notification.title}</div>
          <div style="font-size: 14px; color: #666;">${notification.message}</div>
        </div>
        <button onclick="this.parentElement.parentElement.remove()" 
                style="background: none; border: none; cursor: pointer; font-size: 18px; color: #999;">
          ×
        </button>
      </div>
    `;
    
    document.body.appendChild(toast);
    
    // Auto-remove after 5 seconds
    setTimeout(() => {
      toast.style.animation = 'slideOutRight 0.3s ease-in';
      setTimeout(() => toast.remove(), 300);
    }, 5000);
  };
  
  const getNotificationIcon = (type) => {
    const icons = {
      'feedback_received': '💬',
      'activity_assigned': '📚',
      'achievement_earned': '🏆',
      'reminder': '⏰',
      'milestone': '🎯',
      'staff_note': '✉️',
      'encouragement': '⭐'
    };
    return icons[type] || '🔔';
  };
  
  // Lifecycle
  onMounted(() => {
    if (userEmail) {
      fetchNotifications();
      subscribeToRealtime();
    }
  });
  
  onUnmounted(() => {
    unsubscribeFromRealtime();
  });
  
  return {
    // State
    notifications,
    loading,
    showPanel,
    
    // Computed
    unreadNotifications,
    unreadCount,
    sortedNotifications,
    
    // Methods
    fetchNotifications,
    markRead,
    markAllRead,
    dismissNotification,
    toggleNotifications,
    subscribeToRealtime,
    unsubscribeFromRealtime
  };
}

export default useNotifications;


