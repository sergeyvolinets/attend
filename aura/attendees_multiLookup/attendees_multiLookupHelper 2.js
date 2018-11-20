/*
Strike by Appiphony

Version: 1.0.0
Website: http://www.lightningstrike.io
GitHub: https://github.com/appiphony/Strike-Components
License: BSD 3-Clause License
*/
({
    checkIfInitialized: function(component, event, helper) {
        var initCallsRunning = component.get('v.initCallsRunning');

        if (--initCallsRunning < 0) {
            initCallsRunning = 0;
        }

        component.set('v.initCallsRunning', initCallsRunning);
    },
    closeMenu: function(component, event, helper) {
        component.set('v.focusIndex', null);
        component.set('v.openMenu', false);
    },
    getParams: function(component, event, helper, initStatus) {
        var filter = component.get('v.filter');
        var limit = component.get('v.limit');
        var eventId = component.get('v.eventId');
        var searchInLeads = component.get('v.searchInLeads');
        var searchInContacts = component.get('v.searchInContacts');

        return {
            filter: filter,
            limit: limit,
            eventId: eventId,
            initStatus: initStatus,
            searchInLeads: searchInLeads,
            searchInContacts: searchInContacts
        };
    },
    getInitialInvitees: function(component, event, helper) {
        var selectedRecordsIds = '';
        var getRecordsAction = component.get('c.getRecords');
        var params = helper.getParams(component, event, helper, true);
        params.labelOrganizer = component.get('v.labelOrganizer');

        getRecordsAction.setParams({
            jsonString: JSON.stringify(params)
        });

        getRecordsAction.setCallback(this, function(res) {
            if (res.getState() === 'SUCCESS') {
                var returnValue = JSON.parse(res.getReturnValue());
                if (returnValue.isSuccess) {
                    var tiles = component.get('v.selectedOptionTiles');
                    returnValue.results.data.forEach(function(record) {
                        var tile = {
                            title: record.label,
                            subtitle: record.sublabel,
                            hoverinfo: record.hoverinfo,
                            recordId: record.recordId,
                            status: record.status,
                            type: record.type,
                            readonly: record.readonly
                        }

                        tiles.push(tile);
                        selectedRecordsIds = selectedRecordsIds+record.recordId+";";
                    });
                    selectedRecordsIds = selectedRecordsIds.slice(0, -1);
                    component.set('v.selectedOptionTiles', tiles);
                    component.set('v.selectedRecordsIds', selectedRecordsIds);
                    component.set('v.iNewStatusCount',returnValue.results.iNewStatusCount);
                    component.set('v.iAcceptedStatusCount',returnValue.results.iAcceptedStatusCount);
                    component.set('v.iDeclinedStatusCount',returnValue.results.iDeclinedStatusCount);
                }
            }

            helper.checkIfInitialized(component, event, helper);
        });

        $A.enqueueAction(getRecordsAction);
    },
    getRecordsBySearchTerm: function(component, event, helper) {
        var searchTerm = component.find('lookupInput').getElement().value;

        var lastSearchTerm = component.get('v.lastSearchTerm');
        var searchTimeout = component.get('v.searchTimeout');

        clearTimeout(searchTimeout);

        if ($A.util.isEmpty(searchTerm)) {
            helper.setRecords(component, event, helper, []);
            return;
        } else if (searchTerm === lastSearchTerm) {
            component.set('v.searching', false);
            helper.openMenu(component, event, helper);

            return;
        }

        component.set('v.searching', true);

        component.set('v.searchTimeout', setTimeout($A.getCallback(function() {
            if (!component.isValid()) {
                return;
            }

            var getRecordsAction = component.get('c.getRecords');
            var params = helper.getParams(component, event, helper, false);

            params.searchTerm = component.find('lookupInput').getElement().value;
            params.selectedRecordsIds = component.get('v.selectedRecordsIds');

            getRecordsAction.setParams({
                jsonString: JSON.stringify(params)
            });

            getRecordsAction.setCallback(this, function(res) {
                if (res.getState() === 'SUCCESS') {
                    var returnValue = JSON.parse(res.getReturnValue());
                    
                    if (returnValue.isSuccess && returnValue.results.searchTerm === component.find('lookupInput').getElement().value) {
                        var returnedRecords = [];

                        returnValue.results.data.forEach(function(record) {
                            returnedRecords.push({
                                label: record.label,
                                sublabel: record.sublabel,
                                hoverinfo: record.hoverinfo,
                                recordId: record.recordId,
                                status: record.status,
                                type: record.type,
                                readonly: record.readonly
                            });
                        });

                        helper.setRecords(component, event, helper, returnedRecords);
                    }
                } else {
                    helper.setRecords(component, event, helper, []);
                }
            });

            $A.enqueueAction(getRecordsAction);
        }), 200));
    },
    setRecords: function(component, event, helper, returnedRecords) {
        component.set('v.focusIndex', null);
        component.set('v.lastSearchTerm', component.find('lookupInput').getElement().value);
        component.set('v.records', returnedRecords);
        component.set('v.searching', false);

        helper.openMenu(component, event, helper);
    },
    openMenu: function(component, event, helper) {
        component.set('v.openMenu', !component.get('v.disabled') && !$A.util.isEmpty(component.get('v.lastSearchTerm')));
    },
    closeMobileLookup: function(component, event, helper) {
        $A.util.removeClass(component.find('lookup'), 'sl-lookup--open');
        component.find('lookupInput').getElement().value = ''
    },
    updateValueByFocusIndex: function(component, event, helper) {
        var focusIndex = component.get('v.focusIndex');

        if (focusIndex == null) {
            focusIndex = 0;
        }

        var records = component.get('v.records');

        if (focusIndex < records.length) {
            var tile = {
                title: records[focusIndex].label,
                subtitle: records[focusIndex].sublabel,
                hoverinfo: records[focusIndex].hoverinfo,
                recordId: records[focusIndex].recordId,
                status: records[focusIndex].status,
                type: records[focusIndex].type,
                readonly: records[focusIndex].readonly
            }
            
            var tiles = component.get('v.selectedOptionTiles');
            tiles.push(tile);
            component.set('v.selectedOptionTiles', tiles);

            var selectedRecordsIds = component.get('v.selectedRecordsIds');

            if($A.util.isEmpty(selectedRecordsIds)){
                selectedRecordsIds = records[focusIndex].recordId;
            } else {
                selectedRecordsIds += ';' + records[focusIndex].recordId;
            }

            component.set('v.selectedRecordsIds', selectedRecordsIds);
            component.find('lookupInput').getElement().value = '';
            component.set('v.records',[]);
            component.set('v.lastSearchTerm', '');
            component.set('v.componentHasChanges', true);

            helper.closeMenu(component, event, helper);
        }

        helper.closeMobileLookup(component, event, helper);
    },
    moveRecordFocusUp: function(component, event, helper) {
        var openMenu = component.get('v.openMenu');

        if (openMenu) {
            var focusIndex = component.get('v.focusIndex');
            var options = component.find('lookupMenu').getElement().getElementsByTagName('li');

            if (focusIndex === null || focusIndex === 0) {
                focusIndex = options.length - 1;
            } else {
                --focusIndex;
            }

            component.set('v.focusIndex', focusIndex);
        }
    },
    moveRecordFocusDown: function(component, event, helper) {
        var openMenu = component.get('v.openMenu');

        if (openMenu) {
            var focusIndex = component.get('v.focusIndex');
            var options = component.find('lookupMenu').getElement().getElementsByTagName('li');

            if (focusIndex === null || focusIndex === options.length - 1) {
                focusIndex = 0;
            } else {
                ++focusIndex;
            }

            component.set('v.focusIndex', focusIndex);
        }
    },
    removeOptionTile: function(component, event, sourceCmpValue) {
        
        var currentOptionTiles = component.get('v.selectedOptionTiles');
        
        var destroyedIndex;

        currentOptionTiles.forEach(function(tileObj, index){
            if(tileObj.recordId === sourceCmpValue){
                destroyedIndex = index;
            }
        });

        currentOptionTiles.splice(destroyedIndex, 1);
        component.set('v.selectedOptionTiles', currentOptionTiles);
    },
    removeFromComponentValue: function(component, event, sourceCmpValue) {
        
        var parentCmpValue = component.get('v.selectedRecordsIds');

        
        var valueArray = parentCmpValue.split(';');

        var valueIndex = valueArray.indexOf(sourceCmpValue);

        valueArray.splice(valueIndex, 1);

        var newValue = valueArray.join(';');
        component.set('v.selectedRecordsIds', newValue);
        component.set('v.componentHasChanges', true);
    },
    defineReadWriteMode: function(component, event, helper){
        var action = component.get('c.isCurrentUserEventOwner');
        action.setParams({
            sEventId: component.get('v.eventId')
        });
        
        action.setCallback(this, function(res){
            if (res.getState() === 'SUCCESS') {
                var isOwner = res.getReturnValue();
                component.set('v.componentReadOnly', !isOwner);
                component.set('v.disabled', !isOwner);
            }
        });
        
        $A.enqueueAction(action);
    },
    saveChanges: function(component, event, helper) {
        var saveChangesAction = component.get('c.saveChanges');

        saveChangesAction.setParams({
            sEventId: component.get('v.eventId'),
            sSelectedRecordsIds: component.get('v.selectedRecordsIds')
        });

        saveChangesAction.setCallback(this, function(res) {
            if (res.getState() === 'SUCCESS') {
                $A.get('e.force:refreshView').fire();
            }
            helper.checkIfInitialized(component, event, helper);
        });

        $A.enqueueAction(saveChangesAction);
    },
    defineContactIcon: function(component, event, helper){
        var action = component.get('c.isPersonAccountEnabled');
        
        action.setCallback(this, function(res){
            if (res.getState() === 'SUCCESS') {
                var isPersonAccountEnabled = res.getReturnValue();
                if (isPersonAccountEnabled){
                    component.set("v.iconContact", "standard:account")
                }
            }
        });
        
        $A.enqueueAction(action);
    },
    checkEventHierarchyAndInit: function(component, event, helper){
        var action = component.get('c.isChildEvent');

        action.setParams({
            sEventId: component.get('v.eventId')
        });
        
        action.setCallback(this, function(res){
            if (res.getState() === 'SUCCESS') {
                var sParentEvent = res.getReturnValue();
                if (sParentEvent == 'ParentEventNotFound'){
                    component.set("v.componentReadOnly", true);
                    component.set("v.disabled", true);
                    component.set("v.labelOrganizer", '');
                }else{
                    if(sParentEvent!=null) {
                        component.set("v.componentReadOnly", true);
                        component.set("v.disabled", true);
                        component.set("v.eventId", sParentEvent);
                    }
                }
                helper.getInitialInvitees(component, event, helper);
            }
        });
        
        $A.enqueueAction(action);

    }
})
/*
Copyright 2017 Appiphony, LLC

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the 
following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following 
disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following 
disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote 
products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/