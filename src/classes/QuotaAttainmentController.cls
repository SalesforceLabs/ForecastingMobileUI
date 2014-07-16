public class QuotaAttainmentController {
    private List<String> forecastCategoryList = initForecastCategories();
    private List<ForecastingItem> forecastingItems = getForecastingItems();
    private List<ForecastingQuota> forecastingQuotas = getForecastingQuotas();

    private Double closedValue = getClosedValue();
    private Double quotaValue = getQuotaValue();

    public String getClosedString() {
        return closedValue.format();        
    }
    
    public String getQuotaString() {
        return quotaValue.format();
    }
    
    public Double getClosedValue() {
        Double ret = null;
        for (ForecastingItem item : forecastingItems) {
            if (item.ForecastCategoryName == 'Closed2' && item.ForecastAmount != null) {
                ret = item.ForecastAmount;
                break;
            }
        }
        return ret == null ? 0 : ret;
    }
    
    public Double getQuotaValue() {
        Double ret = null;
        for (ForecastingQuota quota : forecastingQuotas) {
            if (quota.IsAmount) {
                ret = quota.QuotaAmount;
                break;
            }
        }
        return ret == null ? 0 : ret;
    }
    
    private List<ForecastingQuota> getForecastingQuotas() {
        Id periodId = getCurrentPeriod(true);
        Id userId = Id.valueOf(UserInfo.getUserId());
        List<ForecastingQuota> ret = [SELECT QuotaAmount, QuotaQuantity, IsAmount, IsQuantity FROM ForecastingQuota
                                         WHERE QuotaOwnerId=:userId AND PeriodId=:periodId];
        return ret;
    }
    
    public String getAttainmentString() {
        Double attain = 0;
        if (quotaValue > 0 && closedValue > 0)
            attain = closedValue / quotaValue * 100;
        return attain.format() + '%';
    }
    
    private List<ForecastingItem> getForecastingItems() {
        // TODO: Handle different categories, forecasting types, unadjusted value, owner-only, product family, monthly/quarterly
        // TODO: Handle different levels: closed, closed+commit, closed+commit+best case, etc. Need to map
        //       forecasting status category to the category's label, which is the one that is recorded in ForecastingItem
        //       e.g. Closed2 may be the label, and it corresponds to Closed status category.
        Id periodId = getCurrentPeriod(true);
        Id userId = Id.valueOf(UserInfo.getUserId());

        List<ForecastingItem> items = [SELECT ForecastCategoryName, IsAmount, IsQuantity, ForecastAmount, ForecastQuantity, HasAdjustment
                                       FROM ForecastingItem where OwnerId=:userId AND PeriodId=:periodId];

        Map<String,ForecastingItem> itemsByCategory = initItemsByCategory(items);
        items.clear();

        // Put the items in the same order as the forecast categories. 
        for (String category : forecastCategoryList) {
            if (itemsByCategory.containsKey(category))
                items.add(itemsByCategory.get(category));
        }
        return items;
    }
 
    private Map<String,ForecastingItem> initItemsByCategory(List<ForecastingItem> items) {
   		Map<String,ForecastingItem> ret = new Map<String,ForecastingItem>();
        for (ForecastingItem item : items) {
            ret.put(item.ForecastCategoryName, item);
        }
		return ret;
    }
    
    private Id getCurrentPeriod(Boolean isQuarterly) {
        String typeString = isQuarterly ? 'Quarter' : 'Month';
        List<Period> periods = [SELECT Id FROM Period Where Type=:typeString AND 
                                EndDate >= TODAY AND StartDate <= TODAY 
                                ORDER BY StartDate DESC LIMIT 1];
        if (periods == null || periods.size() == 0)
           return null;
        return periods.get(0).Id;
    }
    
    private List<String> initForecastCategories() {
        
    	List<String> ret = new List<String>();
        
    	Schema.DescribeFieldResult f = Schema.sObjectType.ForecastingItem.fields.ForecastCategoryName;
    	List<Schema.PicklistEntry> picklist = f.getPicklistValues();
        for (Schema.PicklistEntry p : picklist) {
            if (p.isActive())
                ret.add(p.getLabel());
        }
        
        return ret;
    }
    
}