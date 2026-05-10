import SwiftUI

// MARK: - Contact Form

struct ContactFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: BusinessViewModel
    let editing: Entity?

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var company = ""
    @State private var email = ""
    @State private var street = ""
    @State private var city = ""
    @State private var postalCode = ""
    @State private var country = ""

    init(viewModel: BusinessViewModel, editing: Entity? = nil) {
        self.viewModel = viewModel
        self.editing = editing
        if let e = editing {
            _firstName = State(initialValue: e.str("first_name"))
            _lastName = State(initialValue: e.str("last_name"))
            _company = State(initialValue: e.str("company"))
            _email = State(initialValue: e.str("email"))
            _city = State(initialValue: e.str("city"))
            _country = State(initialValue: e.str("country"))
        }
    }

    private var isValid: Bool {
        !firstName.isEmpty && !lastName.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            FormHeader(title: editing == nil ? "New Contact" : "Edit Contact", icon: "person.badge.plus")

            Form {
                Section("Name") {
                    HStack(spacing: 10) {
                        TextField("First name", text: $firstName)
                        TextField("Last name", text: $lastName)
                    }
                    TextField("Company", text: $company)
                }

                Section("Contact") {
                    TextField("Email", text: $email)
                }

                Section("Address") {
                    TextField("Street", text: $street)
                    HStack(spacing: 10) {
                        TextField("Postal code", text: $postalCode)
                            .frame(width: 100)
                        TextField("City", text: $city)
                    }
                    TextField("Country", text: $country)
                }
            }
            .formStyle(.grouped)

            FormActions(isValid: isValid, onCancel: { dismiss() }) {
                viewModel.saveContact(
                    id: editing?.id,
                    firstName: firstName, lastName: lastName,
                    company: company, email: email,
                    street: street, city: city,
                    postalCode: postalCode, country: country
                )
                dismiss()
            }
        }
        .frame(width: 420, height: 400)
    }
}

// MARK: - Client Form

