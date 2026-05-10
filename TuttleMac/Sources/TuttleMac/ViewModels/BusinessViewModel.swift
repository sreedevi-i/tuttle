import Foundation
import PythonKit

@Observable
final class BusinessViewModel {
    var clients: [Entity] = []
    var contacts: [Entity] = []
    var contracts: [Entity] = []
    var projects: [Entity] = []

    var isLoading = false
    var isSaving = false
    var errorMessage: String?

    func loadAll() {
        isLoading = true
        errorMessage = nil

        PythonBridge.shared.run({
            let py = PythonBridge.shared

            let cr = py.contacts.get_all()
            let clr = py.clients.get_all()
            let ctr = py.contracts.get_all()
            let pr = py.projects.get_all()

            let contacts: [Entity] = PythonBridge.isOk(cr)
                ? PythonBridge.toEntityList(cr.data) { obj, dict in
                    let addr = obj.address
                    if addr != Python.None {
                        dict["city"] = String(addr.city) ?? ""
                        dict["country"] = String(addr.country) ?? ""
                    }
                    dict["name"] = String(obj.name) ?? ""
                }
                : []

            let clients: [Entity] = PythonBridge.isOk(clr)
                ? PythonBridge.toEntityList(clr.data) { obj, dict in
                    let contact = obj.invoicing_contact
                    if contact != Python.None {
                        dict["contact_name"] = String(contact.name) ?? ""
                        dict["contact_email"] = String(contact.email) ?? ""
                        dict["contact_company"] = String(contact.company) ?? ""
                        let addr = contact.address
                        if addr != Python.None {
                            dict["city"] = String(addr.city) ?? ""
                            dict["country"] = String(addr.country) ?? ""
                        }
                    }
                    dict["num_contracts"] = Int(Python.len(obj.contracts)) ?? 0
                }
                : []

            let contracts: [Entity] = PythonBridge.isOk(ctr)
                ? PythonBridge.toEntityList(ctr.data) { obj, dict in
                    dict["status"] = String(obj.get_status()) ?? "All"
                    if obj.client != Python.None {
                        dict["client_name"] = String(obj.client.name) ?? ""
                    }
                    let cur = dict["currency"] as? String ?? "EUR"
                    dict["rate_formatted"] = PythonBridge.fmtCurrencyStr(obj.rate, cur)
                    dict["unit_value"] = obj.unit != Python.None ? (String(obj.unit.value) ?? "hour") : "hour"
                    dict["billing_cycle_value"] = obj.billing_cycle != Python.None ? (String(obj.billing_cycle.value) ?? "") : ""
                    dict["num_projects"] = Int(Python.len(obj.projects)) ?? 0
                    dict["num_invoices"] = Int(Python.len(obj.invoices)) ?? 0
                }
                : []

            let projects: [Entity] = PythonBridge.isOk(pr)
                ? PythonBridge.toEntityList(pr.data) { obj, dict in
                    dict["status"] = String(obj.get_status()) ?? "All"
                    let contract = obj.contract
                    if contract != Python.None {
                        dict["contract_title"] = String(contract.title) ?? ""
                        if contract.client != Python.None {
                            dict["client_name"] = String(contract.client.name) ?? ""
                        }
                    }
                    dict["num_invoices"] = Int(Python.len(obj.invoices)) ?? 0
                    dict["num_timesheets"] = Int(Python.len(obj.timesheets)) ?? 0
                }
                : []

            return (contacts, clients, contracts, projects)
        }, completion: { [self] (c, cl, ct, p) in
            self.contacts = c
            self.clients = cl
            self.contracts = ct
            self.projects = p
            self.isLoading = false
        })
    }

    func deleteClient(_ id: Int) {
        PythonBridge.shared.run({
            PythonBridge.isOk(PythonBridge.shared.clients.delete(id))
        }, completion: { [self] ok in
            if ok { self.clients.removeAll { $0.id == id } }
        })
    }

    func deleteContact(_ id: Int) {
        PythonBridge.shared.run({
            PythonBridge.isOk(PythonBridge.shared.contacts.delete(id))
        }, completion: { [self] ok in
            if ok { self.contacts.removeAll { $0.id == id } }
        })
    }

    func deleteContract(_ id: Int) {
        PythonBridge.shared.run({
            PythonBridge.isOk(PythonBridge.shared.contracts.delete(id))
        }, completion: { [self] ok in
            if ok { self.contracts.removeAll { $0.id == id } }
        })
    }

    func deleteProject(_ id: Int) {
        PythonBridge.shared.run({
            PythonBridge.isOk(PythonBridge.shared.projects.delete(id))
        }, completion: { [self] ok in
            if ok { self.projects.removeAll { $0.id == id } }
        })
    }

    func toggleContractCompleted(_ id: Int) {
        PythonBridge.shared.run({
            let intent = PythonBridge.shared.contracts!
            let result = intent.get_by_id(id)
            guard PythonBridge.isOk(result) else { return false }
            return PythonBridge.isOk(intent.toggle_complete_status(result.data))
        }, completion: { [self] (ok: Bool) in
            if ok { self.loadAll() }
        })
    }

    func toggleProjectCompleted(_ id: Int) {
        PythonBridge.shared.run({
            let intent = PythonBridge.shared.projects!
            let result = intent.get_by_id(id)
            guard PythonBridge.isOk(result) else { return false }
            return PythonBridge.isOk(intent.toggle_project_completed_status(result.data))
        }, completion: { [self] (ok: Bool) in
            if ok { self.loadAll() }
        })
    }

    // MARK: - Save (create or update)

