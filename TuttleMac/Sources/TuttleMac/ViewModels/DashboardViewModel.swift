import Foundation
import PythonKit

/// Holds all dashboard data as pure Swift types (no PythonObject references).
struct DashboardData {
    var kpis: KPISummary?
    var revenueData: [MonthlyDataPoint]
    var spendableData: [MonthlyDataPoint]
    var projectBudgets: [ProjectBudget]
    var financialGoals: [FinancialGoalModel]
}

@Observable
final class DashboardViewModel {
    var kpis: KPISummary?
    var revenueData: [MonthlyDataPoint] = []
    var spendableData: [MonthlyDataPoint] = []
    var projectBudgets: [ProjectBudget] = []
    var financialGoals: [FinancialGoalModel] = []
    var isLoading = false
    var errorMessage: String?

    func loadAll() {
        isLoading = true
        errorMessage = nil

        PythonBridge.shared.run({ bridge -> DashboardData in
            // All PythonObject access happens here on the Python thread.
            // Convert everything to Swift types before returning.
            let kpiResult = bridge.get_dashboard_kpis()
            let chartResult = bridge.get_monthly_chart_data(12)
            let budgetResult = bridge.get_project_budgets()
            let goalsResult = bridge.get_financial_goals()

            let kpis: KPISummary? = PythonBridge.bool(kpiResult, key: "ok")
                ? KPISummary.from(kpiResult) : nil

            var rev: [MonthlyDataPoint] = []
            var sp: [MonthlyDataPoint] = []
            if PythonBridge.bool(chartResult, key: "ok") {
                for item in chartResult["revenue"] {
                    let month = PythonBridge.string(item, key: "month")
                    rev.append(MonthlyDataPoint(
                        month: month,
                        label: Self.shortLabel(month),
                        value: PythonBridge.double(item, key: "revenue")
                    ))
                }
                for item in chartResult["spendable"] {
                    let month = PythonBridge.string(item, key: "month")
                    sp.append(MonthlyDataPoint(
                        month: month,
                        label: Self.shortLabel(month),
                        value: PythonBridge.double(item, key: "spendable")
                    ))
                }
            }

            var budgets: [ProjectBudget] = []
            if PythonBridge.bool(budgetResult, key: "ok") {
                for item in budgetResult["budgets"] {
                    budgets.append(ProjectBudget.from(item))
                }
            }

            var goals: [FinancialGoalModel] = []
            if PythonBridge.bool(goalsResult, key: "ok") {
                for item in goalsResult["goals"] {
                    goals.append(FinancialGoalModel.from(item))
                }
            }

            return DashboardData(
                kpis: kpis,
                revenueData: rev,
                spendableData: sp,
                projectBudgets: budgets,
                financialGoals: goals
            )
        }, completion: { [self] data in
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
        let m = parts[1]
        let y = parts[0].suffix(2)
        return "\(m)/\(y)"
    }
}
