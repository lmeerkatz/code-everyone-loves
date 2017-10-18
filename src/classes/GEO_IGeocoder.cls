/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 2017
* @description Interface for geocoding services. Classes that implement this interface can be called by GEO_Geocoder.
*/
public interface GEO_IGeocoder {

    /**
    * @description Provides the caller with the service name.
    * @return String The name of the geocoding service.
    */
    String getServiceName();

    /**
    * @description Tells the caller if the class supports batch geocoding.
    * @return Boolean True is the class supports batch geocoding. False otherwise.
    */
    Boolean supportsBatch();

    /**
    * @description Returns geocoding results for a list of addresses.
    * @param addresses The list of addresses to be geocoded.
    * @return List<Geocoding_Result__c> The list of geocoding results.
    */
    List<Geocoding_Result__c> geocodeAddresses(List<GEO_Address> addresses);
}