import React, { useState, useEffect } from 'react';
import {
  IonContent,
  IonPage,
  IonItem,
  IonLabel,
  IonInput,
  IonButton,
  IonSelect,
  IonSelectOption,
  IonList,
  IonToggle,
  useIonToast,
  IonSpinner,
} from '@ionic/react';
import { useHistory } from 'react-router-dom';
import { supabase } from '../config/supabase';
import { useAuth } from '../contexts/AuthContext';
import AppHeader from '../components/AppHeader';

interface GroupType {
  id: number;
  group_type: string;
}

const CreateGroup: React.FC = () => {
  const [name, setName] = useState('');
  const [groupType, setGroupType] = useState<number | null>(null);
  const [visibility, setVisibility] = useState<'public' | 'private'>('private');
  const [joinMethod, setJoinMethod] = useState<'direct' | 'invitation'>('invitation');
  const [creating, setCreating] = useState(false);
  const [groupTypes, setGroupTypes] = useState<GroupType[]>([]);
  const { user } = useAuth();
  const history = useHistory();
  const [present] = useIonToast();

  useEffect(() => {
    loadGroupTypes();
  }, []);

  const loadGroupTypes = async () => {
    try {
      console.log('Fetching group types...');
      const { data, error } = await supabase
        .from('group_types')
        .select('id, group_type, created_at')
        .order('created_at');

      if (error) {
        console.error('Error fetching group types:', error);
        throw error;
      }
      
      console.log('Fetched group types:', data);
      setGroupTypes(data || []);
    } catch (error: any) {
      console.error('Failed to load group types:', error);
      present({
        message: error.message || 'Failed to load group types',
        duration: 3000,
        position: 'top',
        color: 'danger'
      });
    }
  };

  const handleCreate = async () => {
    if (!name.trim()) {
      present({
        message: 'Please enter a group name',
        duration: 2000,
        position: 'top',
        color: 'warning'
      });
      return;
    }

    if (!groupType) {
      present({
        message: 'Please select a group type',
        duration: 2000,
        position: 'top',
        color: 'warning'
      });
      return;
    }

    if (!user) {
      present({
        message: 'You must be logged in to create a group',
        duration: 2000,
        position: 'top',
        color: 'warning'
      });
      return;
    }

    setCreating(true);
    try {
      console.log('Creating group with data:', {
        name: name.trim(),
        group_type_id: groupType,
        visibility,
        join_method: joinMethod,
        created_by: user.id
      });

      // First create the group
      const { data: groupData, error: groupError } = await supabase
        .from('groups')
        .insert([
          {
            name: name.trim(),
            group_type_id: groupType,
            visibility,
            join_method: joinMethod,
            created_by: user.id,
            created_at: new Date().toISOString()
          }
        ])
        .select()
        .single();

      if (groupError) {
        console.error('Error creating group:', groupError);
        throw groupError;
      }

      console.log('Group created:', groupData);

      // Then add the creator as an admin member
      const { error: memberError } = await supabase
        .from('group_members')
        .insert([
          {
            group_id: groupData.id,
            user_id: user.id,
            role: 'admin'
          }
        ]);

      if (memberError) {
        console.error('Error adding member:', memberError);
        throw memberError;
      }

      console.log('Member added successfully');

      present({
        message: 'Group created successfully!',
        duration: 2000,
        position: 'top',
        color: 'success'
      });

      console.log('Navigating back to groups list');
      history.replace('/groups');
    } catch (error: any) {
      console.error('Failed to create group:', error);
      present({
        message: error.message || 'Failed to create group',
        duration: 3000,
        position: 'top',
        color: 'danger'
      });
    } finally {
      console.log('Setting creating to false');
      setCreating(false);
    }
  };

  return (
    <IonPage>
      <AppHeader title="Create Group" showBackButton />
      <IonContent>
        <IonList>
          <IonItem>
            <IonLabel position="stacked">Group Name</IonLabel>
            <IonInput
              value={name}
              onIonChange={e => setName(e.detail.value || '')}
              placeholder="Enter group name"
            />
          </IonItem>

          <IonItem>
            <IonLabel position="stacked">Group Type</IonLabel>
            <IonSelect
              value={groupType}
              onIonChange={e => setGroupType(e.detail.value)}
              placeholder="Select group type"
            >
              {groupTypes.map(type => (
                <IonSelectOption key={type.id} value={type.id}>
                  {type.group_type}
                </IonSelectOption>
              ))}
            </IonSelect>
          </IonItem>

          <IonItem>
            <IonLabel>Public Group</IonLabel>
            <IonToggle
              checked={visibility === 'public'}
              onIonChange={e => setVisibility(e.detail.checked ? 'public' : 'private')}
            />
          </IonItem>

          <IonItem>
            <IonLabel>Allow Direct Join</IonLabel>
            <IonToggle
              checked={joinMethod === 'direct'}
              onIonChange={e => setJoinMethod(e.detail.checked ? 'direct' : 'invitation')}
            />
          </IonItem>
        </IonList>

        <div className="ion-padding">
          <IonButton
            expand="block"
            onClick={handleCreate}
            disabled={creating}
          >
            {creating ? <IonSpinner /> : 'Create Group'}
          </IonButton>
        </div>
      </IonContent>
    </IonPage>
  );
};

export default CreateGroup; 