import Foundation
import PythonKit

@Observable
final class BusinessViewModel {
    var clients: [ClientModel] = []
    var contacts: [ContactModel] = []
    var contracts: [ContractModel] = []
    var projects: [ProjectModel] = []

    var isLoading = false
    var errorMessage: String?

    func loadAll() {
        isLoading = true
        errorMessage = nil

        PythonBridge.shared.run({ bridge -> BusinessData in
            let clientsResult = bridge.get_all_clients()
            let contactsResult = bridge.get_all_contacts()
            let contractsResult = bridge.get_all_contracts()
            let projectsResult = bridge.get_all_projects()

            var clients: [ClientModel] = []
            if PythonBridge.bool(clientsResult, key: "ok") {
                for item in clientsResult["clients"] {
                    clients.append(ClientModel.from(item))
                }
            }

            var contacts: [ContactModel] = []
            if PythonBridge.bool(contactsResult, key: "ok") {
                for item in contactsResult["contacts"] {
                    contacts.append(ContactModel.from(item))
                }
            }

            var contracts: [ContractModel] = []
            if PythonBridge.bool(contractsResult, key: "ok") {
                for item in contractsResult["contracts"] {
                    contracts.append(ContractModel.from(item))
                }
            }

            var projects: [ProjectModel] = []
            if PythonBridge.bool(projectsResult, key: "ok") {
                for item in projectsResult["projects"] {
                    projects.append(ProjectModel.from(item))
                }
            }

            return BusinessData(
                clients: clients,
                contacts: contacts,
                contracts: contracts,
                projects: projects
            )
        }, completion: { [self] data in
            self.clients = data.clients
            self.contacts = data.contacts
            self.contracts = data.contracts
            self.projects = data.projects
            self.isLoading = false
        })
    }

    func deleteClient(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.delete_client(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.clients.removeAll { $0.id == id } }
        })
    }

    func deleteContact(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.delete_contact(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.contacts.removeAll { $0.id == id } }
        })
    }

    func deleteContract(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.delete_contract(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.contracts.removeAll { $0.id == id } }
        })
    }

    func deleteProject(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.delete_project(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.projects.removeAll { $0.id == id } }
        })
    }

    func toggleContractCompleted(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.toggle_contract_completed(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.loadAll() }
        })
    }

    func toggleProjectCompleted(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.toggle_project_completed(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.loadAll() }
        })
    }
}

struct BusinessData {
    var clients: [ClientModel]
    var contacts: [ContactModel]
    var contracts: [ContractModel]
    var projects: [ProjectModel]
}
