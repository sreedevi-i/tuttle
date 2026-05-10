import Foundation
import PythonKit

@Observable
final class InvoicingViewModel {
    var invoices: [Entity] = []
    var isLoading = false
    var errorMessage: String?

    func loadInvoices() {
        isLoading = true
        errorMessage = nil

        PythonBridge.shared.run({
            let result = PythonBridge.shared.invoicingDS.get_all_invoices()
            guard PythonBridge.isOk(result) else { return [Entity]() }
            return PythonBridge.toEntityList(result.data) { obj, dict in
                let contract = obj.contract
                let currency: String
                if contract != Python.None {
                    currency = String(contract.currency) ?? "EUR"
                    dict["contract_title"] = String(contract.title) ?? ""
                } else {
                    currency = "EUR"
                }
                dict["currency"] = currency

                if obj.client != Python.None {
                    dict["client_name"] = String(obj.client.name) ?? ""
                }
                if obj.project != Python.None {
                    dict["project_title"] = String(obj.project.title) ?? ""
                }

                dict["status"] = String(obj.status) ?? "draft"
                dict["sum_value"] = Double(Python.float(obj.sum)) ?? 0
                dict["sum_formatted"] = PythonBridge.fmtCurrencyStr(obj.sum, currency)
                dict["vat_total_value"] = Double(Python.float(obj.VAT_total)) ?? 0
                dict["vat_total_formatted"] = PythonBridge.fmtCurrencyStr(obj.VAT_total, currency)
                dict["total_value"] = Double(Python.float(obj.total)) ?? 0
                dict["total_formatted"] = PythonBridge.fmtCurrencyStr(obj.total, currency)

                // Line items
                var items: [[String: Any]] = []
                let pyItems = obj.items
                if pyItems != Python.None {
                    for item in pyItems {
                        var itemDict = PythonBridge.toSwiftDict(item.model_dump())
                        itemDict["unit_price_formatted"] = PythonBridge.fmtCurrencyStr(item.unit_price, currency)
                        itemDict["subtotal_value"] = Double(Python.float(item.subtotal)) ?? 0
                        itemDict["subtotal_formatted"] = PythonBridge.fmtCurrencyStr(item.subtotal, currency)
                        items.append(itemDict)
                    }
                }
                dict["items"] = items
            }
        }, completion: { [self] data in
            self.invoices = data
            self.isLoading = false
        })
    }

    func deleteInvoice(_ id: Int) {
        PythonBridge.shared.run({
            PythonBridge.isOk(PythonBridge.shared.invoicing.delete_invoice_by_id(id))
        }, completion: { [self] ok in
            if ok { self.invoices.removeAll { $0.id == id } }
        })
    }

    func toggleSent(_ id: Int) { toggleField(id, method: "toggle_invoice_sent_status") }
    func togglePaid(_ id: Int) { toggleField(id, method: "toggle_invoice_paid_status") }
    func toggleCancelled(_ id: Int) { toggleField(id, method: "toggle_invoice_cancelled_status") }

    private func toggleField(_ id: Int, method: String) {
        PythonBridge.shared.run({
            let intent = PythonBridge.shared.invoicing!
            let allMap = intent.get_all_invoices_as_map()
            let inv = allMap[id]
            guard inv != Python.None else { return false }
            let toggle = Python.getattr(intent, method)
            return PythonBridge.isOk(toggle(inv))
        }, completion: { [self] (ok: Bool) in
            if ok { self.loadInvoices() }
        })
    }
}
