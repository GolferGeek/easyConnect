import { useState, useEffect } from 'react';
import {
  IonContent,
  IonPage,
  IonList,
  IonItem,
  IonLabel,
  IonButton,
  IonIcon,
  IonSpinner,
  IonText,
  IonBadge,
  IonFab,
  IonFabButton,
  useIonToast,
  IonItemSliding,
  IonItemOptions,
  IonItemOption,
  useIonActionSheet,
  useIonViewWillEnter,
} from '@ionic/react';
import { addOutline, peopleOutline, trashOutline } from 'ionicons/icons';
import { useHistory } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../config/supabase';
import AppHeader from '../components/AppHeader';

interface ExtendedGroup {
  id: string;
  name: string;
  description?: string;
  visibility?: 'public' | 'private';
  created_at: string;
  member_count: number;
  activity_count: number;
  role: 'admin' | 'member';
}

const Groups: React.FC = () => {
  const [groups, setGroups] = useState<ExtendedGroup[]>([]);
  const [loading, setLoading] = useState(true);
  const { user } = useAuth();
  const history = useHistory();
  const [present] = useIonToast();
  const [presentActionSheet] = useIonActionSheet();

  useEffect(() => {
    if (user) {
      loadGroups();
    }
  }, [user]);

  // Refresh data when the page becomes active
  useIonViewWillEnter(() => {
    if (user) {
      console.log('Groups page will enter, refreshing data...');
      setLoading(true);  // Set loading to true before refreshing
      loadGroups();
    }
  });

  const loadGroups = async () => {
    if (!user) {
      setLoading(false);
      return;
    }

    try {
      console.log('Loading groups...');
      // Get groups with member count and activity count
      const { data: groupsData, error: groupsError } = await supabase
        .from('groups')
        .select(`
          *,
          group_members!inner(role),
          activities(count)
        `)
        .eq('group_members.user_id', user.id);

      if (groupsError) throw groupsError;

      console.log('Groups data:', groupsData);

      if (!groupsData) {
        setGroups([]);
        return;
      }

      // Format the data
      const formattedGroups = groupsData.map(group => ({
        ...group,
        role: group.group_members[0].role,
        member_count: 0, // Will be updated below
        activity_count: group.activities?.[0]?.count || 0
      }));

      // Get member counts for each group
      for (const group of formattedGroups) {
        const { count, error: countError } = await supabase
          .from('group_members')
          .select('*', { count: 'exact', head: true })
          .eq('group_id', group.id);

        if (!countError) {
          group.member_count = count || 0;
        }
      }

      console.log('Formatted groups:', formattedGroups);
      setGroups(formattedGroups);
    } catch (error: any) {
      console.error('Error loading groups:', error);
      present({
        message: error.message || 'Failed to load groups',
        duration: 3000,
        position: 'top',
        color: 'danger'
      });
      setGroups([]); // Set empty array on error
    } finally {
      setLoading(false);
    }
  };

  const handleDeleteGroup = async (groupId: string) => {
    try {
      // First delete all group members
      const { error: membersError } = await supabase
        .from('group_members')
        .delete()
        .eq('group_id', groupId);

      if (membersError) throw membersError;

      // Then delete all activities
      const { error: activitiesError } = await supabase
        .from('activities')
        .delete()
        .eq('group_id', groupId);

      if (activitiesError) throw activitiesError;

      // Finally delete the group
      const { error: groupError } = await supabase
        .from('groups')
        .delete()
        .eq('id', groupId);

      if (groupError) throw groupError;

      // Update local state
      setGroups(groups.filter(g => g.id !== groupId));

      present({
        message: 'Group deleted successfully',
        duration: 2000,
        position: 'top',
        color: 'success'
      });
    } catch (error: any) {
      console.error('Error deleting group:', error);
      present({
        message: error.message || 'Failed to delete group',
        duration: 3000,
        position: 'top',
        color: 'danger'
      });
    }
  };

  return (
    <IonPage>
      <AppHeader title="Groups" />
      <IonContent>
        {loading ? (
          <div className="ion-text-center ion-padding">
            <IonSpinner />
          </div>
        ) : groups.length === 0 ? (
          <div className="ion-text-center ion-padding">
            <IonIcon
              icon={peopleOutline}
              style={{ fontSize: '64px', color: 'var(--ion-color-medium)' }}
            />
            <IonText color="medium">
              <p>No groups found</p>
              <p>Create one to get started!</p>
            </IonText>
          </div>
        ) : (
          <IonList>
            {groups.map(group => (
              <IonItemSliding key={group.id}>
                <IonItem button onClick={() => history.push(`/groups/${group.id}`)}>
                  <IonLabel>
                    <h2>{group.name}</h2>
                    <p>
                      {group.member_count} member{group.member_count !== 1 ? 's' : ''}
                      {group.activity_count > 0 && ` • ${group.activity_count} activities`}
                    </p>
                  </IonLabel>
                  {group.role === 'admin' && (
                    <IonBadge color="success" slot="end">Admin</IonBadge>
                  )}
                </IonItem>
                {group.role === 'admin' && (
                  <IonItemOptions side="end">
                    <IonItemOption 
                      color="danger" 
                      onClick={() => {
                        presentActionSheet({
                          header: 'Delete Group',
                          subHeader: 'This action cannot be undone',
                          buttons: [
                            {
                              text: 'Delete',
                              role: 'destructive',
                              handler: () => handleDeleteGroup(group.id)
                            },
                            {
                              text: 'Cancel',
                              role: 'cancel'
                            }
                          ]
                        });
                      }}
                    >
                      <IonIcon slot="icon-only" icon={trashOutline} />
                    </IonItemOption>
                  </IonItemOptions>
                )}
              </IonItemSliding>
            ))}
          </IonList>
        )}

        <IonFab vertical="bottom" horizontal="end" slot="fixed">
          <IonFabButton onClick={() => history.push('/groups/new')}>
            <IonIcon icon={addOutline} />
          </IonFabButton>
        </IonFab>
      </IonContent>
    </IonPage>
  );
};

export default Groups; 