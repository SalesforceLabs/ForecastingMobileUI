public with sharing class QuotaAttainmentController {
    Id periodId = getCurrentPeriod(true);
    Id userId = Id.valueOf(UserInfo.getUserId());

    private List<ForecastingItem> forecastingItems = getForecastingItems();

    public QuotaAttainmentController() {
        ForecastingTypeUtil.initTypesMap();
    }
    
    private Boolean isAmount(ForecastingItem item) {
        Id forecastingTypeId = item.ForecastingTypeId;
        ForecastingType t = ForecastingTypeUtil.typesMap.get(forecastingTypeId);
        return t.IsAmount;
    }
    
    private String forecastTypeString(ForecastingItem item) {
        Id forecastingTypeId = item.ForecastingTypeId;
        ForecastingType t = ForecastingTypeUtil.typesMap.get(forecastingTypeId);
        return t.MasterLabel;
    }
    
    public List<ForecastCategoryAttainment> getAttainments() {
        // Fetch the list of Forecast categories, starting with the end
    	List<String> forecastCategoryList = initForecastCategories();
        // Now fetch the ForecastingTypes
        List<ForecastingType> forecastingTypes = ForecastingTypeUtil.getActiveForecastingTypes();
        // Finally, fetch the quotas
        Map<Id,ForecastingQuota> forecastingQuotas = getForecastingQuotas();

        // Make an ordered set of Attainment records with this information. 
        // If there's no associated quota, skip it.
        List<ForecastCategoryAttainment> ret = new List<ForecastCategoryAttainment>();
         
   
   		Integer i = 1;
//        for (ForecastingType t : forecastingTypes) {
//            ForecastingQuota q = forecastingQuotas.get(t.Id);
//            if (q == null)
//                continue;                
                
            ForecastCategoryAttainment a = new ForecastCategoryAttainment();
            a.forecastTypeStr = 'Opportunity Quantity';
//            a.quota = t.IsAmount ? q.QuotaAmount : q.QuotaQuantity;
            a.closedAmount = 5000;
            a.commitAmount = 2000.25;
            a.bestcaseAmount = 8000;
            a.quota = 7000;
            ret.add(a);
        
        	a = new ForecastCategoryAttainment();
            a.forecastTypeStr = 'Opportunity Revenue';
//            a.quota = t.IsAmount ? q.QuotaAmount : q.QuotaQuantity;
            a.closedAmount = 10000;
            a.commitAmount = 4000.50;
            a.bestcaseAmount = 8000;
            a.quota = 7000;
            a.unitsPrefix = '$';
            ret.add(a);
        
        /*
        
        // Now fetch all the ForecastingItems. The ones that match by 
        // forecasting type and category will show up in the attainment.
        for (ForecastingItem item : getForecastingItems()) {
            for (Integer i = 0; i < ret.size(); i++) {
                ForecastCategoryAttainment a = ret.get(i);
                if (forecastTypeString(item).equals(c.forecastTypeStr) &&
                    item.ForecastCategoryName.equals(c.category)) {
					
                    c.forecastingItemId = item.Id;
                    c.relatedOpptys = getOppsInForecastingItem(item.Id);
                    c.amount = isAmount(item) ? item.ForecastAmount : item.ForecastQuantity;
            		if (c.amount == null)
                		c.amount = 0;
                        
                    if (i > 0) {
                		if (c.forecastTypeStr.equals(ret.get(i-1).forecastTypeStr))
                			c.category += ' + ' + ret.get(i-1).category;
                			c.amount += ret.get(i-1).amount;
            		}    
                }
            }
        }
        */
        
        return ret;
    }
    
    private List<Opportunity> getOppsInForecastingItem(Id forecastingItemId) {
        List<Opportunity> ret = [SELECT Id, Name, Amount, Account.Name FROM Opportunity WHERE Id IN 
                                 (select OpportunityId from ForecastingFact WHERE ForecastingItemId=:forecastingItemId)];
		System.debug(loggingLevel.INFO, 'Opps for forecastingItemId=' + forecastingItemId + ':\n' + ret);
        return ret;
    }
    
    
    private Map<Id, ForecastingQuota> getForecastingQuotas() {
        List<ForecastingQuota> quotas = [SELECT ForecastingTypeId, QuotaAmount, QuotaQuantity, 
                                         IsAmount, IsQuantity FROM ForecastingQuota
                                         WHERE QuotaOwnerId=:userId AND PeriodId=:periodId];
        
        Map<Id,ForecastingQuota> ret = new Map<Id,ForecastingQuota>();
        for (ForecastingQuota q : quotas) {
            ret.put(q.ForecastingTypeId, q);
        }
        return ret;
    }
        
    private List<ForecastingItem> getForecastingItems() {
        // TODO: Handle unadjusted value, owner-only, product family, monthly/quarterly
        
        List<ForecastingItem> items = [SELECT ForecastCategoryName, ForecastingTypeId, IsAmount, IsQuantity, 
                                       ForecastAmount, ForecastQuantity, HasAdjustment
                                       FROM ForecastingItem where OwnerId=:userId AND PeriodId=:periodId ORDER BY ForecastingTypeId];

       	return items;
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
        for (Integer i = 1; i<=3 && i<picklist.size(); i++) {
            Schema.PicklistEntry p = picklist.get(picklist.size()-i);
            if (p.isActive())
                ret.add(p.getLabel());            
        }
        
        return ret;
    }
    
}