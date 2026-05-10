import Foundation
import PythonKit

@Observable
final class InvoicingViewModel {
    var invoices: [InvoiceModel] = []
    var isLoading = false
    var errorMessage: String?

    func loadInvoices() {
        isLoading = true
        errorMessage = nil

        PythonBridge.shared.run({ bridge -> [InvoiceModel] in
            let result = bridge.get_all_invoices()
            guard PythonBridge.bool(result, key: "ok") else { return [] }
            var out: [InvoiceModel] = []
            for item in result["invoices"] {
                out.append(InvoiceModel.from(item))
            }
            return out
        }, completion: { [self] data in
            self.invoices = data
            self.isLoading = false
        })
    }

    func deleteInvoice(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.delete_invoice(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.invoices.removeAll { $0.id == id } }
        })
    }

    func toggleSent(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.toggle_invoice_sent(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.loadInvoices() }
        })
    }

    func togglePaid(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.toggle_invoice_paid(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.loadInvoices() }
        })
    }

    func toggleCancelled(_ id: Int) {
        PythonBridge.shared.run({ bridge -> Bool in
            PythonBridge.bool(bridge.toggle_invoice_cancelled(id), key: "ok")
        }, completion: { [self] ok in
            if ok { self.loadInvoices() }
        })
    }
}
