/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 2017
* @description Batch class to set Include in Recommendations Stored as a copy of the Include in Recommendations
* formula so we can index on that field and improve query performance for recommendations
*/
global class Recommendations_BatchUpdateSession implements Database.Batchable<SObject>, Schedulable {

    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([SELECT Id, Include_in_Recommendations__c, Include_in_Recommendations_Stored__c
        FROM   Session__c
        WHERE Include_in_Recommendations__c = true
        OR Include_in_Recommendations_Stored__c = true]);
    }

    global void execute(Database.BatchableContext BC, List<Session__c> sessions) {
        List<Session__c> sessionsToUpdate = new List<Session__c>();

        for (Session__c session : sessions){
            if (session.Include_in_Recommendations__c != session.Include_in_Recommendations_Stored__c) {
                sessionsToUpdate.add(new Session__c(
                    Id = session.Id,
                    Include_in_Recommendations_Stored__c = session.Include_in_Recommendations__c
                ));
            }
        }

        if (!sessionsToUpdate.isEmpty()) {
            Database.update(sessionsToUpdate, false);
        }
    }

    global void finish(Database.BatchableContext BC) {
        // Nothing to do here.
    }

    public static void scheduleProcess(String processName, String schedule) {
        Recommendations_BatchUpdateSession scheduler = new Recommendations_BatchUpdateSession();
        System.schedule(processName, schedule, scheduler);
    }

    global void execute(SchedulableContext sc) {
        Database.executeBatch(new Recommendations_BatchUpdateSession());
    }
}