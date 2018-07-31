/**
* Copyright (c) 2018, Salesforce.org
* @author Laura Meerkatz
* @date 2018
* @description Class for managing access to Credential records
*/
public with sharing class Credentials {
    public static Credential__c getCredentialByName(String name) {
        return credentials.get(name);
    }

    private static Map<String, Credential__c> credentials {
        get {
            if (credentials == null) {
                credentials = new Map<String, Credential__c>();
                // if this were production code, you'd want an FLS check here
                for (Credential__c credential : ([
                    SELECT Id, Name, API_Key__c, App_Code__c, Endpoint__c
                    FROM Credential__c
                ])) {
                    credentials.put(credential.Name, credential);
                }
            }
            return credentials;
        }
        set;
    }
}