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
  IonSearchbar,
  useIonToast,
  IonRefresher,
  IonRefresherContent,
  IonSelect,
  IonSelectOption,
  IonCard,
  IonCardHeader,
  IonCardTitle,
  IonCardContent,
  IonChip,
  IonModal,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonButtons,
  IonSegment,
  IonSegmentButton,
  IonGrid,
  IonRow,
  IonCol,
} from '@ionic/react';
import {
  globeOutline,
  peopleOutline,
  timeOutline,
  calendarOutline,
  filterOutline,
  hourglassOutline,
} from 'ionicons/icons';
import { useAuth } from '../contexts/AuthContext';
import { getPublicGroups, getUserJoinRequests, PublicGroup, JoinRequest, requestToJoinGroup } from '../services/database';
import AppHeader from '../components/AppHeader';

const Discover: React.FC = () => {
  const [groups, setGroups] = useState<PublicGroup[]>([]);
  const [joinRequests, setJoinRequests] = useState<JoinRequest[]>([]);
  const [loading, setLoading] = useState(true);
  const [joiningGroup, setJoiningGroup] = useState<string | null>(null);
  const [searchText, setSearchText] = useState('');
  const [showFilters, setShowFilters] = useState(false);
  const [activeSegment, setActiveSegment] = useState<'discover' | 'requests'>('discover');
  const [sortBy, setSortBy] = useState<'created_at' | 'member_count' | 'activity_count'>('created_at');
  const [sortOrder, setSortOrder] = useState<'asc' | 'desc'>('desc');
  const [joinMethod, setJoinMethod] = useState<'all' | 'direct' | 'invitation'>('all');
  const [activityFilter, setActivityFilter] = useState<'all' | 'recent'>('all');
  const { user } = useAuth();
  const [present] = useIonToast();

  useEffect(() => {
    loadData();
  }, [user]);

  const loadData = async (event?: CustomEvent) => {
    if (!user) return;
    try {
      console.log('Loading public groups for user:', user.id);
      const [publicGroups, userRequests] = await Promise.all([
        getPublicGroups(user.id, {
          sortBy,
          sortOrder,
          joinMethod: joinMethod === 'all' ? undefined : joinMethod,
          hasRecentActivity: activityFilter === 'recent',
        }),
        getUserJoinRequests(user.id),
      ]);
      console.log('Loaded public groups:', publicGroups);
      console.log('Loaded join requests:', userRequests);
      setGroups(publicGroups);
      setJoinRequests(userRequests);
    } catch (error) {
      console.error('Error loading data:', error);
      present({
        message: 'Failed to load data',
        duration: 3000,
        position: 'top',
        color: 'danger'
      });
    } finally {
      setLoading(false);
      event?.detail?.complete();
    }
  };

  const handleJoinGroup = async (groupId: string) => {
    if (!user) return;
    setJoiningGroup(groupId);
    try {
      const result = await requestToJoinGroup(groupId, user.id);
      present({
        message: result.status === 'joined' 
          ? 'Successfully joined group' 
          : 'Join request sent successfully',
        duration: 2000,
        position: 'top',
        color: 'success'
      });
      // Refresh data to update lists
      loadData();
    } catch (error: any) {
      present({
        message: error.message || 'Failed to join group',
        duration: 3000,
        position: 'top',
        color: 'danger'
      });
    } finally {
      setJoiningGroup(null);
    }
  };

  const filteredGroups = groups.filter(group => 
    group.name.toLowerCase().includes(searchText.toLowerCase()) ||
    (group.description?.toLowerCase().includes(searchText.toLowerCase()))
  );

  const formatDate = (dateString: string) => {
    const date = new Date(dateString);
    return date.toLocaleDateString(undefined, {
      year: 'numeric',
      month: 'short',
      day: 'numeric'
    });
  };

  return (
    <IonPage>
      <AppHeader title="Discover" />
      <IonContent>
        <IonRefresher slot="fixed" onIonRefresh={loadData}>
          <IonRefresherContent />
        </IonRefresher>

        <IonSegment 
          value={activeSegment}
          onIonChange={e => setActiveSegment(e.detail.value as 'discover' | 'requests')}
          className="ion-padding"
        >
          <IonSegmentButton value="discover">
            <IonIcon icon={globeOutline} />
            <IonLabel>Discover</IonLabel>
          </IonSegmentButton>
          <IonSegmentButton value="requests">
            <IonIcon icon={hourglassOutline} />
            <IonLabel>
              Requests
              {joinRequests.length > 0 && (
                <IonBadge color="primary" className="ion-margin-start">
                  {joinRequests.length}
                </IonBadge>
              )}
            </IonLabel>
          </IonSegmentButton>
        </IonSegment>

        {activeSegment === 'discover' ? (
          <>
            <div className="ion-padding">
              <IonGrid>
                <IonRow>
                  <IonCol size="10">
                    <IonSearchbar
                      value={searchText}
                      onIonInput={e => setSearchText(e.detail.value!)}
                      placeholder="Search groups"
                    />
                  </IonCol>
                  <IonCol size="2">
                    <IonButton 
                      fill="clear" 
                      onClick={() => setShowFilters(true)}
                      className="ion-no-padding"
                    >
                      <IonIcon icon={filterOutline} />
                    </IonButton>
                  </IonCol>
                </IonRow>
              </IonGrid>
            </div>

            {loading ? (
              <div className="ion-text-center ion-padding">
                <IonSpinner />
              </div>
            ) : filteredGroups.length === 0 ? (
              <div className="ion-text-center ion-padding">
                <IonIcon
                  icon={globeOutline}
                  style={{ fontSize: '64px', color: 'var(--ion-color-medium)' }}
                />
                <IonText>
                  <p>No public groups available to join.</p>
                  <p>Check back later!</p>
                </IonText>
              </div>
            ) : (
              <IonList>
                {filteredGroups.map(group => (
                  <IonCard key={group.id} className="ion-margin">
                    <IonCardHeader>
                      <IonCardTitle>{group.name}</IonCardTitle>
                      <div className="ion-padding-top">
                        <IonChip color="success">
                          <IonIcon icon={globeOutline} />
                          <IonLabel>Public</IonLabel>
                        </IonChip>
                        <IonChip>
                          <IonIcon icon={peopleOutline} />
                          <IonLabel>{group.member_count} members</IonLabel>
                        </IonChip>
                        {group.latest_activity && (
                          <IonChip>
                            <IonIcon icon={calendarOutline} />
                            <IonLabel>{group.activity_count} activities</IonLabel>
                          </IonChip>
                        )}
                      </div>
                    </IonCardHeader>
                    <IonCardContent>
                      {group.description && (
                        <p>{group.description}</p>
                      )}
                      <IonItem lines="none" className="ion-margin-top">
                        <IonIcon icon={timeOutline} slot="start" />
                        <IonLabel>Created {formatDate(group.created_at)}</IonLabel>
                      </IonItem>
                      {group.latest_activity && (
                        <IonItem lines="none">
                          <IonIcon icon={calendarOutline} slot="start" />
                          <IonLabel>
                            Latest activity: {group.latest_activity.title}
                            <p>{formatDate(group.latest_activity.date)}</p>
                          </IonLabel>
                        </IonItem>
                      )}
                      <div className="ion-text-center ion-padding-top">
                        <IonButton
                          onClick={() => handleJoinGroup(group.id)}
                          disabled={joiningGroup === group.id}
                        >
                          {joiningGroup === group.id ? (
                            <IonSpinner name="crescent" />
                          ) : (
                            group.join_method === 'direct' ? 'Join Now' : 'Request to Join'
                          )}
                        </IonButton>
                      </div>
                    </IonCardContent>
                  </IonCard>
                ))}
              </IonList>
            )}
          </>
        ) : (
          <IonList>
            {joinRequests.length === 0 ? (
              <div className="ion-text-center ion-padding">
                <IonIcon
                  icon={hourglassOutline}
                  style={{ fontSize: '64px', color: 'var(--ion-color-medium)' }}
                />
                <IonText>
                  <p>No pending join requests</p>
                </IonText>
              </div>
            ) : (
              joinRequests.map(request => (
                <IonItem key={request.id}>
                  <IonLabel>
                    <h2>{request.group.name}</h2>
                    <p>Requested {formatDate(request.created_at)}</p>
                  </IonLabel>
                  <IonBadge color="warning" slot="end">Pending</IonBadge>
                </IonItem>
              ))
            )}
          </IonList>
        )}

        {/* Filters Modal */}
        <IonModal isOpen={showFilters} onDidDismiss={() => setShowFilters(false)}>
          <IonHeader>
            <IonToolbar>
              <IonTitle>Filter Groups</IonTitle>
              <IonButtons slot="end">
                <IonButton onClick={() => setShowFilters(false)}>Done</IonButton>
              </IonButtons>
            </IonToolbar>
          </IonHeader>
          <IonContent>
            <IonList>
              <IonItem>
                <IonLabel>Sort By</IonLabel>
                <IonSelect
                  value={sortBy}
                  onIonChange={e => {
                    setSortBy(e.detail.value);
                    loadData();
                  }}
                >
                  <IonSelectOption value="created_at">Creation Date</IonSelectOption>
                  <IonSelectOption value="member_count">Member Count</IonSelectOption>
                  <IonSelectOption value="activity_count">Activity Count</IonSelectOption>
                </IonSelect>
              </IonItem>

              <IonItem>
                <IonLabel>Sort Order</IonLabel>
                <IonSelect
                  value={sortOrder}
                  onIonChange={e => {
                    setSortOrder(e.detail.value);
                    loadData();
                  }}
                >
                  <IonSelectOption value="asc">Ascending</IonSelectOption>
                  <IonSelectOption value="desc">Descending</IonSelectOption>
                </IonSelect>
              </IonItem>

              <IonItem>
                <IonLabel>Join Method</IonLabel>
                <IonSelect
                  value={joinMethod}
                  onIonChange={e => {
                    setJoinMethod(e.detail.value);
                    loadData();
                  }}
                >
                  <IonSelectOption value="all">All</IonSelectOption>
                  <IonSelectOption value="direct">Instant Join</IonSelectOption>
                  <IonSelectOption value="invitation">Requires Approval</IonSelectOption>
                </IonSelect>
              </IonItem>

              <IonItem>
                <IonLabel>Activity</IonLabel>
                <IonSelect
                  value={activityFilter}
                  onIonChange={e => {
                    setActivityFilter(e.detail.value);
                    loadData();
                  }}
                >
                  <IonSelectOption value="all">All Groups</IonSelectOption>
                  <IonSelectOption value="recent">Recently Active</IonSelectOption>
                </IonSelect>
              </IonItem>
            </IonList>
          </IonContent>
        </IonModal>
      </IonContent>
    </IonPage>
  );
};

export default Discover; 