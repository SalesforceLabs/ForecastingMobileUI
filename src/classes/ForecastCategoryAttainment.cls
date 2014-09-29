/**
This class represents the forecast components
of a specific forecast period and forecast type.
*/
public class ForecastCategoryAttainment {
    public Decimal closedAmount {get; set;}
    public Decimal commitAmount {get; set;}
    public Decimal bestcaseAmount {get; set;}
    public Decimal quota {get; set;}
    
    public String closedCategoryStr { get; set; }
    public String commitCategoryStr { get; set; }
    public String bestcaseCategoryStr { get; set; }
    
    public Id closedForecastingItemId { get; set; }
    public Id commitForecastingItemId { get; set; }
    public Id bestcaseForecastingItemId { get; set; }
    
    public String unitsPrefix { get; set; }
    public String timeRemainingInPeriod { get; set; }

    public String forecastTypeStr { get; set; }
    public Id forecastingItemId { get; set; }
    
    public ForecastCategoryAttainment() {
        closedAmount = 0;
        commitAmount = 0;
        bestcaseAmount = 0;
        quota = 0;
        unitsPrefix = '';
        timeRemainingInPeriod = '';
        forecastTypeStr = '';
    }
    
    public Decimal sumPipeline() {
        return closedAmount + commitAmount + bestcaseAmount;
    }
    
    public Decimal getClosedPercent() {
      return sumPipeline() == 0 ? 0 : closedAmount.divide(Math.max(sumPipeline(),quota)/100,2);
    }
    
    public Decimal getCommitPercent() {
      return sumPipeline() == 0 ? 0 : commitAmount.divide(Math.max(sumPipeline(),quota)/100,2);
    }
    
    public Decimal getQuotaPercent() {
      return sumPipeline() == 0 ? 0 : quota.divide(Math.max(sumPipeline(),quota)/100,2);
    }
    
    public Decimal getQuotaAttainmentPercent() {
       return quota == 0 ? 0 : closedAmount.divide(quota/100,2);
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
        if (decimalLocation > 0 && decimalLocation == s.length()-2) {
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