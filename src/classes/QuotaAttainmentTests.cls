@isTest
public class QuotaAttainmentTests{
    static testMethod void testBasic() {
        QuotaAttainmentController qc = new QuotaAttainmentController();
        qc.getAttainments();
    }
    
    static testMethod void testModel() {
        ForecastCategoryAttainment a = new ForecastCategoryAttainment();
        a.closedAmount = 5000;
        a.commitAmount = 6000;
        a.bestcaseAmount = 7000;
        a.quota = 4000;
        a.getBestcaseAmountStr();
        a.getClosedAmountStr();
        a.getCommitAmountStr();
        a.getQuotaAmountStr();
        a.getClosedPercent();
        a.getCommitPercent();
        a.getQuotaAttainmentPercent();
        a.getQuotaRemainingStr();
        a.getQuotaPercent();
    }
}