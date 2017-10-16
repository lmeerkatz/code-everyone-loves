/**
* @author Laura Meerkatz
* @date 10/12/2017
* @description Geocoder implementation for HERE.com API
*/
public with sharing class GEO_HereGeocoder implements GEO_IGeocoder {

    private Geocoding_Settings__c settings;

    public GEO_HereGeocoder() {
        settings = Geocoding_Settings__c.getInstance();
        if (settings == null) {
            throw new GEO_Geocoder.GeocodingException('Geocoding Settings have not been set.');
        } else if (settings.Class__c == null ||
            settings.API_Key__c == null ||
            settings.App_Code__c == null ||
            settings.Endpoint__c == null) {
            throw new GEO_Geocoder.GeocodingException('Required fields are missing from Geocoding Settings.');
        } else if (settings.Class__c != 'GEO_HereGeocoder') {
            throw new GEO_Geocoder.GeocodingException(
                'GEO_OpenCageGeocoder can\'t be called directly when another service is set in Geocoding Settings.');
        }
    }

    /**
    * @description Provides the caller with the service name.
    * @return String The name of the geocoding service.
    */
    public String getServiceName(){
        return 'HERE.com Geocoding API';
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

        // if we've got a valid country code, use it
        String country = (addresses[0].country != null && addresses[0].country.length() == 2) ?
            addresses[0].country : null;

        // String address, String country, String language, Integer max
        GEO_HereData.GeocoderResponse response =
            geolocate(addresses[0], Integer.valueOf(settings.Maximum_Results__c));

        List<Geocoding_Result__c> results = new List<Geocoding_Result__c>();

        if (!response.Response.View.isEmpty()) {
            System.debug('response.Response.View.size(): ' + response.Response.View.size());
            for (GEO_HereData.Result apiResult : response.Response.View[0].Result) {
                results.add(new Geocoding_Result__c(
                    Geocoding_Service__c = this.getServiceName(),
                    Requested_Address__c = addresses[0].getQueryString(),
                    Geocoded_Address__c = apiResult.Location.Address.Label,
                    Confidence__c = apiResult.Relevance,
                    Location__Latitude__s = apiResult.Location.DisplayPosition.Latitude,
                    Location__Longitude__s = apiResult.Location.DisplayPosition.Longitude,
                    Related_Record_Id__c = addresses[0].recordId,
                    Score__c = apiResult.Relevance,
                    Scoring_Method__c = 'Using Relevance provided by HERE.com'
                ));
                System.debug('Relevance: ' + apiResult.Relevance);
                System.debug('MatchLevel: ' + apiResult.MatchLevel);
                System.debug('MatchQuality: ' + apiResult.MatchQuality);
                System.debug('MatchType: ' + apiResult.MatchType);
                System.debug('Latitude: ' + apiResult.Location.DisplayPosition.Latitude);
                System.debug('Longitude: ' + apiResult.Location.DisplayPosition.Latitude);

            }
        }

        return results;
    }

    /**
    * @description Geocodes an address, returning the complete results from the OpenCage API
    * @param address The address you want to geocode
    * @param country Country code to limit the scope of the search (or multiple codes separated by commas)
    * @param language Optional preferred language code for results
    * @param max Maximum number of results to return (if null, returns 1 result)
    * @return GeocodeResponse object
    */
    public GEO_HereData.GeocoderResponse geolocate(GEO_Address address, Integer max) {
        GEO_HereData.GeocoderResponse gr;

        String requestParameters =
            constructQuery(address) +
                '&maxresults=' + max;

        String responseJson = callHereDotCom(requestParameters);
        if (responseJson != null) {
            System.debug(responseJson);
            responseJson = responseJson.replaceAll('"_type"', '"type"');

            gr = ((GEO_HereData.GeocoderResponse)(JSON.deserialize(responseJson, GEO_HereData.GeocoderResponse.class)));

        }
        return gr;
    }

    private String constructQuery(GEO_Address address) {
        String query;

        // country is required to pass in specific address parts; otherwise use searchText for all parts
        if (address.country != null) {
            query =
                // TODO: parse out housenumber + street?
                (address.street != null ? '&searchText=' + EncodingUtil.urlEncode(address.street, 'UTF-8') : '') +
                    (address.city != null ? '&city=' + EncodingUtil.urlEncode(address.city, 'UTF-8') : '') +
                    (address.state != null ? '&state=' + EncodingUtil.urlEncode(address.state, 'UTF-8') : '') +
                    (address.postalCode != null ? '&postalcode=' + EncodingUtil.urlEncode(address.postalCode, 'UTF-8') : '') +
                    (address.country != null ? '&country=' + EncodingUtil.urlEncode(address.country, 'UTF-8') : '');
            System.debug('with country: ' + query);
        } else {
            query =
                '&searchText=' + EncodingUtil.urlEncode(address.getQueryString(), 'UTF-8');
            System.debug('without country: ' + query);
        }
        return query.trim();
    }

    private String callHereDotCom(String query) {
        HttpRequest http = new HttpRequest();

        http.setEndpoint(settings.Endpoint__c +
            '?app_id=' + settings.API_Key__c +
            '&app_code=' + settings.App_Code__c +
            query);

        http.setMethod('GET');
        Integer timeout = settings.Timeout_Seconds__c != null ?
            Integer.valueOf(settings.Timeout_Seconds__c) * 1000 : 20000;
        http.setTimeout(timeout);

        String response;
        Integer statusCode;
        Http con = new Http();
        HttpResponse hs = new HttpResponse();
        //System.debug(LoggingLevel.WARN, 'HERE.com request >>>> \n' + String.valueOf(http) + '\n');
        hs = con.send(http);

        if (hs.getStatusCode() != 2100) {
            //System.debug(LoggingLevel.WARN, 'HERE.com response >>>>\n'+ hs.getBody() + '\n');
            return hs.getBody();
        } else {
            Integer status = hs.getStatusCode();
            String err = 'Rats! HERE.com returned status code ' + String.valueOf(status);
            GEO_Geocoder.GeocodingException ge = new GEO_Geocoder.GeocodingException(err);
            throw ge;
        }
    }
}