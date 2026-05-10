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

    private func kpiSection(_ kpis: Entity) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            KPICard(
                title: "Revenue (YTD)",
                value: kpis.str("total_revenue_ytd_formatted"),
                icon: "arrow.up.right",
                valueColor: kpis.num("total_revenue_ytd") > 0 ? .green : .primary
            )
            KPICard(
                title: "Outstanding",
                value: kpis.str("outstanding_amount_formatted"),
                icon: "wallet.bifold",
                valueColor: kpis.num("outstanding_amount") > 0 ? .yellow : .primary
            )
            KPICard(
                title: "Overdue",
                value: kpis.str("overdue_amount_formatted"),
                icon: "exclamationmark.triangle",
                valueColor: kpis.num("overdue_amount") > 0 ? .red : .primary
            )
            KPICard(
                title: "Eff. Hourly Rate",
                value: kpis.str("effective_hourly_rate_formatted"),
                icon: "gauge.with.needle",
                valueColor: .blue
            )
            KPICard(
                title: "Utilization",
                value: kpis.str("utilization_rate_formatted"),
                icon: "chart.pie",
                valueColor: (kpis.optNum("utilization_rate") ?? 0) >= 0.7 ? .blue : .yellow
            )
            KPICard(
                title: "Active Projects",
                value: "\(kpis.int("active_projects"))",
                icon: "folder",
                valueColor: .primary
            )
            KPICard(
                title: "Active Contracts",
                value: "\(kpis.int("active_contracts"))",
                icon: "signature",
                valueColor: .primary
            )
            KPICard(
                title: "Unpaid Invoices",
                value: "\(kpis.int("unpaid_invoices"))",
                icon: "doc.text",
                valueColor: kpis.int("unpaid_invoices") > 0 ? .yellow : .primary
            )
        }
    }

    private func taxSection(_ kpis: Entity) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
            KPICard(
                title: "VAT Reserve",
                value: kpis.str("vat_reserve_formatted"),
                icon: "building.columns",
                valueColor: kpis.num("vat_reserve") > 0 ? .yellow : .primary
            )
            KPICard(
                title: "Est. Income Tax",
                value: kpis.str("income_tax_reserve_formatted"),
                icon: "function",
                valueColor: kpis.num("income_tax_reserve") > 0 ? .yellow : .primary
            )
            KPICard(
                title: "Spendable Income",
                value: kpis.str("spendable_income_formatted"),
                icon: "banknote",
                valueColor: kpis.num("spendable_income") > 0 ? .green : .red
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
                    AxisMarks { _ in
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
    let budget: Entity

    private var barColor: Color {
        let progress = budget.num("progress")
        if progress >= 1.0 { return .red }
        if progress >= 0.8 { return .yellow }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(budget.str("project"))
                    .font(.body)
                Spacer()
                Text("\(Int(budget.num("hours_tracked"))) / \(Int(budget.num("hours_budget"))) h (\(Int(budget.num("progress") * 100))%)")
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
                        .frame(width: geo.size.width * min(budget.num("progress"), 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

struct FinancialGoalRow: View {
    let goal: Entity

    private var barColor: Color {
        goal.bool("is_reached") ? .green : .blue
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(goal.title)
                    .font(.body)
                Spacer()
                if goal.bool("is_reached") {
                    Text("Reached!")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                } else {
                    Text("\(goal.str("ytd_revenue_formatted")) / \(goal.str("target_amount_formatted"))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("Target: \(goal.str("target_amount_formatted")) by \(goal.str("target_date_formatted"))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 6)
                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * min(goal.num("progress"), 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
