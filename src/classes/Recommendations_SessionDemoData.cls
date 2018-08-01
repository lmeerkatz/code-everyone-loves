/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 2017
* @description Query to pull a demo pool of sessions to use in recommendations. If this were a real implementation,
* you'd want a more generic query builder that would allow you to pass parameters in instead of hard-coding values
* like location.
*/

public with sharing class Recommendations_SessionDemoData {
    public static Location defaultLocation = Location.newInstance(37.7831029,-122.4040588);

    /********************** NOT GREAT **********************/

    // Criteria:
    // - Session is in the future
    // - Session isn't full
    // - Session has a topic
    // - Name doesn't include 'private' 
    public static List<Session__c> getSessionsEligibleForRecommendationsHardCoded() {
        return [
            SELECT Id, Name, Location__c, Location__Latitude__s, Location__Longitude__s,
                Number_of_Attendees__c, Maximum_Attendees__c, Session_Date__c,
                Topics__c, Roles__c, Levels__c, Description__c
            FROM Session__c
            WHERE Session_Date__c >= TODAY AND
                (Maximum_Attendees__c = null OR
                    (Open_Slots__c != null AND Open_Slots__c > 0)) 
                AND Topics__c != null
                AND Name != '%private%'
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    /********************** BETTER **********************/

    // returns a list of eligible sessions
    // in a production scenario this should also be abstracted out
    // 
    // Include_in_Recommendations__c is a formula field. 
    // To revise the criteria edit the formula.
    public static List<Session__c> getSessionsEligibleForRecommendationsFormula() {
        return [
            SELECT Id, Name, Location__c, Location__Latitude__s, Location__Longitude__s,
                Number_of_Attendees__c, Maximum_Attendees__c, Session_Date__c,
                Topics__c, Roles__c, Levels__c, Description__c
            FROM Session__c
            WHERE Include_in_Recommendations__c = true 
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }

    /********************** BEST **********************/

    // returns a list of eligible sessions
    // in a production scenario this should also be abstracted out
    // 
    // Include_in_Recommendations_Stored__c =  
    // copy of Include_in_Recommendations__c formula field for query performance
    public static List<Session__c> getSessionsEligibleForRecommendationsStored() {
        return [
            SELECT Id, Name, Location__c, Location__Latitude__s, Location__Longitude__s,
                Number_of_Attendees__c, Maximum_Attendees__c, Session_Date__c,
                Topics__c, Roles__c, Levels__c, Description__c
            FROM Session__c
            WHERE Include_in_Recommendations_Stored__c = true 
            ORDER BY CreatedDate DESC
            LIMIT 200
        ];
    }


}