public class QuotaAttainmentController {
    private List<String> forecastCategoryList = initForecastCategories();
    Id forecastingTypeId = ForecastingTypeUtil.types.get(0).Id;
    ForecastingType selectedType = ForecastingTypeUtil.types.get(0);
    Id periodId = getCurrentPeriod(true);

    private List<ForecastingItem> forecastingItems = getForecastingItems();
    private List<ForecastingQuota> forecastingQuotas = getForecastingQuotas();

    private Double quotaValue = getQuotaValue();

    public String getQuotaString() {
        return quotaValue.format();
    }
    
    public String getSelectedForecastingType() {
        return forecastingTypeId;
    }
    
    public void setSelectedForecastingType(Id selectedId) {
        forecastingTypeId = selectedId;
        selectedType = ForecastingTypeUtil.getForecastingTypeById(selectedId);
    }
    
    public void onChangeForecastType() {
        selectedType = ForecastingTypeUtil.getForecastingTypeById(forecastingTypeId);        
    }
    
    public static List<SelectOption> getActiveForecastingTypes() {
        return ForecastingTypeUtil.getActiveForecastingTypesAsOptions();
    }
       
    
    public List<CumulativeAmount> getAttainments() {
        List<CumulativeAmount> ret = new List<CumulativeAmount>();
        for(Integer i = 0; i < forecastingItems.size(); i++) {
            ForecastingItem item = forecastingItems.get(i);
            CumulativeAmount c = new CumulativeAmount();
            c.category = item.ForecastCategoryName;
            c.amount = selectedType.IsAmount ? item.ForecastAmount : item.ForecastQuantity;
            if (c.amount == null)
                c.amount = 0;
      
            if (i > 0) {
                c.category += ' + ' + ret.get(i-1).category;
                c.amount += ret.get(i-1).amount;
            }
            System.debug(loggingLevel.INFO, 'Save:' + c.category + ', ' + c.amount);
            ret.add(c);
            System.debug(loggingLevel.INFO, 'Size=' + ret.size());
        }
        return ret;
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
        Id userId = Id.valueOf(UserInfo.getUserId());
        List<ForecastingQuota> ret = [SELECT QuotaAmount, QuotaQuantity, IsAmount, IsQuantity FROM ForecastingQuota
                                         WHERE QuotaOwnerId=:userId AND PeriodId=:periodId AND ForecastingTypeId=:forecastingTypeId];
        return ret;
    }
        
    private List<ForecastingItem> getForecastingItems() {
        // TODO: Handle different categories, forecasting types, unadjusted value, owner-only, product family, monthly/quarterly
        // TODO: Handle different levels: closed, closed+commit, closed+commit+best case, etc. Need to map
        //       forecasting status category to the category's label, which is the one that is recorded in ForecastingItem
        //       e.g. Closed2 may be the label, and it corresponds to Closed status category.
        Id userId = Id.valueOf(UserInfo.getUserId());
        System.debug(loggingLevel.INFO, 'forecastingTypeId: ' + forecastingTypeId);
	    System.debug(loggingLevel.INFO, 'userId: ' + userId);
	    System.debug(loggingLevel.INFO, 'periodId: ' + periodId);

        
        List<ForecastingItem> items = [SELECT ForecastCategoryName, IsAmount, IsQuantity, ForecastAmount, ForecastQuantity, HasAdjustment
                                       FROM ForecastingItem where OwnerId=:userId AND PeriodId=:periodId AND ForecastingTypeId=:forecastingTypeId];

        // Make a hashmap to the forecasting items, with the key being the category.
        Map<String,ForecastingItem> itemsByCategory = initItemsByCategory(items);
        items.clear();

        System.debug(loggingLevel.INFO, 'Items hashmap: ' + itemsByCategory);

        // Put the items in the same order as the forecast categories. 
        for (String category : forecastCategoryList) {
            if (itemsByCategory.containsKey(category))
                items.add(itemsByCategory.get(category));
        }
        return items;
    }
 
    // Make a hashmap to the forecasting items, with the key being the category.
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
		// Sort in reverse order
        for (Integer i = picklist.size() - 1; i>=0; i--) {
            Schema.PicklistEntry p = picklist.get(i);
            if (p.isActive())
                ret.add(p.getLabel());            
        }
        
        return ret;
    }
    
}