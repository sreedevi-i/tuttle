import Foundation
import PythonKit

@Observable
final class BusinessViewModel {
    var clients: [Entity] = []
    var contacts: [Entity] = []
    var contracts: [Entity] = []
    var projects: [Entity] = []

    var isLoading = false
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
}
