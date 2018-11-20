@IsTest  public with sharing class attendees_lookupControllerTest {
	public static String Attendees_Event_Organizer = System.label.Attendees_Event_Organizer;
	public static String Attendees_Label = System.label.Attendees_Label;
	public static String Attendees_Placeholder = System.label.Attendees_Placeholder;
	public static String Attendees_Loading_Message = System.label.Attendees_Loading_Message;
	public static String Attendees_Error_Message = System.label.Attendees_Error_Message;
	public static String Attendees_Label_Accepted_Status = System.label.Attendees_Label_Accepted_Status;
	public static String Attendees_Label_New_Status = System.label.Attendees_Label_New_Status;
	public static String Attendees_Label_Declined_Status = System.label.Attendees_Label_Declined_Status;
	public static String Attendees_Label_Save_Button = System.label.Attendees_Label_Save_Button;
	public static String Attendees_Label_Cancel_Button = System.label.Attendees_Label_Cancel_Button;

    @isTest static void test_getData() {

    	User sobjUser = new User(
		     ProfileId = UserInfo.getProfileId(),
		     LastName = 'Test',
		     Email = 'TestUserAttendees@example.com',
		     Username = 'TestUserAttendees@attendees.example.com' + System.currentTimeMillis(),
		     CompanyName = 'Test',
		     Title = 'Test Title',
		     Alias = 'Test',
		     TimeZoneSidKey = 'America/Los_Angeles',
		     EmailEncodingKey = 'UTF-8',
		     LanguageLocaleKey = 'en_US',
		     LocaleSidKey = 'en_US',
		     UserRoleId = UserInfo.getUserRoleId()
		);
		insert sobjUser;

		User sobjUser2 = new User(
		     ProfileId = UserInfo.getProfileId(),
		     LastName = 'Test2',
		     Email = 'TestUserAttendees2@example.com',
		     Username = 'TestUserAttendees2@attendees.example.com' + System.currentTimeMillis(),
		     CompanyName = 'Test2',
		     Title = 'Test2 Title',
		     Alias = 'Test2',
		     TimeZoneSidKey = 'America/Los_Angeles',
		     EmailEncodingKey = 'UTF-8',
		     LanguageLocaleKey = 'en_US',
		     LocaleSidKey = 'en_US',
		     UserRoleId = UserInfo.getUserRoleId()
		);
		insert sobjUser2;

		String sTestUserId = sobjUser2.Id;
		String sUserId = sobjUser.Id;

        System.runAs(sobjUser) {
	        Account sobjAccount = new Account(
	            Name='Test Account');
	        insert sobjAccount;

	        Contact sobjContact = new Contact(
	            LastName='Test Contact',
	            FirstName='Test',
	            AccountId = sobjAccount.Id);
	        insert sobjContact;

	        Contact sobjContact2 = new Contact(
	            LastName='Test Contact',
	            FirstName='Test',
	            AccountId = sobjAccount.Id);
	        insert sobjContact2;

	        Lead sobjLead = new Lead(
	            LastName='Test Lead',
	            Company='Test Company');
	        insert sobjLead;

	        Lead sobjLead2 = new Lead(
	            LastName='Test Lead 2',
	            Company='Test Company 2');
	        insert sobjLead2;

	        Event sobjEvent = new Event(
			    Type = 'Meeting',
			    Description = 'Test Description',
			    OwnerId = sUserId,
			    WhatId = sobjAccount.Id,
			    DurationInMinutes = 60,
			    ActivityDateTime = System.now());
		    insert sobjEvent;

		    EventRelation sobjEventRelation = new EventRelation(
		    	EventId = sobjEvent.Id, 
	    		RelationId = sobjLead2.Id);
			insert sobjEventRelation;

			EventRelation sobjEventRelation2 = new EventRelation(
				EventId = sobjEvent.Id, 
				Status = 'Declined',
	    		RelationId = sobjContact2.Id);
			insert sobjEventRelation2;

			EventRelation sobjEventRelation3 = new EventRelation(
				EventId = sobjEvent.Id, 
				Status = 'Accepted',
	    		RelationId = sTestUserId);
			insert sobjEventRelation3;

		    String sSelectedRecordsIds = sTestUserId+';'+sobjLead.Id+';'+sobjContact.Id;

	        String jsonStringInit = '{"initStatus":"true", "labelOrganizer":"Organizer", "eventId":"'+sobjEvent.Id+'"}';
	        String jsonStringSearch = '{"initStatus":"false", "searchInLeads":"true", "searchInContacts":"true", "selectedRecordsIds":"'+sSelectedRecordsIds+'", "searchTerm":"Test", "limit":10, "eventId":"'+sobjEvent.Id+'"}';


	        Test.startTest();
	        attendees_lookupController.isChildEvent(sobjEvent.Id);
	     	attendees_lookupController.getRecords(jsonStringInit);
	    	attendees_lookupController.getRecords(jsonStringSearch);
	    	attendees_lookupController.saveChanges(sobjEvent.Id, sSelectedRecordsIds);
	        Test.stopTest();
    	}
    }

    @isTest static void test_getValue(){
        Account sobjAccount = new Account(
            Name='Test Account',
            BillingCountry = 'France',
            BillingStreet='Test Street',
            BillingCity='Test City',
            BillingPostalCode='Test Postal Code');
        insert sobjAccount;
        Account sobjAccountFromDB = [SELECT Id, BillingAddress, BillingStreet, BillingCity, BillingPostalCode FROM Account WHERE Id = :sobjAccount.Id];

        Contact sobjContact = new Contact(
            LastName='Contact',
            FirstName='Test',
            AccountId = sobjAccount.Id);
        insert sobjContact;

        Contact sobjContactFromDB = [SELECT Id, Account.Name FROM Contact WHERE Id = :sobjContact.Id];

        Test.startTest();
        String sResultAccountFieldValue = attendees_lookupController.getValue(sobjAccountFromDB, 'Account', 'BillingAddress');
        System.assert(sResultAccountFieldValue.length()>0);
        String sResultContactFieldValue = attendees_lookupController.getValue(sobjContactFromDB, 'Contact', 'Account.Name');
        System.assertEquals(sobjAccount.Name, sResultContactFieldValue);
        Test.stopTest();
    }
    @isTest static void test_isPersonAccountEnabled(){
    	Test.startTest();
    	attendees_lookupController.isPersonAccountEnabled();
    	Test.stopTest();    	
    }
    
}