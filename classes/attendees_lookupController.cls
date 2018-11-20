public without sharing class attendees_lookupController {

	private static final String CLASS_NAMESPACE = [SELECT NamespacePrefix FROM ApexClass WHERE Name = 'attendees_lookupController' LIMIT 1].NamespacePrefix;

	public static final String OBJ_TYPE_USER = 'User';
	public static final String OBJ_TYPE_CONTACT = 'Contact'; 
	public static final String OBJ_TYPE_LEAD = 'Lead';

	public static final String RELATION_TYPE_USER = 'User';
	public static final String RELATION_TYPE_CONTACT = 'Contact'; 
	public static final String RELATION_TYPE_LEAD = 'Lead';

	public static final String EVENT_STATUS_NEW = 'New';
	public static final String EVENT_STATUS_ACCEPTED = 'Accepted';
	public static final String EVENT_STATUS_DECLINED = 'Declined';

	public static final String EVENT_RELATION_TYPE_USER = 'User';

	public static final String USER_ID_PREFIX = '005';
	public static final String CONTACT_ID_PREFIX = '003';
	public static final String LEAD_ID_PREFIX = '00Q';

	public static final String USER_FIELD_SET_NAME = 'Attendees_Preview';
	public static final String CONTACT_FIELD_SET_NAME = 'Attendees_Preview';
	public static final String LEAD_FIELD_SET_NAME = 'Attendees_Preview';

	public static final String PARENT_EVENT_NOT_FOUND = 'ParentEventNotFound';

	@AuraEnabled
    public static String isChildEvent(String sEventId){
    	String sQueryString = 'SELECT Id, IsChild, Subject, WhatId, StartDateTime';
    	Boolean bClientGuidEnabled = false;
    	if (Schema.sObjectType.Event.fields.getMap().containsKey('ClientGuid')){
    		sQueryString+=', ClientGuid';
    		bClientGuidEnabled = true;
    	}
    	sQueryString += ' FROM Event WHERE Id=:sEventId LIMIT 1';
	    Event currentEvent = Database.query(sQueryString);
        if (currentEvent.IsChild || Test.isRunningTest()){
	    	DateTime dtStartDateTime = currentEvent.StartDateTime;
	    	String sWhatId = currentEvent.WhatId;

	    	sQueryString = 'SELECT Id FROM Event WHERE isChild=false AND WhatId=:sWhatId AND Subject= \'' + currentEvent.Subject +'\' AND StartDateTime=:dtStartDateTime';
	        if (bClientGuidEnabled){
	        	String sClientGuid = (String)currentEvent.get('ClientGuid');
	    		sQueryString+=' AND ClientGuid =:sClientGuid ';
	    	}
	    	sQueryString+=' LIMIT 1';
        	list <Event> listParentEvent = Database.query(sQueryString);
        	if (listParentEvent.size()>0){
        		return listParentEvent[0].Id;
        	}else{
        		return PARENT_EVENT_NOT_FOUND;
        	}
	    }
		return null;
	}

	@AuraEnabled
    public static Boolean isCurrentUserEventOwner(String sEventId){
        String userId = UserInfo.getUserId();
        Event currentEvent = [SELECT Id, OwnerId FROM Event WHERE Id =: sEventId LIMIT 1];
		return userId == currentEvent.OwnerId;
	}

	@AuraEnabled 
	public static Boolean isPersonAccountEnabled(){
    	return Account.SObjectType.getDescribe().hasSubtypes;
	}

	@AuraEnabled
	public static String getRecords(String jsonString) {
		strike_responseData responseData = new strike_responseData();
		
		try {
			Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(jsonString);
			Boolean bInitStatus = Boolean.valueOf(jsonMap.get('initStatus'));
			if (bInitStatus){
				responseData.results = attendees_lookupController.initData(jsonMap);
			}else{
				responseData.results = attendees_search.getMultiEntityData(jsonMap);
			}
		} catch (Exception e) {
			responseData.addError(e.getMessage());
		}

		return responseData.getJsonString();
	}

	public static Boolean isSharedActivitiesEnabled(){
		return Schema.sObjectType.EventRelation.fields.getMap().containsKey('IsParent');
	}

	private static Map<String, Object> initData(Map<String, Object> jsonMap) {
		String sEventId = String.escapeSingleQuotes((String)jsonMap.get('eventId'));
		String sOrginizerLabel = '';

		Boolean bSharedActivitiesEnabled = isSharedActivitiesEnabled();

		List<Map<String, Object>> data = new List<Map<String, Object>>();
		Integer iNewStatusCount = 0;
		Integer iDeclinedStatusCount = 0;
		Integer iAcceptedStatusCount = 1; //Owner always in Accepted status

		String sQueryEventRelation = 'SELECT Id, EventId, Status, RelationId, Relation.Type FROM EventRelation WHERE  IsDeleted=false AND EventId=:sEventId';
		if (bSharedActivitiesEnabled == true){
			sQueryEventRelation+=' AND IsInvitee=true';
		} 
		List<EventRelation> listEventRelation = Database.query(sQueryEventRelation);

		Map<Id,EventRelation> mapEventRelationDetails = new Map<Id,EventRelation>();
		Set<Id> setRelatedUsersId = new Set<Id>();
		Set<Id> setRelatedContactsId = new Set<Id>();
		Set<Id> setRelatedLeadsId = new Set<Id>();

		if (listEventRelation.size()>0){
			sOrginizerLabel = String.escapeSingleQuotes((String)jsonMap.get('labelOrganizer'));
			if (sOrginizerLabel!=''){
				sOrginizerLabel = ' ('+sOrginizerLabel+')';
			}
			for (EventRelation sobjEventRelation: listEventRelation){
				if (sobjEventRelation.Relation.Type == RELATION_TYPE_USER){
					setRelatedUsersId.add(sobjEventRelation.RelationId);
				}else if(sobjEventRelation.Relation.Type == RELATION_TYPE_CONTACT){
					setRelatedContactsId.add(sobjEventRelation.RelationId);
				}else if(sobjEventRelation.Relation.Type == RELATION_TYPE_LEAD){
					setRelatedLeadsId.add(sobjEventRelation.RelationId);
				}

				mapEventRelationDetails.put(sobjEventRelation.RelationId, sobjEventRelation);

				if (sobjEventRelation.Status == EVENT_STATUS_NEW){
					iNewStatusCount++;
				}else if(sobjEventRelation.Status == EVENT_STATUS_ACCEPTED){
					iAcceptedStatusCount++;
				}else if(sobjEventRelation.Status == EVENT_STATUS_DECLINED){
					iDeclinedStatusCount++;
				} 
			}
		}

		List<String> listUserFields = getFieldsFromFieldSet(OBJ_TYPE_USER, USER_FIELD_SET_NAME);
		List<String> listContactFields = getFieldsFromFieldSet(OBJ_TYPE_CONTACT, CONTACT_FIELD_SET_NAME);
		List<String> listLeadFields = getFieldsFromFieldSet(OBJ_TYPE_LEAD, LEAD_FIELD_SET_NAME);
		String sUserQueryFields;

		//Fetch Owner Record From Users
		Id eventOwnerId = [SELECT OwnerId FROM Event WHERE Id =:sEventId LIMIT 1].OwnerId;
		setRelatedUsersId.add(eventOwnerId);

		if (setRelatedUsersId.size()>0){
			String sQueryString = getQueryString(OBJ_TYPE_USER, listUserFields, 'setRelatedUsersId');
			List<User> listUsers = Database.query(sQueryString);
			if (listUsers.size()>0){
				for (User sobjUser: listUsers){
					if (sobjUser.Id != eventOwnerId){
						data.add(new Map<String, Object>{
							'label' => getValue(sobjUser, OBJ_TYPE_USER, listUserFields[0]),
							'sublabel' => joinVal(getValue(sobjUser, OBJ_TYPE_USER, listUserFields[1]) , getValue(sobjUser, OBJ_TYPE_USER, listUserFields[2])),
							'hoverinfo' =>  getValue(sobjUser, OBJ_TYPE_USER, listUserFields[3]),
							'value' =>   sobjUser.Id,
							'recordId' => sobjUser.Id,
							'status' => mapEventRelationDetails.get(sobjUser.Id).Status,
							'eventRelationId' => mapEventRelationDetails.get(sobjUser.Id).Id,
							'type' => mapEventRelationDetails.get(sobjUser.Id).Relation.Type,
							'readonly' => false
						});

					}else{
						//User Is Owner of this Event
						data.add(new Map<String, Object>{
						'label' => getValue(sobjUser, OBJ_TYPE_USER, listUserFields[0]) + sOrginizerLabel,
						'sublabel' => joinVal(getValue(sobjUser, OBJ_TYPE_USER, listUserFields[1]), getValue(sobjUser, OBJ_TYPE_USER, listUserFields[2])),
						'hoverinfo' =>  getValue(sobjUser, OBJ_TYPE_USER, listUserFields[3]),
						'value' =>   eventOwnerId,
						'recordId' => sobjUser.Id,
						'status' => EVENT_STATUS_ACCEPTED,
						'type' => EVENT_RELATION_TYPE_USER,
						'readonly' => true
						});
					}
				}
			}
		}

		if (setRelatedContactsId.size()>0){
			String sQueryString = getQueryString(OBJ_TYPE_CONTACT, listContactFields, 'setRelatedContactsId');
			List<Contact> listContacts = Database.query(sQueryString);
			if (listContacts.size()>0){
				for (Contact sobjContact: listContacts){
					data.add(new Map<String, Object>{
					'label' => getValue(sobjContact, OBJ_TYPE_CONTACT, listContactFields[0]),
					'sublabel' => joinVal(getValue(sobjContact, OBJ_TYPE_CONTACT, listContactFields[1]), getValue(sobjContact, OBJ_TYPE_CONTACT, listContactFields[2])),
					'hoverinfo' =>  getValue(sobjContact, OBJ_TYPE_CONTACT, listContactFields[3]),
					'value' =>   sobjContact.Id,
					'recordId' => sobjContact.Id,
					'status' => mapEventRelationDetails.get(sobjContact.Id).Status,
					'eventRelationId' => mapEventRelationDetails.get(sobjContact.Id).Id,
					'type' => mapEventRelationDetails.get(sobjContact.Id).Relation.Type,
					'readonly' => false
					});  
				}
			}
		}

		if (setRelatedLeadsId.size()>0){
			String sQueryString = getQueryString(OBJ_TYPE_LEAD, listLeadFields, 'setRelatedLeadsId');
			List<Lead> listLeads = Database.query(sQueryString);
			if (listLeads.size()>0){
				for (Lead sobjLead: listLeads){
					data.add(new Map<String, Object>{
					'label' => getValue(sobjLead, OBJ_TYPE_LEAD, listLeadFields[0]),
					'sublabel' => joinVal(getValue(sobjLead, OBJ_TYPE_LEAD, listLeadFields[1]) , getValue(sobjLead, OBJ_TYPE_LEAD, listLeadFields[2])),
					'hoverinfo' =>  getValue(sobjLead, OBJ_TYPE_LEAD, listLeadFields[3]),
					'value' =>   sobjLead.Id,
					'recordId' => sobjLead.Id,
					'status' => mapEventRelationDetails.get(sobjLead.Id).Status,
					'eventRelationId' => mapEventRelationDetails.get(sobjLead.Id).Id,
					'type' => mapEventRelationDetails.get(sobjLead.Id).Relation.Type,
					'readonly'=> false
					});  
				}
			}
		}

		return new Map<String, Object>{
			'data' => data,
			'iNewStatusCount' => iNewStatusCount,
			'iAcceptedStatusCount' => iAcceptedStatusCount,
			'iDeclinedStatusCount' => iDeclinedStatusCount
		};
	}

	@AuraEnabled
	public static void saveChanges(String sEventId, String sSelectedRecordsIds) {

		//Validate that Current User is Owner to Prevent UI hacks from Dev console
		if (isCurrentUserEventOwner(sEventId)){

			Boolean bIsSharedActivitiesEnabled = isSharedActivitiesEnabled();
			String sCurrentUserId = UserInfo.getUserId();

			Set<Id> setSelectedRecordsIds = new Set<Id>();

			List<String> listSelectedRecordsIds = sSelectedRecordsIds.split(';');
			if (listSelectedRecordsIds.size()>0){
				for (String sSelectedId:listSelectedRecordsIds){
					setSelectedRecordsIds.add((Id)sSelectedId);
				}
			}
			//Event owner (organizer) not supposed to be stored in EventRelation
			setSelectedRecordsIds.remove(sCurrentUserId);
			List<EventRelation> listEventRelationToDelete = new List<EventRelation>();
			List<EventRelation> listEventRelationToUpdateAddAsInvitee= new List<EventRelation>();
			List<EventRelation> listEventRelationToUpdateRemoveFromInvitee = new List<EventRelation>();
			Set<Id> setEventRelationIdToInsert = setSelectedRecordsIds.clone();
			
			
			//Get current state of Event attendees in DB
			String sQueryString =  'SELECT Id, EventId, Status, RelationId, Relation.Type';
			if (bIsSharedActivitiesEnabled){
				sQueryString+=', IsInvitee, IsParent ';
			}
			sQueryString +=  ' FROM EventRelation WHERE IsDeleted=false AND EventId=:sEventId';
			if (bIsSharedActivitiesEnabled){
				sQueryString+=' AND IsWhat=false';
			}
			List<EventRelation> listEventRelation = Database.query(sQueryString);

			if (listEventRelation.size()>0){
				if (bIsSharedActivitiesEnabled){
					for (EventRelation sobjEventRelation:listEventRelation){
						if (setSelectedRecordsIds.contains(sobjEventRelation.RelationId)){
							if(!(Boolean)sobjEventRelation.get('IsInvitee')){
								sobjEventRelation.put('IsInvitee', true);
								listEventRelationToUpdateAddAsInvitee.add(sobjEventRelation);
							}
							setEventRelationIdToInsert.remove(sobjEventRelation.RelationId);
						}else{
							if ((Boolean)sobjEventRelation.get('IsParent')){
								sobjEventRelation.put('IsInvitee', false);
								listEventRelationToUpdateRemoveFromInvitee.add(sobjEventRelation);
							}else{	
								listEventRelationToDelete.add(sobjEventRelation);
							}
						}
					}
				}else{
					for (EventRelation sobjEventRelation:listEventRelation){
						if (setSelectedRecordsIds.contains(sobjEventRelation.RelationId)){
							setEventRelationIdToInsert.remove(sobjEventRelation.RelationId);
						}else{
							listEventRelationToDelete.add(sobjEventRelation);
						}
					}
				}
			}

			if (bIsSharedActivitiesEnabled){
				//Mark as Invitee
				if (listEventRelationToUpdateAddAsInvitee.size()>0){
					update listEventRelationToUpdateAddAsInvitee;
				}
				//Remove from Invitee
				if (listEventRelationToUpdateRemoveFromInvitee.size()>0){
					update listEventRelationToUpdateRemoveFromInvitee;
				}
			}

			//Insert new EventRelations
			if (setEventRelationIdToInsert.size()>0){
				List<EventRelation> listEventRelationToInsert = new List<EventRelation>();
				for (Id relationId:setEventRelationIdToInsert){
					EventRelation sobjEventRelation = new EventRelation();
					sobjEventRelation.EventId = sEventId;
					sobjEventRelation.RelationId = relationId;
					listEventRelationToInsert.add(sobjEventRelation);
				}		
				insert listEventRelationToInsert;
			}

			//Delete removed EventRelation
			if (listEventRelationToDelete.size()>0){
				delete listEventRelationToDelete;
			}

			//Update Last Modification Date of Event
            updateEventLastModificationDate(sEventId);
		}
	}

	@future
    public static void updateEventLastModificationDate(String sEventId)
    {   
		Event sobjEvent = new Event();
		sobjEvent.id = sEventId;
		update sobjEvent;
    }

	public static Boolean fieldNotEmpty(Map<String, Object> jsonMap, String field) {
		return jsonMap.containsKey(field) && !String.isEmpty((String)jsonMap.get(field));
	}

    public static string joinVal (string str1, string str2)
    {
        string sRet;
        if (str1 == '' || str1 == null){
        	sRet = str2;
        }else{
	        if(str2 != '' && str2 != null)
	        {
				sRet = str1+'; '+str2;
	        }else
	        {
	            sRet = str1;
	        }
        }
        return sRet;
    }

	public static String getValue(SObject obj, String objectType, String field) {
		if (field==null || field == ''){
			return '';
		}
		List<String> fieldPath = field.split('[.]');
		Object label = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize(obj));

		Map<String, Schema.SObjectField> fieldMap = Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap();

		for (String fieldName : fieldPath) {
			fieldName = fieldName.replaceAll('__r$', '__c');

			label = ((Map<String, Object>)label).get(fieldName);

			if (label == null) {
				return '';
			}

			if (fieldMap.containsKey(fieldName + 'Id')) {
				fieldName = fieldName + 'Id';
			}

			Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
			String fieldType = String.valueOf(fieldDescribe.getType()).toUpperCase();

			if (fieldType == 'REFERENCE') {
				fieldMap = Schema.getGlobalDescribe().get(String.valueOf(fieldDescribe.getReferenceTo().get(0))).getDescribe().fields.getMap();
			} else if (fieldType == 'ADDRESS') {
				List<String> addressComponents = new List<String>();
				Map<String, Object> addr = (Map<String, Object>)label;

				if (addr.containsKey('street') && addr.get('street') != null) {
					addressComponents.add((String)addr.get('street'));
				}

				if (addr.containsKey('city') && addr.get('city') != null) {
					addressComponents.add((String)addr.get('city'));
				}

				if (addr.containsKey('state') && addr.get('state') != null) {
					addressComponents.add((String)addr.get('state'));
				}

				if (addr.containsKey('country') && addr.get('country') != null) {
					addressComponents.add((String)addr.get('country'));
				}

				if (addr.containsKey('postalCode') &&addr.get('postalCode') != null) {
					addressComponents.add((String)addr.get('postalCode'));
				}

				// change later for user formatting?
				label = String.join(addressComponents, ', ');
			}
		}
		return String.valueOf(label);
	}

	public static List<String> getFieldsFromFieldSet(String sObjectType, String sFieldSetName){
		String sFieldSetNameWithNamespace = sFieldSetName;
		if (CLASS_NAMESPACE!= null && CLASS_NAMESPACE!=''){
			sFieldSetNameWithNamespace=CLASS_NAMESPACE+'__'+sFieldSetName;
		}
		List<String> listFields = new List<String>{'Name','','',''};
		Schema.FieldSet fieldSetUserAttendeesPreview = Schema.getGlobalDescribe().get(sObjectType).getDescribe().fieldSets.getMap().get(sFieldSetNameWithNamespace);
		if (fieldSetUserAttendeesPreview!=null){
			List<FieldSetMember> listFieldSetMember = fieldSetUserAttendeesPreview.getFields();
			if (listFieldSetMember.size()>0){
				Integer i=0;
			 	for(Schema.FieldSetMember sobjFieldSetMember : listFieldSetMember) {
            		//get first 4 fields from field set
            		listFields[i] = sobjFieldSetMember.getFieldPath();
            		i++;
            		if (i == 4){
            			break;
            		}
        		}
			}
		}
		return listFields;
	}

	public static String getQueryString(String sObjectType, List<String> listStringFields, String sSetNameIncludeRecordsId){
		return getQueryString(sObjectType, listStringFields, sSetNameIncludeRecordsId, null, null, null, null);
	}

	public static String getQueryString(String sObjectType, List<String> listStringFields, String sSetNameIncludeRecordsId, String sSetNameExcludeRecordsId, String sNameEmailLikeExp, String sAdditionalFilter, Integer iLimit){
		String sQuery = 'SELECT ' + String.join(listStringFields, ',');
		sQuery = sQuery.replaceAll(',+$','');
		sQuery+=' FROM '+sObjectType;
		sQuery+=' WHERE ';
		String sConcatenateString = '';
		if (sSetNameIncludeRecordsId!=null){
			sQuery+='Id IN :'+sSetNameIncludeRecordsId;
			sConcatenateString = ' AND ';
		}
		if (sSetNameExcludeRecordsId!=null){
			sQuery+=sConcatenateString;

			sQuery+='Id NOT IN :'+sSetNameExcludeRecordsId;
			sConcatenateString = ' AND ';
		}
		if (sNameEmailLikeExp!=null && sNameEmailLikeExp!=''){
			sQuery+=sConcatenateString;
			sQuery+= '(Name LIKE '+ sNameEmailLikeExp +' OR Email LIKE '+sNameEmailLikeExp+')';
			sConcatenateString = ' AND ';
		}
		if (sAdditionalFilter!=null && sAdditionalFilter!=''){
			sQuery+=sConcatenateString;
			sQuery+=sAdditionalFilter;
		}
		if (iLimit!=null && iLimit>0){
			sQuery+= ' LIMIT '+iLimit;
		}
		return sQuery;
	}
}