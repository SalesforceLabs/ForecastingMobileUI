public with sharing class QuotaAttainmentController {
    List<Period> periods = getCurrentPeriods();
    List<Id> periodIds = getPeriodIds(periods);
    Id userId = Id.valueOf(UserInfo.getUserId());
    Date today = Date.today();

    private List<ForecastingType> forecastingTypes = ForecastingTypeUtil.getActiveForecastingTypes();
    private List<ForecastingItem> forecastingItems = getForecastingItems();
    Map<PeriodFtypeKey,ForecastingQuota> forecastingQuotas = getForecastingQuotas();

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
        Map<String,Integer> forecastCategoryList = initForecastCategories();
        System.debug(forecastCategoryList);

        List<ForecastCategoryAttainment> attainments = new List<ForecastCategoryAttainment>();
        Map<PeriodFtypeKey, ForecastCategoryAttainment> attainsmentsByKey = new Map<PeriodFtypeKey, ForecastCategoryAttainment>();

        System.debug(periods);
        System.debug(forecastingTypes);
        System.debug(forecastingQuotas);
        System.debug(forecastingItems);
        // Make an ordered set of Attainment records: by period, then by forecasting type 
        for (Period period : periods) {
            for (ForecastingType t : forecastingTypes) {
                PeriodFtypeKey key = new PeriodFtypeKey(period.Id, t.Id);
                
                ForecastCategoryAttainment a = new ForecastCategoryAttainment();
                a.forecastTypeStr = t.MasterLabel;
                a.timeRemainingInPeriod = timeBetweenTwoDates(today, period.EndDate);
                a.unitsPrefix = t.IsAmount ? '$' : '';
                
                for (String catName : forecastCategoryList.keySet()) {
                    Integer catNumber = forecastCategoryList.get(catName);
                    if (catNumber == 0) {
		                a.closedCategoryStr = catName;                
                    } else if (catNumber == 1) {
                        a.commitCategoryStr = catName;
                    } else if (catNumber == 2) {
                        a.bestcaseCategoryStr = catName;
                    }
                }
                
                attainments.add(a);
                attainsmentsByKey.put(key, a);
                
                // If there's no associated quota, put in a blank
                ForecastingQuota q = forecastingQuotas.get(key);
                if (q != null) {
                    a.quota = q.IsAmount ? q.QuotaAmount : q.QuotaQuantity;
                }
            }
        }
        
        // Go through all the Forecasting Items. Match them to the right attainment
        for (ForecastingItem item : forecastingItems) {
            PeriodFtypeKey key = new PeriodFtypeKey(item.PeriodId, item.ForecastingTypeId);
            ForecastCategoryAttainment a = attainsmentsByKey.get(key);
            if (a == null)
                continue;
            
            Integer categoryPosition = forecastCategoryList.get(item.ForecastCategoryName);
            if (categoryPosition == null)
        		continue;
            
            Decimal amount = item.IsAmount ? item.ForecastAmount : item.ForecastQuantity;
            System.debug('Item=' + item + '\nCorresponding attainment=' + a);
            
            if (categoryPosition == 0) {
                a.closedAmount = amount;
                a.closedForecastingItemId = item.Id;
            } else if (categoryPosition == 1) {
                a.commitAmount = amount;
                a.commitForecastingItemId = item.Id;
            } else if (categoryPosition == 2) {
                a.bestcaseAmount = amount;
                a.bestcaseForecastingItemId = item.Id;
            } else {
                continue;
            }
        }
                
        // Remove any blank attainments
        List<ForecastCategoryAttainment> ret = new List<ForecastCategoryAttainment>();
        for (ForecastCategoryAttainment a : attainments) {
            if (a.sumPipeline() > 0 || a.quota > 0)
                ret.add(a);
        } 
        
        return ret;
    }
    
    private Map<PeriodFtypeKey, ForecastingQuota> getForecastingQuotas() {
        List<ForecastingQuota> quotas = [SELECT PeriodId, ForecastingTypeId, QuotaAmount, QuotaQuantity, 
                                         IsAmount, IsQuantity FROM ForecastingQuota
                                         WHERE QuotaOwnerId=:userId AND PeriodId IN :periodIds];
        
        Map<PeriodFtypeKey,ForecastingQuota> ret = new Map<PeriodFtypeKey,ForecastingQuota>();
        for (ForecastingQuota q : quotas) {
            ret.put(new PeriodFtypeKey(q.PeriodId, q.ForecastingTypeId), q);
        }
        return ret;
    }
        
    private List<ForecastingItem> getForecastingItems() {
        // TODO: Handle adjusted value, owner-only, product family
        
        List<ForecastingItem> items = [SELECT PeriodId, ForecastCategoryName, ForecastingTypeId, IsAmount, 
                                       ForecastAmount, ForecastQuantity, HasAdjustment
                                       FROM ForecastingItem where OwnerId=:userId AND 
                                       PeriodId IN :periodIds];

         return items;
    }
     
    private List<Period> getCurrentPeriods() {
        List<Period> periods = [SELECT Id, EndDate FROM Period Where Type IN ('Month', 'Quarter') AND 
                                EndDate >= TODAY AND StartDate <= TODAY ORDER BY StartDate];
        return periods;
    }
    
    private List<Id> getPeriodIds(List<Period> periods) {
        List<Id> ret = new List<Id>();
        for (Period p : periods) {
            ret.add(p.Id);
        }
        return ret;
    }
    
    private String timeBetweenTwoDates(Date first, Date second) {
        Integer numberDays = first.daysBetween(second);
        if (numberDays >= 21) {
            return (numberDays/7) + ' weeks left in this period';
        }
        else if (numberDays >= 2) {
            return numberDays + ' days left in this period';
        }
        else if (numberDays == 1) {
            return 'Period ends tomorrow!';
        }
        return 'Period ends today!';
    }
    
    
    
    private Map<String,Integer> initForecastCategories() {        
      Map<String,Integer> ret = new Map<String,Integer>();
        
      Schema.DescribeFieldResult f = Schema.sObjectType.ForecastingItem.fields.ForecastCategoryName;
      List<Schema.PicklistEntry> picklist = f.getPicklistValues();
      // Sort in reverse order
      Integer found = 0;
      for (Integer i = 1; found<3 && i<picklist.size(); i++) {
          Schema.PicklistEntry p = picklist.get(picklist.size()-i);
          if (p.isActive()) {
              ret.put(p.getLabel(),found++);
          }
      }
        
      return ret;
    }
    
    public class PeriodFtypeKey {
        String code;
        
        public PeriodFtypeKey(Id a, Id b) {
            code = String.valueOf(a) + String.valueOf(b);
        }
        
        public Boolean equals(Object obj) {
            if (obj instanceof PeriodFtypeKey) {
                PeriodFtypeKey p = (PeriodFtypeKey)obj;
                return (p.code.equals(this.code));
            }
            return false;
        }
        
        public Integer hashCode() {
            return (code.hashCode());
        }
    }
    
}