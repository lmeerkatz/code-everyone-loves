public class GEO_Address {
    public String street;
    public String city;
    public String state;
    public String postalCode;
    public String country;
    public Id recordId; // the origin of this address

    public String getQueryString() {
        Set<String> query = new Set<String>();
        if (street != null) {
            query.add(street);
        }
        if (city != null) {
            query.add(city);
        }
        if (state != null) {
            query.add(state);
        }
        if (postalCode != null) {
            query.add(postalCode);
        }
        if (country != null) {
            query.add(country);
        }
        return String.join((Iterable<String>)query, ',');
    }
}