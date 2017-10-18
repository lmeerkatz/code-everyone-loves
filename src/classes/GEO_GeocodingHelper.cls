/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 2017
* @description Support methods for geocoding. All logic that isn't specific to the geocoding service being used.
*/
public with sharing class GEO_GeocodingHelper {

    /**
    * @description Converts addresses from records to generic addresses
    * @param recordIds A list of Ids for the records that will provide the address data
    * @return List<GEO_Address> The list of addresses
    */
    public static List<GEO_Address> convertRecordsToAddresses(List<Id> recordIds){
        // get object type
        String sObjectName = recordIds[0].getSObjectType().getDescribe().getName();

        // get the address fields for this sobject
        Geocoding_Field_Map__c fieldMap = GEO_GeocodingHelper.fieldMapSettings.get(sObjectName);

        // the fields for address in an address map setting
        List<String> addressFields = new List<String>{
            'Street_Field__c', 'City_Field__c', 'State_Field__c', 'Postal_Code_Field__c', 'Country_Field__c'
        };

        // add the address fields to the query string
        Set<String> fields = new Set<String>{};

        for (String addressField : addressFields) {
            if (fieldMap.get(addressField) != null) {
                String fieldName = (String)fieldMap.get(addressField);
                // confirm that field actually exists for this object
                if (!DescribeUtil.isValidFieldName(sObjectName, fieldName)) {
                    throw new GEO_Geocoder.GeocodingException(fieldName + ' is not a valid field for ' +
                        sObjectName + '. Value for ' + addressField + ' in Geocoding Field Map ' + fieldMap.Name +
                        ' needs to be updated');
                } else {
                    fields.add(fieldName);
                }
            }
        }

        if (fields.isEmpty()) {
            throw new GEO_Geocoder.GeocodingException(
                'Field map for ' + sObjectName + ' does not contain any valid address fields');
        }

        // query for records
        String query = 'SELECT ' + String.join((Iterable<String>)fields, ', ') + ' FROM ' + sObjectName +
            ' WHERE Id IN :recordIds';
        Map<Id, SObject> records = new Map<Id, SObject>(Database.query(query));

        // convert record addresses to geocoding addresses
        List<GEO_Address> addresses = new List<GEO_Address>();

        GEO_Address addr;

        for (SObject record : records.values()) {
            addr = new GEO_Address();
            addr.recordId = record.Id;

            if (fieldMap.get('Street_Field__c') != null) {
                addr.street = (String)record.get(fieldMap.Street_Field__c);
            }
            if (fieldMap.get('City_Field__c') != null) {
                addr.city = (String)record.get(fieldMap.City_Field__c);
            }
            if (fieldMap.get('State_Field__c') != null) {
                addr.state = (String)record.get(fieldMap.State_Field__c);
            }
            if (fieldMap.get('Postal_Code_Field__c') != null) {
                addr.postalCode = (String)record.get(fieldMap.Postal_Code_Field__c);
            }
            if (fieldMap.get('Country_Field__c') != null) {
                addr.country = (String)record.get(fieldMap.Country_Field__c);
            }
            addresses.add(addr);
        }

        return addresses;
    }

    /**
    * @description Updates a list of records with geolocation data. Optionally saves individual geocoding results.
    * @param results The list of geocoding results that will be scored and used to update records. These include a
    * reference to the address that was requested, which includes the originating record Id.
    * @param saveGeocodingResults Flag to determine whether individual Geocoding Result records should be saved.
    * @return List<SObject> The updated records.
    */
    public static List<SObject> updateRecords(List<Geocoding_Result__c> results, Boolean saveGeocodingResults) {
        Map<Id, SObject> records = new Map<Id, SObject>();
        SObject record;

        String sObjectName = ((Id)results[0].Related_Record_Id__c).getSObjectType().getDescribe().getName();
        Geocoding_Field_Map__c fieldMap = GEO_GeocodingHelper.fieldMapSettings.get(sObjectName);

        Map<String, Object> populatedFields = fieldMap.getPopulatedFieldsAsMap();
        if (populatedFields.get('Latitude_Field__c') == null || populatedFields.get('Longitude_Field__c') == null) {
            throw new GEO_Geocoder.GeocodingException(
                'Latitude and longitude fields must be set in Address Field Map settings for ' + sObjectName);
        }

        // sort results by confidence
        results = sort(results);

        // map results back to lat/long fields
        for (Geocoding_Result__c result : results) {
            if (!records.containsKey(result.Related_Record_Id__c)) {
                record = Schema.getGlobalDescribe().get(sObjectName).newSObject();
                record.Id = result.Related_Record_Id__c;
                record.put((String)fieldMap.get('Latitude_Field__c'), result.Location__Latitude__s);
                record.put((String)fieldMap.get('Longitude_Field__c'), result.Location__Longitude__s);
                records.put(record.Id, record);
            }

            // this assumes the results are sorted with winning result first
            result.Winning_Result__c = (result == results[0] ? true : false);

            // if we have a lookup for this type of record on the geocoding result, populate it
            String lookupField = getLookupFieldName((Id)result.Related_Record_Id__c);
            if (lookupField != null) {
                result.put(lookupField, (Id)result.Related_Record_Id__c);
            }
        }

        // update records
        if (!records.isEmpty()) {
            update records.values();
        }

        if (saveGeocodingResults && !results.isEmpty()) {
            insert results;
        }

        return records.values();
    }

    // sObjectName => field map setting
    @TestVisible
    private static Map<String, Geocoding_Field_Map__c> fieldMapSettings {
        get {
            if (fieldMapSettings == null) {
                fieldMapSettings = new Map<String, Geocoding_Field_Map__c>();
                // this assumes there's only one map per object
                // we may want to expand to the allow for geocoding multiple address fields on an object
                for (Geocoding_Field_Map__c fieldMap : Geocoding_Field_Map__c.getAll().values()){
                    fieldMapSettings.put(fieldMap.SObject_Name__c, fieldMap);
                }
            }
            return fieldMapSettings;
        }
        set;
    }

    /**
    * @description Returns the name of the lookup field that matches the sObject type of the provided record.
    * The field will match if the field name matches to the object name and the record's object type matches
    * the type of object the field refers to.
    * @param recordId The record we're matching against
    * @return String The name of the lookup field, if there is one. Will return null if there is no matching field.
    */
    public static String getLookupFieldName(Id recordId) {
        String sObjectName = recordId.getSObjectType().getDescribe().getName();

        // if we have a lookup for this type of record on the geocoding result, populate it
        // the lookup field must match the name of the object and the reference must be to the same type of sobject
        if (Schema.SObjectType.Geocoding_Result__c.fields.getMap().containsKey(sObjectName)) {
            Schema.DescribeFieldResult describe =
                Schema.SObjectType.Geocoding_Result__c.fields.getMap().get(sObjectName).getDescribe();
            if (describe.getReferenceTo().size() > 0 &&
                describe.getReferenceTo()[0].getDescribe().getName() == sObjectName) {
                return sObjectName;
            }
        } else if (Schema.SObjectType.Geocoding_Result__c.fields.getMap().containsKey(sObjectName + '__c')) {
            Schema.DescribeFieldResult describe =
                Schema.SObjectType.Geocoding_Result__c.fields.getMap().get(sObjectName  + '__c').getDescribe();
            // this will support lookups to standard objects
            if (describe.getReferenceTo()[0].getDescribe().getName() == sObjectName) {
                return sObjectName  + '__c';
            }
        }
        return null;
    }

    /**
    * @description Returns a list of Geocoding Results sorted by Score (descending)
    * // TODO: replace this with more flexible sorting?
    * @param unsortedResults The list to be sorted
    * @return List<Geocoding_Result__c> The sorted list (highest score listed first)
    */
    private static List<Geocoding_Result__c> sort(List<Geocoding_Result__c> unsortedResults) {
        // convert unsorted list to list of wrappers
        List<GeocodingResultWrapper> wrappers = new List<GeocodingResultWrapper>();
        for (Geocoding_Result__c result : unsortedResults) {
            wrappers.add(new GeocodingResultWrapper(result));
        }

        // sort wrapper list
        wrappers.sort();

        List<Geocoding_Result__c> sortedResults = new List<Geocoding_Result__c>();
        // convert back to sobject
        for (GeocodingResultWrapper wrapper : wrappers) {
            sortedResults.add(wrapper.result);
        }
        return sortedResults;
    }

    private class GeocodingResultWrapper implements Comparable {
        private Geocoding_Result__c result;
        private GeocodingResultWrapper(Geocoding_Result__c result) {
            this.result = result;
        }

        // implement compareTo so we can sort by score
        // this will list the records with the highest confidence first
        public Integer compareTo(Object compareTo) {
            GeocodingResultWrapper compareToResult = (GeocodingResultWrapper)compareTo;
            Integer returnValue = 0;
            if (this.result.Score__c < compareToResult.result.Score__c) {
                return 1;
            } else if (this.result.Score__c > compareToResult.result.Score__c) {
                return -1;
            }
            return returnValue;
        }
    }
}