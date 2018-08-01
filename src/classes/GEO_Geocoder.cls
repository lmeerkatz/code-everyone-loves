/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 2017
* @description Generic geocoder that calls other geocoding classes based on custom setting
*/
public with sharing class GEO_Geocoder {
    private static Geocoding_Settings__c settings = Geocoding_Settings__c.getInstance();

    private GEO_IGeocoder geocoder {
        get {
            if (geocoder == null) {
                // if we're missing key settings, we can't geocode
                if (settings == null) {
                    throw new GeocodingException('Geocoding Settings are missing');
                } else if (settings.Class__c == null || settings.Credential_Name__c == null) {
                    throw new GeocodingException('Geocoding Settings are incomplete');
                }

                // if the class name listed in the setting isn't actually a class, we can't geocode
                Type classType = Type.forName(settings.Class__c);
                if (classType == null) {
                    throw new GeocodingException('Invalid Class in Geocoding Settings: ' + settings.Class__c);
                }

                // if the class doesn't implement the geocoding interface, we can't call it
                Object classInstance = classType.newInstance();
                if (!(classInstance instanceof GEO_IGeocoder)) {
                    throw new GeocodingException('Class ' + settings.Class__c + ' must implement GEO_IGeocoder');
                }
                geocoder = (GEO_IGeocoder)classInstance;
            }
            return geocoder;
        }
        set;
    }

    /**
    * @description Returns the name of the geocoding service being called.
    * @return String The name of the service.
    */
    public String getServiceName(){
        return geocoder.getServiceName();
    }

    /**
    * @description Indicates whether the current service supports batch geocoding.
    * @return Boolean
    */
    public Boolean supportsBatch(){
        return geocoder.supportsBatch();
    }

    /**
    * @description Geocodes a list of addresses
    * @param addresses The list of addresses to geocode.
    * @return List<Geocoding_Result__c> List of geocoding results.
    */
    public List<Geocoding_Result__c> geocodeAddresses(List<GEO_Address> addresses) {
        if (!addresses.isEmpty()) {
            List<Geocoding_Result__c> results = geocoder.geocodeAddresses(addresses);
            return results;
        }
        return null;
    }

    /**
    * @description Updates a list of records with geocoding data (latitude/longitude).
    * @param recordIds A list of Ids of the records to be updated.
    * @return List<SObject> The updated records.
    */
    public List<SObject> geocodeRecords(List<Id> recordIds) {
        if (!recordIds.isEmpty()) {
            if (!geocoder.supportsBatch()) {
                // if this service doesn't support batch, remove all but the first record
                recordIds = new List<Id>{ recordIds[0] };
            }

            // convert records to addresses
            List<GEO_Address> addresses = GEO_GeocodingHelper.convertRecordsToAddresses(recordIds);

            // geocode addresses
            List<Geocoding_Result__c> results = geocoder.geocodeAddresses(addresses);

            // if no results are found
            if (results.isEmpty()) {
                // if we're saving results, save an empty result for each address
                if (settings.Save_Geocoding_Results__c) {
                    List<Geocoding_Result__c> emptyResults = new List<Geocoding_Result__c>();

                    // see if we have a lookup for this type of record on the geocoding result
                    String lookupField = GEO_GeocodingHelper.getLookupFieldName((Id)addresses[0].recordId);

                    Geocoding_Result__c emptyResult;

                    for (GEO_Address address : addresses) {
                        emptyResult = new Geocoding_Result__c(
                            Geocoding_Service__c = geocoder.getServiceName(),
                            Requested_Address__c = address.getQueryString(),
                            Geocoded_Address__c = 'No results found',
                            Related_Record_Id__c = address.recordId
                        );
                        if (lookupField != null) {
                            emptyResult.put(lookupField, address.recordId);
                        }
                        emptyResults.add(emptyResult);
                    }
                    insert emptyResults;
                } // otherwise do nothing
                return null;
            }

            // update records
            List<SObject> records = GEO_GeocodingHelper.updateRecords(results, settings.Save_Geocoding_Results__c);

            return records;

        }
        return null;
    }

    /**
    * @description @Future method for calling geocodeRecords()
    * @param recordIds A list of Ids of the records to be updated.
    * @return void
    */
    @future(callout=true)
    public static void geocodeRecordsFuture(List<Id> recordIds){
        GEO_Geocoder geocoder = new GEO_Geocoder();
        try {
            geocoder.geocodeRecords(recordIds);
        } catch (GEO_Geocoder.GeocodingException ex) {
            // TODO: log error
        }
    }

    /**
    * @description @Invocable method for calling geocodeRecords()
    * @param recordIds A list of Ids of the records to be updated.
    * @return void
    */
    @InvocableMethod(label='Geocode Records' description='Requests geocoding data and updates the records.')
    public static void geocodeRecordsInvocable(List<Id> recordIds) {
        geocodeRecordsFuture(recordIds);
    }

    public class GeocodingException extends Exception {}
}