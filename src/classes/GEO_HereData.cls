/**
* Copyright (c) 2017, Salesforce.org
* @author Laura Meerkatz
* @date 2017
* @description Data structure for data returned from HERE.com API
*/
public with sharing class GEO_HereData {

    // Custom data types for response data
    public class AdditionalData {
        public String value;
        public String key;
    }

    public class Response {
        public MetaInfo MetaInfo;
        public List<View> View;
    }

    public class MatchQuality {
        public Double Country;
        public Double State;
        public Double City;
        public List<Double> Street;
        public Double HouseNumber;
        public Double PostalCode;
    }

    public class DisplayPosition {
        public Double Latitude;
        public Double Longitude;
    }

    public class Address {
        public String Label;
        public String Country;
        public String State;
        public String County;
        public String City;
        public String District;
        public String Street;
        public String HouseNumber;
        public String PostalCode;
        public List<AdditionalData> AdditionalData;
    }

    public class GeocoderResponse {
        public Response Response;
    }

    public class MetaInfo {
        public String Timestamp;
    }

    public class MapView {
        public DisplayPosition TopLeft;
        public DisplayPosition BottomRight;
    }

    public class View {
        public String type;
        public Integer ViewId;
        public List<Result> Result;
    }

    public class Location {
        public String LocationId;
        public String LocationType;
        public DisplayPosition DisplayPosition;
        public List<DisplayPosition> NavigationPosition;
        public MapView MapView;
        public Address Address;
    }

    public class Result {
        public Double Relevance;
        public String MatchLevel;
        public MatchQuality MatchQuality;
        public String MatchType;
        public Location Location;
    }
}