import Foundation
import PythonKit

struct DashboardData {
    var kpis: Entity?
    var revenueData: [MonthlyDataPoint]
    var spendableData: [MonthlyDataPoint]
    var projectBudgets: [Entity]
    var financialGoals: [Entity]
}

@Observable
final class DashboardViewModel {
    var kpis: Entity?
    var revenueData: [MonthlyDataPoint] = []
    var spendableData: [MonthlyDataPoint] = []
    var projectBudgets: [Entity] = []
    var financialGoals: [Entity] = []
    var isLoading = false
    var errorMessage: String?

    func loadAll() {
        isLoading = true
        errorMessage = nil

        PythonBridge.shared.run({
            let db = PythonBridge.shared.dashboard!

            // KPIs (NamedTuple, not SQLModel — use _asdict())
            let kpiResult = db.get_kpis()
            var kpis: Entity? = nil
            if PythonBridge.isOk(kpiResult) {
                let obj = kpiResult.data
                var dict = PythonBridge.toSwiftDict(obj._asdict())
                let tc = dict["tax_currency"] as? String ?? "EUR"
                dict["total_revenue_ytd_formatted"] = PythonBridge.fmtCurrencyStr(obj.total_revenue_ytd, tc)
                dict["outstanding_amount_formatted"] = PythonBridge.fmtCurrencyStr(obj.outstanding_amount, tc)
                dict["overdue_amount_formatted"] = PythonBridge.fmtCurrencyStr(obj.overdue_amount, tc)
                dict["vat_reserve_formatted"] = PythonBridge.fmtCurrencyStr(obj.vat_reserve, tc)
                dict["income_tax_reserve_formatted"] = PythonBridge.fmtCurrencyStr(obj.income_tax_reserve, tc)
                dict["spendable_income_formatted"] = PythonBridge.fmtCurrencyStr(obj.spendable_income, tc)

                let ehr = obj.effective_hourly_rate
                if ehr != Python.None {
                    dict["effective_hourly_rate_formatted"] = PythonBridge.fmtCurrencyStr(ehr, tc)
                } else {
                    dict["effective_hourly_rate_formatted"] = "—"
                }

                let ur = obj.utilization_rate
                if ur != Python.None {
                    if let d = Double(ur) {
                        dict["utilization_rate_formatted"] = String(format: "%.0f%%", d * 100)
                    }
                } else {
                    dict["utilization_rate_formatted"] = "—"
                }

                kpis = Entity(data: dict)
            }

            // Monthly chart data
            let chartResult = db.get_monthly_chart_data(12)
            var rev: [MonthlyDataPoint] = []
            var sp: [MonthlyDataPoint] = []
            if PythonBridge.isOk(chartResult) {
                let data = chartResult.data
                for item in data["revenue"] {
                    let month = String(item["month"]) ?? ""
                    rev.append(MonthlyDataPoint(
                        month: month,
                        label: Self.shortLabel(month),
                        value: Double(Python.float(item["revenue"])) ?? 0
                    ))
                }
                for item in data["spendable"] {
                    let month = String(item["month"]) ?? ""
                    sp.append(MonthlyDataPoint(
                        month: month,
                        label: Self.shortLabel(month),
                        value: Double(Python.float(item["spendable"])) ?? 0
                    ))
                }
            }

            // Project budgets
            let budgetResult = db.get_project_budgets()
            var budgets: [Entity] = []
            if PythonBridge.isOk(budgetResult) {
                budgets = PythonBridge.dictListToEntities(budgetResult.data)
            }

            // Financial goals
            let goalsResult = db.get_financial_goals()
            var goals: [Entity] = []
            if PythonBridge.isOk(goalsResult) {
                for item in goalsResult.data {
                    let g = item["goal"]
                    let tc = String(item["currency"]) ?? "EUR"
                    let dict: [String: Any] = [
                        "id": Int(g.id) ?? 0,
                        "title": String(g.title) ?? "",
                        "target_amount": Double(Python.float(g.target_amount)) ?? 0,
                        "target_amount_formatted": PythonBridge.fmtCurrencyStr(g.target_amount, tc),
                        "target_date": String(g.target_date.isoformat()) ?? "",
                        "target_date_formatted": String(g.target_date.strftime("%b %Y")) ?? "",
                        "is_reached": Bool(g.is_reached) ?? false,
                        "progress": Double(item["progress"]) ?? 0,
                        "ytd_revenue_formatted": PythonBridge.fmtCurrencyStr(item["ytd_revenue"], tc),
                    ]
                    goals.append(Entity(data: dict))
                }
            }

            return DashboardData(
                kpis: kpis,
                revenueData: rev,
                spendableData: sp,
                projectBudgets: budgets,
                financialGoals: goals
            )
        }, completion: { [self] (data: DashboardData) in
            self.kpis = data.kpis
            self.revenueData = data.revenueData
            self.spendableData = data.spendableData
            self.projectBudgets = data.projectBudgets
            self.financialGoals = data.financialGoals
            self.isLoading = false
        })
    }

    private static func shortLabel(_ month: String) -> String {
        let parts = month.split(separator: "-")
        guard parts.count == 2 else { return month }
        return "\(parts[1])/\(parts[0].suffix(2))"
    }
}