struct ClientFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: BusinessViewModel
    let editing: Entity?

    @State private var name = ""
    @State private var selectedContactId: Int?

    init(viewModel: BusinessViewModel, editing: Entity? = nil) {
        self.viewModel = viewModel
        self.editing = editing
        if let e = editing {
            _name = State(initialValue: e.str("name"))
        }
    }

    private var isValid: Bool { !name.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            FormHeader(title: editing == nil ? "New Client" : "Edit Client", icon: "building.2.fill")

            Form {
                Section("Client") {
                    TextField("Client name", text: $name)
                }

                Section("Invoicing Contact") {
                    Picker("Contact", selection: $selectedContactId) {
                        Text("None").tag(nil as Int?)
                        ForEach(viewModel.contacts) { contact in
                            Text(contact.fullName.isEmpty ? contact.str("company") : contact.fullName)
                                .tag(contact.id as Int?)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            FormActions(isValid: isValid, onCancel: { dismiss() }) {
                viewModel.saveClient(
                    id: editing?.id,
                    name: name,
                    contactId: selectedContactId
                )
                dismiss()
            }
        }
        .frame(width: 380, height: 280)
    }
}

// MARK: - Contract Form

struct ContractFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: BusinessViewModel
    let editing: Entity?

    @State private var title = ""
    @State private var selectedClientId: Int?
    @State private var rate = ""
    @State private var currency = "EUR"
    @State private var unit = "hour"
    @State private var billingCycle = "monthly"
    @State private var vatRate = "0.19"
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var hasEndDate = false
    @State private var volume = ""

    private let currencies = ["EUR", "USD", "GBP", "CHF"]
    private let units = ["hour", "day"]
    private let cycles = ["monthly", "quarterly", "yearly"]

    init(viewModel: BusinessViewModel, editing: Entity? = nil) {
        self.viewModel = viewModel
        self.editing = editing
        if let e = editing {
            _title = State(initialValue: e.str("title"))
            _rate = State(initialValue: e.num("rate") > 0 ? String(format: "%.2f", e.num("rate")) : "")
            _currency = State(initialValue: e.str("currency").isEmpty ? "EUR" : e.str("currency"))
            _unit = State(initialValue: e.str("unit_value").isEmpty ? "hour" : e.str("unit_value"))
            _billingCycle = State(initialValue: e.str("billing_cycle_value").isEmpty ? "monthly" : e.str("billing_cycle_value"))
            let vr = e.num("VAT_rate")
            _vatRate = State(initialValue: vr > 0 ? String(format: "%.2f", vr) : "0.19")
            if let sd = Self.parseDate(e.str("start_date")) { _startDate = State(initialValue: sd) }
            if let ed = Self.parseDate(e.optStr("end_date") ?? "") {
                _endDate = State(initialValue: ed)
                _hasEndDate = State(initialValue: true)
            }
            if let v = e.optInt("volume") { _volume = State(initialValue: String(v)) }
        }
    }

    private var isValid: Bool { !title.isEmpty && !rate.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            FormHeader(title: editing == nil ? "New Contract" : "Edit Contract", icon: "signature")

            Form {
                Section("Basics") {
                    TextField("Title", text: $title)
                    Picker("Client", selection: $selectedClientId) {
                        Text("None").tag(nil as Int?)
                        ForEach(viewModel.clients) { client in
                            Text(client.name).tag(client.id as Int?)
                        }
                    }
                }

                Section("Terms") {
                    HStack(spacing: 10) {
                        TextField("Rate", text: $rate)
                            .frame(width: 100)
                        Picker("", selection: $currency) {
                            ForEach(currencies, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                        Text("/")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $unit) {
                            ForEach(units, id: \.self) { Text($0) }
                        }
                        .labelsHidden()
                        .frame(width: 80)
                    }
                    HStack(spacing: 10) {
                        Picker("Billing", selection: $billingCycle) {
                            ForEach(cycles, id: \.self) { Text($0.capitalized) }
                        }
                        TextField("Volume", text: $volume)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("VAT")
                        TextField("", text: $vatRate)
                            .frame(width: 60)
                        Text("(\(String(format: "%.0f%%", (Double(vatRate) ?? 0) * 100)))")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Period") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                }
            }
            .formStyle(.grouped)

            FormActions(isValid: isValid, onCancel: { dismiss() }) {
                viewModel.saveContract(
                    id: editing?.id,
                    title: title, clientId: selectedClientId,
                    rate: rate, currency: currency, unit: unit,
                    billingCycle: billingCycle, vatRate: vatRate,
                    startDate: startDate, endDate: hasEndDate ? endDate : nil,
                    volume: volume
                )
                dismiss()
            }
        }
        .frame(width: 480, height: 520)
    }

    private static func parseDate(_ str: String) -> Date? {
        guard !str.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: str)
    }
}

// MARK: - Project Form

struct ProjectFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    let viewModel: BusinessViewModel
    let editing: Entity?

    @State private var title = ""
    @State private var tag = ""
    @State private var desc = ""
    @State private var selectedContractId: Int?
    @State private var startDate = Date()
    @State private var endDate = Date()
    @State private var hasEndDate = false

    init(viewModel: BusinessViewModel, editing: Entity? = nil) {
        self.viewModel = viewModel
        self.editing = editing
        if let e = editing {
            _title = State(initialValue: e.str("title"))
            _tag = State(initialValue: e.str("tag"))
            _desc = State(initialValue: e.str("description"))
            if let sd = Self.parseDate(e.str("start_date")) { _startDate = State(initialValue: sd) }
            if let ed = Self.parseDate(e.optStr("end_date") ?? "") {
                _endDate = State(initialValue: ed)
                _hasEndDate = State(initialValue: true)
            }
        }
    }

    private var isValid: Bool { !title.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            FormHeader(title: editing == nil ? "New Project" : "Edit Project", icon: "folder.badge.plus")

            Form {
                Section("Project") {
                    TextField("Title", text: $title)
                    TextField("Tag (short identifier)", text: $tag)
                }

                Section("Contract") {
                    Picker("Contract", selection: $selectedContractId) {
                        Text("None").tag(nil as Int?)
                        ForEach(viewModel.contracts) { contract in
                            Text(contract.title).tag(contract.id as Int?)
                        }
                    }
                }

                Section("Period") {
                    DatePicker("Start", selection: $startDate, displayedComponents: .date)
                    Toggle("Has end date", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("End", selection: $endDate, displayedComponents: .date)
                    }
                }

                Section("Description") {
                    TextEditor(text: $desc)
                        .frame(height: 60)
                }
            }
            .formStyle(.grouped)

            FormActions(isValid: isValid, onCancel: { dismiss() }) {
                viewModel.saveProject(
                    id: editing?.id,
                    title: title, tag: tag, description: desc,
                    contractId: selectedContractId,
                    startDate: startDate, endDate: hasEndDate ? endDate : nil
                )
                dismiss()
            }
        }
        .frame(width: 420, height: 460)
    }

    private static func parseDate(_ str: String) -> Date? {
        guard !str.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: str)
    }
}

// MARK: - Shared Form Components

struct FormHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }
}

struct FormActions: View {
    let isValid: Bool
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel, action: onCancel)
                .keyboardShortcut(.escape, modifiers: [])
            Button("Save", action: onSave)
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}
