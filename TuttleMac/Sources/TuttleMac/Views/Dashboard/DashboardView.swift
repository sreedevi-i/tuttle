import SwiftUI
import Charts

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.kpis == nil {
                ProgressView("Loading dashboard…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let kpis = viewModel.kpis {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        kpiSection(kpis)
                        taxSection(kpis)
                        chartSection
                        budgetSection
                        goalsSection
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView(
                    "No Data",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Could not load dashboard data.")
                )
            }
        }
        .navigationTitle("Dashboard")
        .onAppear { viewModel.loadAll() }
        .refreshable { viewModel.loadAll() }
    }

    // MARK: - KPI Cards

    private func kpiSection(_ kpis: KPISummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            KPICard(
                title: "Revenue (YTD)",
                value: kpis.totalRevenueYTDFormatted,
                icon: "arrow.up.right",
                valueColor: kpis.totalRevenueYTD > 0 ? .green : .primary
            )
            KPICard(
                title: "Outstanding",
                value: kpis.outstandingAmountFormatted,
                icon: "wallet.bifold",
                valueColor: kpis.outstandingAmount > 0 ? .yellow : .primary
            )
            KPICard(
                title: "Overdue",
                value: kpis.overdueAmountFormatted,
                icon: "exclamationmark.triangle",
                valueColor: kpis.overdueAmount > 0 ? .red : .primary
            )
            KPICard(
                title: "Eff. Hourly Rate",
                value: kpis.effectiveHourlyRateFormatted,
                icon: "gauge.with.needle",
                valueColor: .blue
            )
            KPICard(
                title: "Utilization",
                value: kpis.utilizationRateFormatted,
                icon: "chart.pie",
                valueColor: (kpis.utilizationRate ?? 0) >= 0.7 ? .blue : .yellow
            )
            KPICard(
                title: "Active Projects",
                value: "\(kpis.activeProjects)",
                icon: "folder",
                valueColor: .primary
            )
            KPICard(
                title: "Active Contracts",
                value: "\(kpis.activeContracts)",
                icon: "signature",
                valueColor: .primary
            )
            KPICard(
                title: "Unpaid Invoices",
                value: "\(kpis.unpaidInvoices)",
                icon: "doc.text",
                valueColor: kpis.unpaidInvoices > 0 ? .yellow : .primary
            )
        }
    }

    private func taxSection(_ kpis: KPISummary) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            KPICard(
                title: "VAT Reserve",
                value: kpis.vatReserveFormatted,
                icon: "building.columns",
                valueColor: kpis.vatReserve > 0 ? .yellow : .primary
            )
            KPICard(
                title: "Est. Income Tax",
                value: kpis.incomeTaxReserveFormatted,
                icon: "function",
                valueColor: kpis.incomeTaxReserve > 0 ? .yellow : .primary
            )
            KPICard(
                title: "Spendable Income",
                value: kpis.spendableIncomeFormatted,
                icon: "banknote",
                valueColor: kpis.spendableIncome > 0 ? .green : .red
            )
        }
    }

    // MARK: - Revenue Chart

    @ViewBuilder
    private var chartSection: some View {
        if !viewModel.revenueData.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Monthly Revenue vs Spendable Income (Est.)", systemImage: "chart.bar")
                        .font(.headline)
                    Spacer()
                    HStack(spacing: 12) {
                        legendChip("Revenue", color: .blue)
                        legendChip("Spendable", color: .green)
                    }
                }

                Chart {
                    ForEach(viewModel.revenueData) { point in
                        BarMark(
                            x: .value("Month", point.label),
                            y: .value("Revenue", point.value)
                        )
                        .foregroundStyle(.blue)
                        .position(by: .value("Type", "Revenue"))
                    }
                    ForEach(viewModel.spendableData) { point in
                        BarMark(
                            x: .value("Month", point.label),
                            y: .value("Spendable", max(point.value, 0))
                        )
                        .foregroundStyle(.green)
                        .position(by: .value("Type", "Spendable"))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(Self.shortCurrency(v))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: 260)
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func legendChip(_ label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.quaternary.opacity(0.5), in: Capsule())
    }

    private static func shortCurrency(_ value: Double) -> String {
        if value >= 1000 {
            return "\(String(format: "%.0f", value / 1000))K"
        }
        return String(format: "%.0f", value)
    }

    // MARK: - Project Budgets

    @ViewBuilder
    private var budgetSection: some View {
        if !viewModel.projectBudgets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Project Budgets", systemImage: "chart.bar.doc.horizontal")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(viewModel.projectBudgets) { budget in
                        ProjectBudgetRow(budget: budget)
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Financial Goals

    @ViewBuilder
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Financial Goals", systemImage: "flag")
                .font(.headline)

            if viewModel.financialGoals.isEmpty {
                Text("No goals yet.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.financialGoals) { goal in
                        FinancialGoalRow(goal: goal)
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

// MARK: - Subviews

struct KPICard: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(title.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .tracking(0.6)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct ProjectBudgetRow: View {
    let budget: ProjectBudget

    private var barColor: Color {
        if budget.progress >= 1.0 { return .red }
        if budget.progress >= 0.8 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(budget.project)
                    .font(.body)
                Spacer()
                Text("\(Int(budget.hoursTracked)) / \(Int(budget.hoursBudget)) h (\(Int(budget.progress * 100))%)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 6)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * min(budget.progress, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct FinancialGoalRow: View {
    let goal: FinancialGoalModel

    private var barColor: Color {
        goal.isReached ? .green : .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(goal.title)
                    .font(.body)
                Spacer()
                if goal.isReached {
                    Text("Reached!")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                } else {
                    Text("\(goal.ytdRevenueFormatted) / \(goal.targetAmountFormatted)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Target: \(goal.targetAmountFormatted) by \(goal.targetDateFormatted)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 6)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * min(goal.progress, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
