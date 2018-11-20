public with sharing class attendees_search{

	public static final String OBJ_TYPE_USER = attendees_lookupController.OBJ_TYPE_USER;
	public static final String OBJ_TYPE_CONTACT = attendees_lookupController.OBJ_TYPE_CONTACT; 
	public static final String OBJ_TYPE_LEAD = attendees_lookupController.OBJ_TYPE_LEAD;

	public static final String USER_FIELD_SET_NAME = attendees_lookupController.USER_FIELD_SET_NAME;
	public static final String CONTACT_FIELD_SET_NAME = attendees_lookupController.CONTACT_FIELD_SET_NAME;
	public static final String LEAD_FIELD_SET_NAME = attendees_lookupController.LEAD_FIELD_SET_NAME;

	public static final String RELATION_TYPE_USER = attendees_lookupController.RELATION_TYPE_USER;
	public static final String RELATION_TYPE_CONTACT = attendees_lookupController.RELATION_TYPE_CONTACT; 
	public static final String RELATION_TYPE_LEAD = attendees_lookupController.RELATION_TYPE_LEAD;

	public static final String EVENT_STATUS_NEW = attendees_lookupController.EVENT_STATUS_NEW;
	public static final String EVENT_STATUS_ACCEPTED = attendees_lookupController.EVENT_STATUS_ACCEPTED;
	public static final String EVENT_STATUS_DECLINED = attendees_lookupController.EVENT_STATUS_DECLINED;

	public static final String USER_ID_PREFIX = attendees_lookupController.USER_ID_PREFIX;
	public static final String CONTACT_ID_PREFIX = attendees_lookupController.CONTACT_ID_PREFIX;
	public static final String LEAD_ID_PREFIX = attendees_lookupController.LEAD_ID_PREFIX;

	public static Map<String, Object> getMultiEntityData(Map<String, Object> jsonMap) {

		Boolean bSearchInLeads = Boolean.valueOf(jsonMap.get('searchInLeads'));
		Boolean bSearchInContacts = Boolean.valueOf(jsonMap.get('searchInContacts'));
		String sSelectedRecordsIds = (String)jsonMap.get('selectedRecordsIds');
		Integer iLimit = (Integer)jsonMap.get('limit');

		List<String> listSelectedRecordsIds = sSelectedRecordsIds.split(';');

		Set<Id> setSelectedUsersId = new Set<Id>();
		Set<Id> setSelectedContactsId = new Set<Id>();
		Set<Id> setSelectedLeadsId = new Set<Id>();

		if (listSelectedRecordsIds.size()>0){
			for (String sSelectedId:listSelectedRecordsIds){
				if(sSelectedId.startsWith(USER_ID_PREFIX)){
					setSelectedUsersId.add((Id)sSelectedId);
				}else if(sSelectedId.startsWith(CONTACT_ID_PREFIX)){
					setSelectedContactsId.add((Id)sSelectedId);
				} else if(sSelectedId.startsWith(LEAD_ID_PREFIX)){
					setSelectedLeadsId.add((Id)sSelectedId);
				}
			}
		}		

		List<Map<String, Object>> data = new List<Map<String, Object>>();
		String searchTerm = '';
		String sLikeExp = '';

		if (attendees_lookupController.fieldNotEmpty(jsonMap, 'searchTerm')) {
			searchTerm = String.escapeSingleQuotes((String)jsonMap.get('searchTerm'));
			sLikeExp = '\'%' +searchTerm +'%\'';
		}

		List<String> listUserFields = attendees_lookupController.getFieldsFromFieldSet(OBJ_TYPE_USER, USER_FIELD_SET_NAME);
		String sUserQueryString = attendees_lookupController.getQueryString(OBJ_TYPE_USER, listUserFields, null, 'setSelectedUsersId', sLikeExp, null, iLimit);
		List<User> listUsers = Database.query(sUserQueryString);
		if (listUsers.size()>0){
			for (User sobjUser: listUsers){
				data.add(new Map<String, Object>{
					'label' => attendees_lookupController.getValue(sobjUser, OBJ_TYPE_USER, listUserFields[0]),
					'sublabel' => attendees_lookupController.joinVal(attendees_lookupController.getValue(sobjUser, OBJ_TYPE_USER, listUserFields[1]), attendees_lookupController.getValue(sobjUser, OBJ_TYPE_USER, listUserFields[2])),
					'hoverinfo' =>  attendees_lookupController.getValue(sobjUser, OBJ_TYPE_USER, listUserFields[3]),
					'value' =>   sobjUser.Id,
					'recordId' => sobjUser.Id,
					'status' => EVENT_STATUS_NEW,
					'type' => RELATION_TYPE_USER,
					'readonly' => false
				});
			}
		}

		if (bSearchInContacts){
			List<String> listContactFields = attendees_lookupController.getFieldsFromFieldSet(OBJ_TYPE_CONTACT, CONTACT_FIELD_SET_NAME);
			String sQueryString = attendees_lookupController.getQueryString(OBJ_TYPE_CONTACT, listContactFields, null, 'setSelectedContactsId', sLikeExp, null, iLimit);
			List<Contact> listContacts = Database.query(sQueryString);
			if (listContacts.size()>0){
				for (Contact sobjContact: listContacts){
					data.add(new Map<String, Object>{
					'label' => attendees_lookupController.getValue(sobjContact, OBJ_TYPE_CONTACT, listContactFields[0]),
					'sublabel' => attendees_lookupController.joinVal(attendees_lookupController.getValue(sobjContact, OBJ_TYPE_CONTACT, listContactFields[1]), attendees_lookupController.getValue(sobjContact, OBJ_TYPE_CONTACT, listContactFields[2])),
					'hoverinfo' =>  attendees_lookupController.getValue(sobjContact, OBJ_TYPE_CONTACT, listContactFields[3]),
					'value' =>   sobjContact.Id,
					'recordId' => sobjContact.Id,
					'status' => EVENT_STATUS_NEW,
					'type' => RELATION_TYPE_CONTACT,
					'readonly' => false
					});  
				}
			}
		}
		if (bSearchInLeads){
			List<String> listLeadFields = attendees_lookupController.getFieldsFromFieldSet(OBJ_TYPE_LEAD, LEAD_FIELD_SET_NAME);
			String sQueryString = attendees_lookupController.getQueryString(OBJ_TYPE_LEAD, listLeadFields, null, 'setSelectedLeadsId', sLikeExp, null, iLimit);
			List<Lead> listLeads = Database.query(sQueryString);
			if (listLeads.size()>0){
				for (Lead sobjLead: listLeads){
					data.add(new Map<String, Object>{
					'label' => attendees_lookupController.getValue(sobjLead, OBJ_TYPE_LEAD, listLeadFields[0]),
					'sublabel' => attendees_lookupController.joinVal(attendees_lookupController.getValue(sobjLead, OBJ_TYPE_LEAD, listLeadFields[1]), attendees_lookupController.getValue(sobjLead, OBJ_TYPE_LEAD, listLeadFields[2])),
					'hoverinfo' =>  attendees_lookupController.getValue(sobjLead, OBJ_TYPE_LEAD, listLeadFields[3]),
					'value' =>   sobjLead.Id,
					'recordId' => sobjLead.Id,
					'status' => EVENT_STATUS_NEW,
					'type' => RELATION_TYPE_LEAD,
					'readonly' => false
					});  
				}
			}
		}

		return new Map<String, Object>{
				   'data' => data,
				   'searchTerm' => searchTerm
		};
	}
}