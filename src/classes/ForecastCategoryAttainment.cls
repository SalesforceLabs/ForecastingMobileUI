/**
This class represents the forecast components
of a specific forecast period and forecast type.
*/
public class ForecastCategoryAttainment {
    public Decimal closedAmount {get; set;}
    public Decimal commitAmount {get; set;}
    public Decimal bestcaseAmount {get; set;}
    public Decimal quota {get; set;}
    public String unitsPrefix { get; set; }

    public String forecastTypeStr { get; set; }
    public Id forecastingItemId { get; set; }
    public List<Opportunity> relatedOpptys {get; set; }
    
    public Decimal getClosedPercent() {
    	return closedAmount.divide((closedAmount + commitAmount + bestcaseAmount)/100,2);
    }
    
    public Decimal getCommitPercent() {
    	return commitAmount.divide((closedAmount + commitAmount + bestcaseAmount)/100,2);
    }
    
    public Decimal getQuotaPercent() {
    	return quota.divide((closedAmount + commitAmount + bestcaseAmount)/100,2);
    }
    
    public Decimal getQuotaAttainmentPercent() {
    	return closedAmount.divide(quota/100,2);
    }
    
    public String getClosedAmountStr() { return addPrefixAndZeros(closedAmount); }
    public String getCommitAmountStr() { return addPrefixAndZeros(commitAmount); }
    public String getBestcaseAmountStr() { return addPrefixAndZeros(bestcaseAmount); }
    public String getQuotaAmountStr() { return addPrefixAndZeros(quota); }
    public String getQuotaRemainingStr() { 
        Decimal remaining = quota - closedAmount;
        if (remaining < 0)
            remaining = 0;
        return addPrefixAndZeros(remaining);
    }
    
    private String addPrefixAndZeros(Decimal dec) {
	    // Make the number display with two digits after the decimal. 
	    dec.setScale(2);
	    String s = dec.format();
	    integer decimalLocation = s.lastIndexOf('.');
        if (decimalLocation == s.length()-2) {
            // if there's only one digit after the period
            // strip it if non-currency, else add a 0.
            if (unitsPrefix == null)
                s = s.left(decimalLocation);
            else
                s += '0';
        }
        if (unitsPrefix != null)
            s = unitsPrefix + s;
	    return s;
    }
    
}