    func saveContact(
        id: Int?, firstName: String, lastName: String,
        company: String, email: String,
        street: String, city: String, postalCode: String, country: String
    ) {
        isSaving = true
        PythonBridge.shared.run({
            let intent = PythonBridge.shared.contacts!
            let model = Python.import("tuttle.model")

            let contact: PythonObject
            if let existingId = id {
                let r = intent.get_by_id(existingId)
                guard PythonBridge.isOk(r) else { return "Failed to load contact" }
                contact = r.data
            } else {
                contact = model.Contact()
            }

            contact.first_name = PythonObject(firstName)
            contact.last_name = PythonObject(lastName)
            contact.company = PythonObject(company)
            contact.email = PythonObject(email.isEmpty ? Python.None : PythonObject(email))

            if contact.address == Python.None {
                contact.address = model.Address()
            }
            contact.address.street = PythonObject(street)
            contact.address.city = PythonObject(city)
            contact.address.postal_code = PythonObject(postalCode)
            contact.address.country = PythonObject(country)

            let result = intent.save_contact(contact)
            if PythonBridge.isOk(result) { return nil as String? }
            return String(result.error_msg) ?? "Save failed"
        }, completion: { [self] (err: String?) in
            self.isSaving = false
            self.errorMessage = err
            self.loadAll()
        })
    }

    func saveClient(id: Int?, name: String, contactId: Int?) {
        isSaving = true
        PythonBridge.shared.run({
            let intent = PythonBridge.shared.clients!
            let model = Python.import("tuttle.model")

            let client: PythonObject
            if let existingId = id {
                let r = intent.get_by_id(existingId)
                guard PythonBridge.isOk(r) else { return "Failed to load client" }
                client = r.data
            } else {
                client = model.Client()
            }

            client.name = PythonObject(name)

            if let cId = contactId {
                let cr = PythonBridge.shared.contacts!.get_by_id(cId)
                if PythonBridge.isOk(cr) {
                    client.invoicing_contact = cr.data
                    client.invoicing_contact_id = PythonObject(cId)
                }
            }

            let result = intent.save_client(client)
            if PythonBridge.isOk(result) { return nil as String? }
            return String(result.error_msg) ?? "Save failed"
        }, completion: { [self] (err: String?) in
            self.isSaving = false
            self.errorMessage = err
            self.loadAll()
        })
    }

    func saveContract(
        id: Int?, title: String, clientId: Int?,
        rate: String, currency: String, unit: String, billingCycle: String,
        vatRate: String, startDate: Date, endDate: Date?, volume: String
    ) {
        isSaving = true
        PythonBridge.shared.run({
            let intent = PythonBridge.shared.contracts!
            let model = Python.import("tuttle.model")
            let decimal = Python.import("decimal")
            let timeModule = Python.import("tuttle.time")
            let dt = Python.import("datetime")

            let contract: PythonObject
            if let existingId = id {
                let r = intent.get_by_id(existingId)
                guard PythonBridge.isOk(r) else { return "Failed to load contract" }
                contract = r.data
            } else {
                contract = model.Contract()
            }

            contract.title = PythonObject(title)
            contract.rate = decimal.Decimal(rate.isEmpty ? "0" : rate)
            contract.currency = PythonObject(currency.isEmpty ? "EUR" : currency)
            contract.unit = timeModule.TimeUnit(unit.isEmpty ? "hour" : unit)
            contract.billing_cycle = timeModule.Cycle(billingCycle.isEmpty ? "monthly" : billingCycle)
            contract.VAT_rate = decimal.Decimal(vatRate.isEmpty ? "0.19" : vatRate)

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            contract.start_date = dt.date.fromisoformat(fmt.string(from: startDate))
            if let end = endDate {
                contract.end_date = dt.date.fromisoformat(fmt.string(from: end))
            }
            contract.signature_date = contract.start_date

            if !volume.isEmpty, let v = Int(volume) {
                contract.volume = PythonObject(v)
            }

            if let cId = clientId {
                let cr = PythonBridge.shared.clients!.get_by_id(cId)
                if PythonBridge.isOk(cr) {
                    contract.client = cr.data
                    contract.client_id = PythonObject(cId)
                }
            }

            let result = intent.save_contract(contract)
            if PythonBridge.isOk(result) { return nil as String? }
            return String(result.error_msg) ?? "Save failed"
        }, completion: { [self] (err: String?) in
            self.isSaving = false
            self.errorMessage = err
            self.loadAll()
        })
    }

    func saveProject(
        id: Int?, title: String, tag: String, description: String,
        contractId: Int?, startDate: Date, endDate: Date?
    ) {
        isSaving = true
        PythonBridge.shared.run({
            let intent = PythonBridge.shared.projects!
            let model = Python.import("tuttle.model")
            let dt = Python.import("datetime")

            let project: PythonObject
            if let existingId = id {
                let r = intent.get_by_id(existingId)
                guard PythonBridge.isOk(r) else { return "Failed to load project" }
                project = r.data
            } else {
                project = model.Project()
            }

            project.title = PythonObject(title)
            project.tag = PythonObject(tag)
            project[dynamicMember: "description"] = PythonObject(description)

            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            project.start_date = dt.date.fromisoformat(fmt.string(from: startDate))
            if let end = endDate {
                project.end_date = dt.date.fromisoformat(fmt.string(from: end))
            } else {
                project.end_date = Python.None
            }

            if let cId = contractId {
                let cr = PythonBridge.shared.contracts!.get_by_id(cId)
                if PythonBridge.isOk(cr) {
                    project.contract = cr.data
                    project.contract_id = PythonObject(cId)
                }
            }

            let result = intent.save_project(project)
            if PythonBridge.isOk(result) { return nil as String? }
            return String(result.error_msg) ?? "Save failed"
        }, completion: { [self] (err: String?) in
            self.isSaving = false
            self.errorMessage = err
            self.loadAll()
        })
    }
}
