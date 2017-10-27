/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 2017
* @description Geocoder implementation for demos. It's not hooked to a real service; It always returns the same coordinates.
*/
public with sharing class GEO_DemoGeocoder implements GEO_IGeocoder {

    private Geocoding_Settings__c settings;

    public GEO_DemoGeocoder() {
        settings = Geocoding_Settings__c.getInstance();
        if (settings == null) {
            throw new GEO_Geocoder.GeocodingException('Geocoding Settings have not been set.');
        } else if (settings.Class__c == null) {
            throw new GEO_Geocoder.GeocodingException('Required fields are missing from Geocoding Settings.');
        } else if (settings.Class__c != 'GEO_DemoGeocoder') {
            throw new GEO_Geocoder.GeocodingException(
                'GEO_DemoGeocoder can\'t be called directly when another service is set in Geocoding Settings.');
        }
    }

    /**
    * @description Provides the caller with the service name.
    * @return String The name of the geocoding service.
    */
    public String getServiceName(){
        return 'Demo Geocoding API';
    }

    /**
    * @description Tells the caller if the class supports batch geocoding.
    * @return Boolean
    */
    public Boolean supportsBatch(){
        return false;
    }

    /**
    * @description Returns geocoding results for a list of addresses.
    * @param addresses The list of addresses to be geocoded.
    * @return List<Geocoding_Result__c> The list of geocoding results.
    */
    public List<Geocoding_Result__c> geocodeAddresses(List<GEO_Address> addresses) {

        // since this doesn't support batch, remove all but the first record
        addresses = new List<GEO_Address>{ addresses[0] };

        List<Geocoding_Result__c> results = new List<Geocoding_Result__c>();

        results.add(new Geocoding_Result__c(
            Geocoding_Service__c = this.getServiceName(),
            Requested_Address__c = addresses[0].getQueryString(),
            Geocoded_Address__c = addresses[0].getQueryString(),
            Confidence__c = 10,
            Location__Latitude__s = 37.7831029,
            Location__Longitude__s = -122.4062475,
            Related_Record_Id__c = addresses[0].recordId,
            Score__c = 10,
            Scoring_Method__c = 'Value hard-coded for demo'
        ));

        return results;
    }


}